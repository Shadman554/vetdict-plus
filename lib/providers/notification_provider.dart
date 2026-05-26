import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification.dart';
import '../services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  int _unreadCount = 0;
  List<NotificationModel> _recentNotifications = [];
  bool _isLoading = false;
  String? _error;
  Set<String> _dismissedNotificationIds = {};
  Set<String> _readNotificationIds = {}; // Track read notifications locally

  int get unreadCount => _unreadCount;
  List<NotificationModel> get recentNotifications => _recentNotifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateUnreadCount(int count) {
    _unreadCount = count;
    notifyListeners();
  }

  void incrementUnreadCount() {
    _unreadCount++;
    notifyListeners();
  }

  void decrementUnreadCount() {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
    }
  }

  void resetUnreadCount() {
    _unreadCount = 0;
    notifyListeners();
  }

  // Load dismissed notification IDs from local storage
  Future<void> loadDismissedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedIds = prefs.getStringList('dismissed_notifications') ?? [];
      _dismissedNotificationIds = dismissedIds.toSet();
    } catch (e) {
      _dismissedNotificationIds = {};
    }
  }

  // Save dismissed notification IDs to local storage
  Future<void> _saveDismissedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('dismissed_notifications', _dismissedNotificationIds.toList());
    } catch (e) {
      // Silent error handling
    }
  }

  // Load read notification IDs from local storage
  Future<void> _loadReadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList('read_notifications') ?? [];
      _readNotificationIds = readIds.toSet();
    } catch (e) {
      _readNotificationIds = {};
    }
  }

  // Save read notification IDs to local storage
  Future<void> _saveReadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_notifications', _readNotificationIds.toList());
    } catch (e) {
      // Silent error handling
    }
  }

  Future<void> fetchRecentNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load dismissed and read notifications first
      await loadDismissedNotifications();
      await _loadReadNotifications();
      
      // Fetch all notifications from API
      final allNotifications = await _apiService.fetchRecentNotifications();
      
      // Filter out dismissed notifications and apply local read status
      _recentNotifications = allNotifications
          .where((n) => !_dismissedNotificationIds.contains(n.id))
          .map((n) {
            // Override backend read status with local read status
            final isLocallyRead = _readNotificationIds.contains(n.id);
            return n.copyWith(isRead: isLocallyRead || n.isRead);
          })
          .toList();
      
      // Count unread notifications based on local read status
      _unreadCount = _recentNotifications.where((n) => !n.isRead).length;
      _error = null; // Clear any previous errors
    } catch (e) {
      // Only show error if we have no cached notifications to display
      if (_recentNotifications.isEmpty) {
        _error = 'خەتا لە بارکردنی ئاگادارکردنەوەکان';
      }
      // Keep existing notifications for better UX (don't wipe on network error)

    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.markAllNotificationsAsRead();
    } catch (e) {
      // Silent - still update local state below for better UX
    }
    // Add all notification IDs to read set
    for (var notification in _recentNotifications) {
      _readNotificationIds.add(notification.id);
    }
    // Save to local storage
    await _saveReadNotifications();
    
    // Always update local state for immediate UX feedback
    _recentNotifications = _recentNotifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    // Add to read set and save to local storage
    _readNotificationIds.add(notificationId);
    await _saveReadNotifications();
    
    // Update local state first for immediate UI feedback
    final index = _recentNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _recentNotifications[index] = _recentNotifications[index].copyWith(isRead: true);
      if (_unreadCount > 0) {
        _unreadCount--;
      }
      notifyListeners();
    }
    // Then sync with API in background
    try {
      await _apiService.markNotificationAsRead(notificationId);
    } catch (e) {
      // Silent - local state already updated for better UX
    }
  }

  Future<void> markNotificationAsUnread(String notificationId) async {
    // Remove from read set and save to local storage
    _readNotificationIds.remove(notificationId);
    await _saveReadNotifications();
    
    // Update local notification first for immediate UI feedback
    final index = _recentNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _recentNotifications[index] = _recentNotifications[index].copyWith(isRead: false);
      _unreadCount++;
      notifyListeners();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      // Remove from local list first for immediate UI feedback
      final notificationToRemove = _recentNotifications.firstWhere(
        (n) => n.id == notificationId,
        orElse: () => NotificationModel(
          id: notificationId, title: '', content: '', type: '', isRead: true, createdAt: DateTime.now(),
        ),
      );
      _recentNotifications.removeWhere((n) => n.id == notificationId);
      
      // Update unread count if the deleted notification was unread
      if (!notificationToRemove.isRead && _unreadCount > 0) {
        _unreadCount--;
      }
      
      // Add to dismissed notifications set and save to local storage
      _dismissedNotificationIds.add(notificationId);
      await _saveDismissedNotifications();
      
      notifyListeners();
    } catch (e) {
      // Silent - avoid crashing the UI
    }
  }

  // Insert a push notification locally so UI updates immediately
  void addIncomingNotification(NotificationModel notification) {
    // Skip if notification is dismissed
    if (_dismissedNotificationIds.contains(notification.id)) {
      return;
    }
    
    // Avoid duplicates by ID
    final exists = _recentNotifications.any((n) => n.id == notification.id);
    if (exists) {
      // Duplicate, skip insert
      return;
    }
    _recentNotifications.insert(0, notification);
    if (!notification.isRead) {
      _unreadCount++;
    }
    notifyListeners();
  }
}
