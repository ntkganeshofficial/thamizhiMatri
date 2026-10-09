import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/profile_service.dart';
import 'l10n.dart';

/// Opens the phone dialer or WhatsApp for a member whose interest was accepted.
Future<void> contactMember(
  BuildContext context,
  String uid, {
  required bool whatsapp,
}) async {
  final service = context.read<ProfileService>();
  final messenger = ScaffoldMessenger.of(context);
  final noPhone = context.trRead('Phone number not available');
  final phone = await service.getPhone(uid);
  if (phone == null || phone.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(noPhone)));
    return;
  }
  final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = whatsapp
      ? Uri.parse('https://wa.me/${digits.replaceAll('+', '')}')
      : Uri(scheme: 'tel', path: digits);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(noPhone)));
}
