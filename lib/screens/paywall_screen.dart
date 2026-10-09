import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/l10n.dart';
import '../services/activity_controller.dart';
import '../services/payment_service.dart';

/// Shown when a free member tries to open a third profile, and from Account.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _payments = PaymentService();
  Razorpay? _razorpay;
  String _selected = 'm3';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError)
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pay() async {
    final plan = plans.firstWhere((p) => p.id == _selected);
    final failMsg = context.trRead('Could not start the payment');
    final user = FirebaseAuth.instance.currentUser;
    setState(() => _busy = true);
    try {
      final order = await _payments.createOrder(plan.id);
      _razorpay!.open({
        'key': order.keyId,
        'amount': order.amount,
        'order_id': order.orderId,
        'currency': 'INR',
        'name': AppStrings.nameEnglish,
        'description':
            '${plan.months} ${plan.months == 1 ? 'month' : 'months'}',
        'prefill': {
          'contact': user?.phoneNumber ?? '',
          'email': user?.email ?? '',
        },
        'theme': {'color': '#671B30'},
        'retry': {'enabled': true, 'max_count': 1},
      });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('$failMsg: $e');
      }
    }
  }

  Future<void> _onSuccess(PaymentSuccessResponse r) async {
    final okMsg = context.trRead('Payment successful');
    final failMsg = context.trRead(
      'Payment received but could not be confirmed. Please contact support.',
    );
    try {
      await _payments.verify(
        orderId: r.orderId ?? '',
        paymentId: r.paymentId ?? '',
        signature: r.signature ?? '',
      );
      if (!mounted) return;
      _toast(okMsg);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _toast('$failMsg ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onError(PaymentFailureResponse r) {
    if (!mounted) return;
    setState(() => _busy = false);
    _toast('${context.trRead('Payment failed')}: ${r.message ?? r.code}');
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityController>();
    final ta = context.isTamil;
    final until = activity.entitlement.premiumUntil;
    final selected = plans.firstWhere((p) => p.id == _selected);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Premium'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            activity.isPremium ? Icons.workspace_premium : Icons.lock_outline,
            size: 64,
            color: AppColors.gold,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              activity.isPremium
                  ? 'Premium active until {date}'
                  : 'You have used your {n} free profile views',
              {
                'date': until == null ? '' : context.fmtDate(until),
                'n': '${ActivityController.freeViewLimit}',
              },
            ),
            textAlign: TextAlign.center,
            style: Fx.serif(
              ta,
              fontSize: ta ? 22 : 28,
              fontWeight: FontWeight.w700,
              color: AppColors.maroon,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Unlimited profile views, with Call and Message access for accepted interests.',
            ),
            textAlign: TextAlign.center,
            style: Fx.body(ta, fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('Choose a plan'),
            style: Fx.body(ta, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          RadioGroup<String>(
            groupValue: _selected,
            onChanged: (v) {
              if (!_busy && v != null) setState(() => _selected = v);
            },
            child: Column(
              children: [
                for (final p in plans)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: _selected == p.id
                            ? AppColors.maroon
                            : AppColors.gold.withValues(alpha: 0.4),
                        width: _selected == p.id ? 2 : 1,
                      ),
                    ),
                    child: RadioListTile<String>(
                      value: p.id,
                      activeColor: AppColors.maroon,
                      title: Text(
                        context.tr(p.months == 1 ? '1 month' : '{n} months', {
                          'n': '${p.months}',
                        }),
                        style: Fx.body(
                          ta,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: p.months == 6
                          ? Text(context.tr('Best value'))
                          : null,
                      secondary: Text(
                        '\u20b9${p.priceRupees}',
                        style: Fx.body(
                          ta,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.maroon,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (kIsWeb)
            Text(
              context.tr('Payments are available in the mobile app'),
              textAlign: TextAlign.center,
            )
          else
            FilledButton(
              onPressed: _busy ? null : _pay,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      context.tr('Pay \u20b9{price}', {
                        'price': '${selected.priceRupees}',
                      }),
                    ),
            ),
          const SizedBox(height: 12),
          Text(
            context.tr('Secure payment by Razorpay (UPI, cards, netbanking)'),
            textAlign: TextAlign.center,
            style: Fx.body(ta, fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
