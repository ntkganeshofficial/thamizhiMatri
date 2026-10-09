import 'package:cloud_functions/cloud_functions.dart';

class PlanInfo {
  final String id;
  final int months;
  final int priceRupees;
  const PlanInfo(this.id, this.months, this.priceRupees);
}

/// Display prices only; the server holds the authoritative amounts.
const plans = [
  PlanInfo('m1', 1, 49),
  PlanInfo('m3', 3, 119),
  PlanInfo('m6', 6, 199),
];

class RazorpayOrder {
  final String orderId;
  final int amount;
  final String keyId;
  const RazorpayOrder({
    required this.orderId,
    required this.amount,
    required this.keyId,
  });
}

class PaymentService {
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<RazorpayOrder> createOrder(String planId) async {
    final result = await _functions
        .httpsCallable('createOrder')
        .call<Map<Object?, Object?>>({'planId': planId});
    final d = result.data;
    return RazorpayOrder(
      orderId: d['orderId'] as String,
      amount: d['amount'] as int,
      keyId: d['keyId'] as String,
    );
  }

  /// Returns the new premium expiry.
  Future<DateTime?> verify({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final result = await _functions
        .httpsCallable('verifyPayment')
        .call<Map<Object?, Object?>>({
          'orderId': orderId,
          'paymentId': paymentId,
          'signature': signature,
        });
    final ms = result.data['premiumUntil'] as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
