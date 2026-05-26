import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';
import '../services/update_service.dart';

/// Wraps any widget with store-based update checking (Play Store / App Store).
///
/// When a newer version is detected, [UpgradeAlert] automatically shows a
/// dialog in the user's language (Kurdish is supported natively by upgrader).
///
/// Usage — just wrap your Scaffold (or any widget) with this:
/// ```dart
/// VetDictUpgradeAlert(child: Scaffold(...))
/// ```
class VetDictUpgradeAlert extends StatelessWidget {
  final Widget child;

  const VetDictUpgradeAlert({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      upgrader: UpdateService.upgrader,
      // Tapping outside the dialog will NOT dismiss it
      barrierDismissible: false,
      // Hide the IGNORE button — only LATER and UPDATE NOW are shown
      showIgnore: false,
      showLater: true,
      showReleaseNotes: true,
      child: child,
    );
  }
}
