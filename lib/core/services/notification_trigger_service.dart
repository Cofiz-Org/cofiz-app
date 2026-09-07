import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/debt_model.dart';
import '../models/notification_model.dart';
import 'push_relay_service.dart';


class NotificationTriggerService {
  final FirebaseFirestore _firestore;
  final PushRelayService? _pushRelayOverride;
  late final PushRelayService _pushRelay =
      _pushRelayOverride ?? PushRelayService.shared;

  NotificationTriggerService(
      {FirebaseFirestore? firestore, PushRelayService? pushRelay})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _pushRelayOverride = pushRelay;

  
  static const double lowBalanceThreshold = 500.0;
  static const double largePurchaseThreshold = 10000.0;

  
  Future<void> _sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    required NotificationType type,
    String? senderName,
    String? senderId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'targetUserId': targetUserId,
        'title': title,
        'body': body,
        'type': type.name,
        'isRead': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'senderName': senderName ?? 'System',
        'senderId': senderId,
        'metadata': metadata,
      });
      debugPrint('Notification sent: $title to $targetUserId');
      await _maybeQueueEmail(
        targetUserId: targetUserId,
        title: title,
        body: body,
      );
      await _pushRelay.sendPush(
        targetUserId: targetUserId,
        title: title,
        body: body,
        type: type.name,
        data: metadata?.map((k, v) => MapEntry(k, v.toString())),
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  
  
  
  
  Future<void> _maybeQueueEmail({
    required String targetUserId,
    required String title,
    required String body,
  }) async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(targetUserId).get();
      final data = userDoc.data();
      if (data == null) return;
      final verified = data['emailVerified'] == true;
      final optedIn = data['emailNotificationsEnabled'] == true;
      if (!verified || !optedIn) return;

      final email = data['email'];
      if (email is! String || email.isEmpty) return;

      await _firestore.collection('mail').add({
        'to': email,
        'template': {
          'name': 'notification',
          'data': {'title': title, 'body': body},
        },
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('Email queued: $title to $email');
    } catch (e) {
      debugPrint('Error queueing notification email: $e');
    }
  }

  
  Future<void> notifyMoneyDistributed({
    required String workerId,
    required String workerUserId,
    required String workerName,
    required double amount,
    String? adminName,
  }) async {
    await _sendNotification(
      targetUserId: workerUserId,
      title: 'Money Received',
      body:
          'You received ETB ${amount.toStringAsFixed(0)} from ${adminName ?? 'Admin'}',
      type: NotificationType.moneyDistributed,
      senderName: adminName ?? 'Admin',
      metadata: {
        'workerId': workerId,
        'amount': amount,
      },
    );
  }

  
  
  
  Future<void> checkLowBalance({
    required String workerId,
    required String workerUserId,
    required String workerName,
    required double newBalance,
  }) async {
    
    
    return;
  }

  
  Future<void> notifyCommissionEarned({
    required String workerUserId,
    required String workerName,
    required double commission,
    required double totalCommission,
  }) async {
    await _sendNotification(
      targetUserId: workerUserId,
      title: 'Commission Earned!',
      body:
          'You earned ETB ${commission.toStringAsFixed(0)} commission. Total: ETB ${totalCommission.toStringAsFixed(0)}',
      type: NotificationType.commissionEarned,
      metadata: {
        'commission': commission,
        'totalCommission': totalCommission,
      },
    );
  }

  
  Future<void> checkLargePurchase({
    required String workerId,
    required String workerName,
    required double amount,
    String? coffeeType,
    double? weight,
  }) async {
    
    return;
  }

  
  Future<void> _notifyAllAdmins({
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      
      final adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var doc in adminSnapshot.docs) {
        await _sendNotification(
          targetUserId: doc.id,
          title: title,
          body: body,
          type: type,
          senderName: 'System',
          metadata: metadata,
        );
      }
    } catch (e) {
      debugPrint('Error notifying admins: $e');
    }
  }

  Future<String?> _collectorUserId(String collectorId) async {
    if (collectorId.isEmpty || collectorId == Debt.companyCollectorId) {
      return null;
    }
    try {
      final doc =
          await _firestore.collection('workers').doc(collectorId).get();
      final userId = doc.data()?['userId'];
      if (userId is String && userId.isNotEmpty) return userId;
    } catch (_) {}
    return null;
  }

  Future<void> _notifyCollector({
    required String collectorId,
    required String collectorName,
    required String title,
    required String body,
    required NotificationType type,
    required Map<String, dynamic> metadata,
  }) async {
    final userId = await _collectorUserId(collectorId);
    if (userId == null) return;
    await _sendNotification(
      targetUserId: userId,
      title: title,
      body: body,
      type: type,
      senderName: 'System',
      metadata: metadata,
    );
  }

  Future<void> notifyDebtRecorded({
    required String collectorId,
    required String collectorName,
    required double forgivenAmount,
    required double totalAmount,
    String? linkedName,
    String source = 'purchase',
    String creditorName = '',
  }) async {
    final hasLink = linkedName != null && linkedName.isNotEmpty;
    final kind = source == 'expense' && hasLink ? linkedName : source;
    final forSuffix =
        source != 'expense' && hasLink ? ' For $linkedName.' : '';
    final creditor = creditorName.isNotEmpty
        ? creditorName
        : (source == 'purchase' ? collectorName : 'Admin');
    final adminBody =
        'You owe $creditor: ETB ${forgivenAmount.toStringAsFixed(0)} recorded ($kind ETB ${totalAmount.toStringAsFixed(0)}).$forSuffix';
    final viewerBody =
        'You owe $creditor: ETB ${forgivenAmount.toStringAsFixed(0)} recorded.';
    await _notifyAllAdmins(
      title: 'Debt recorded',
      body: adminBody,
      type: NotificationType.debtRecorded,
      metadata: {'collectorId': collectorId, 'collectorName': collectorName, 'forgivenAmount': forgivenAmount, 'totalAmount': totalAmount},
    );
    await _notifyAllViewers(
      title: 'Debt recorded',
      body: viewerBody,
      type: NotificationType.debtRecorded,
      metadata: {'collectorId': collectorId, 'collectorName': collectorName, 'forgivenAmount': forgivenAmount},
    );
    await _notifyCollector(
      collectorId: collectorId,
      collectorName: collectorName,
      title: 'Debt recorded',
      body: viewerBody,
      type: NotificationType.debtRecorded,
      metadata: {'collectorId': collectorId, 'collectorName': collectorName, 'forgivenAmount': forgivenAmount, 'totalAmount': totalAmount},
    );
  }

  
  Future<void> notifyDebtRepaid({
    required String collectorId,
    required String collectorName,
    required double amount,
  }) async {
    final body =
        '$collectorName cleared their balance (ETB ${amount.toStringAsFixed(0)} repaid).';
    await _notifyAllAdmins(
      title: 'Debt repaid',
      body: body,
      type: NotificationType.debtRecorded,
      metadata: {'collectorId': collectorId, 'collectorName': collectorName, 'amount': amount},
    );
    await _notifyAllViewers(
      title: 'Debt repaid',
      body: body,
      type: NotificationType.debtRecorded,
      metadata: {'collectorId': collectorId, 'collectorName': collectorName, 'amount': amount},
    );
    await _notifyCollector(
      collectorId: collectorId,
      collectorName: collectorName,
      title: 'Debt repaid',
      body: body,
      type: NotificationType.debtRecorded,
      metadata: {'collectorId': collectorId, 'collectorName': collectorName, 'amount': amount},
    );
  }

  Future<void> _notifyAllViewers({
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final viewerSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'viewer')
          .get();

      for (var doc in viewerSnapshot.docs) {
        await _sendNotification(
          targetUserId: doc.id,
          title: title,
          body: body,
          type: type,
          senderName: 'System',
          metadata: metadata,
        );
      }
    } catch (e) {
      debugPrint('Error notifying viewers: $e');
    }
  }
}
