import 'package:flutter/material.dart';

import '../models/debt_model.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/transaction/all_debts_screen.dart';
import '../../presentation/screens/transaction/collector_debts_screen.dart';
import '../../presentation/screens/worker/worker_dashboard_screen.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static void openNotificationType(String type,
      [Map<String, String> data = const {}]) {
    final nav = key.currentState;
    if (nav == null) return;
    final page = _pageFor(type, data);
    if (page == null) return;
    nav.push(MaterialPageRoute(builder: (_) => page));
  }

  static Widget? _pageFor(String type, Map<String, String> data) {
    switch (type) {
      case 'registrationApproved':
      case 'registrationDenied':
        return null;
      case 'app_update':
        return const SettingsScreen();
      case 'debtRecorded':
        final collectorId = data['collectorId'] ?? '';
        if (collectorId.isEmpty ||
            collectorId == Debt.companyCollectorId) {
          return const AllDebtsScreen();
        }
        return CollectorDebtsScreen(
          collectorId: collectorId,
          collectorName: data['collectorName'] ?? '',
        );
      case 'moneyDistributed':
      case 'lowBalance':
      case 'commissionEarned':
      case 'purchaseRecorded':
        final workerId = data['workerId'] ?? '';
        if (workerId.isEmpty) return const NotificationsScreen();
        return WorkerDashboardScreen(workerId: workerId);
      default:
        return const NotificationsScreen();
    }
  }
}
