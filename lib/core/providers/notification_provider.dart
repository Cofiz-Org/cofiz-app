import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../services/push_relay_service.dart';

class NotificationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore;
  final PushRelayService? _pushRelayOverride;
  late final PushRelayService _pushRelay =
      _pushRelayOverride ?? PushRelayService.shared;

  NotificationProvider(
      {FirebaseFirestore? firestore, PushRelayService? pushRelay})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _pushRelayOverride = pushRelay;

  static const int pageSize = 30;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _subscription;
  String? _currentUserId;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  void init(String userId) {
    if (_currentUserId == userId) return;

    _currentUserId = userId;
    _subscription?.cancel();
    _lastDoc = null;
    _hasMore = true;

    _subscription = _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .listen((snapshot) {
      _notifications = snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc.data(), doc.id))
          .toList();
      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
      }
      _hasMore = snapshot.docs.length == pageSize;
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error listening to notifications: $e');
    });
  }

  Future<void> loadMore() async {
    if (_currentUserId == null || _lastDoc == null || !_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final snap = await _firestore
          .collection('notifications')
          .where('targetUserId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(pageSize)
          .get();
      final more = snap.docs
          .map((doc) => AppNotification.fromFirestore(doc.data(), doc.id))
          .toList();
      _notifications.addAll(more);
      if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
      _hasMore = snap.docs.length == pageSize;
    } catch (e) {
      debugPrint('Error loading more notifications: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void disposeListener() {
    _subscription?.cancel();
    _subscription = null;
    _currentUserId = null;
    _notifications = [];
    _unreadCount = 0;
    _lastDoc = null;
    _hasMore = true;
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    var flipped = false;
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
      flipped = true;
    }
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      if (flipped && index != -1) {
        _notifications[index] =
            _notifications[index].copyWith(isRead: false);
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    }
  }

  Future<void> markAllAsRead() async {
    List<QueryDocumentSnapshot> unread;
    try {
      final snap = await _firestore
          .collection('notifications')
          .where('targetUserId', isEqualTo: _currentUserId)
          .where('isRead', isEqualTo: false)
          .get();
      unread = snap.docs;
    } catch (e) {
      debugPrint('Error marking all as read: $e');
      return;
    }
    if (unread.isEmpty) return;
    try {
      for (var i = 0; i < unread.length; i += 500) {
        final batch = _firestore.batch();
        for (final doc in unread.skip(i).take(500)) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
      _notifications = [
        for (final n in _notifications) n.copyWith(isRead: true),
      ];
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<String> _recipientLanguage(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final code = doc.data()?['language_code'];
      if (code is String && code.toLowerCase().startsWith('am')) return 'am';
    } catch (_) {}
    return 'en';
  }

  /// Send a ping to a specific user (Admin only)
  Future<void> sendPing({
    required String targetUserId,
    required String title,
    required String body,
    String? titleAm,
    String? bodyAm,
    required String senderName,
    required String senderId,
  }) async {
    final cofizTitle = NotificationType.cofizTitle(title);
    final cofizTitleAm =
        titleAm == null ? null : NotificationType.cofizTitle(titleAm);
    final lang = await _recipientLanguage(targetUserId);
    final pushTitle = lang == 'am' ? (cofizTitleAm ?? cofizTitle) : cofizTitle;
    final pushBody = lang == 'am' ? (bodyAm ?? body) : body;
    try {
      final notification = AppNotification(
        id: '',
        targetUserId: targetUserId,
        title: cofizTitle,
        body: body,
        titleAm: cofizTitleAm,
        bodyAm: bodyAm,
        type: NotificationType.ping,
        createdAt: DateTime.now(),
        senderName: senderName,
        senderId: senderId,
      );

      await _firestore.collection('notifications').add(notification.toFirestore());
      await _pushRelay.sendPush(
        targetUserId: targetUserId,
        title: pushTitle,
        body: pushBody,
        type: NotificationType.ping.name,
      );
    } catch (e) {
      debugPrint('Error sending ping: $e');
      rethrow;
    }
  }

  /// Send a ping to ALL workers (Admin only)
  /// Warning: efficient for small number of workers. For large scale, use Cloud Functions.
  Future<void> sendGlobalPing({
    required String title,
    required String body,
    String? titleAm,
    String? bodyAm,
    required String senderName,
    required String senderId,
  }) async {
    try {
      // 1. Get all users with 'worker' role
      final workersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'worker')
          .get();

      final cofizTitle = NotificationType.cofizTitle(title);
      final cofizTitleAm =
          titleAm == null ? null : NotificationType.cofizTitle(titleAm);
      final batch = _firestore.batch();

      for (var doc in workersSnapshot.docs) {
        final newDocRef = _firestore.collection('notifications').doc();
        final notification = AppNotification(
          id: newDocRef.id,
          targetUserId: doc.id,
          title: cofizTitle,
          body: body,
          titleAm: cofizTitleAm,
          bodyAm: bodyAm,
          type: NotificationType.dailyReportRequest,
          createdAt: DateTime.now(),
          senderName: senderName,
          senderId: senderId,
        );

        batch.set(newDocRef, notification.toFirestore());
      }

      await batch.commit();
      for (var doc in workersSnapshot.docs) {
        final lang = await _recipientLanguage(doc.id);
        await _pushRelay.sendPush(
          targetUserId: doc.id,
          title: lang == 'am' ? (cofizTitleAm ?? cofizTitle) : cofizTitle,
          body: lang == 'am' ? (bodyAm ?? body) : body,
          type: NotificationType.dailyReportRequest.name,
        );
      }
    } catch (e) {
      debugPrint('Error sending global ping: $e');
      rethrow;
    }
  }
}
