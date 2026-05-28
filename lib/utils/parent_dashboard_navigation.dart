import 'package:flutter/material.dart';

import '../screens/parent_dashboard_screen.dart';
import '../widgets/parental_gate_dialog.dart';

/// Shows the parental gate, then navigates to [ParentDashboardScreen] on success.
///
/// [dashboardBuilder] is intended for widget tests so navigation can be asserted
/// without loading the full dashboard (providers, assets, etc.).
Future<void> openParentDashboard(
  BuildContext context, {
  WidgetBuilder? dashboardBuilder,
}) async {
  final passed = await ParentalGateDialog.show(context);
  if (!passed || !context.mounted) {
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: dashboardBuilder ?? (_) => const ParentDashboardScreen(),
    ),
  );
}
