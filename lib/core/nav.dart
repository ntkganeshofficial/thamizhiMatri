import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/activity_controller.dart';

/// Pushes [screen] and re-provides the member's [ActivityController], which lives below the Navigator.
Future<T?> pushScreen<T>(BuildContext context, Widget screen) {
  final activity = context.read<ActivityController>();
  return Navigator.push<T>(
    context,
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider<ActivityController>.value(
        value: activity,
        child: screen,
      ),
    ),
  );
}
