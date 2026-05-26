import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../models/notification.dart';
import 'package:flutter/services.dart';

class NotificationBottomSheet extends StatefulWidget {
  const NotificationBottomSheet({Key? key}) : super(key: key);

  @override
  State<NotificationBottomSheet> createState() => _NotificationBottomSheetState();
}

class _NotificationBottomSheetState extends State<NotificationBottomSheet> {
  String _selectedFilter = 'all';
  
  // Cache expensive calculations
  late Color _primaryColor;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Fetch notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNotifications();
    });
  }
  
  Future<void> _fetchNotifications() async {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    // Only fetch from backend if we currently have no items.
    if (notificationProvider.recentNotifications.isEmpty && !notificationProvider.isLoading) {
      await notificationProvider.fetchRecentNotifications();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache theme colors to avoid repeated lookups
    final theme = Theme.of(context);
    _primaryColor = theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Selector3<LanguageProvider, ThemeProvider, NotificationProvider, 
        ({bool isRTL, TextDirection textDirection, ThemeData theme, 
          List<NotificationModel> notifications, bool isLoading, String? error, int unreadCount})>(
      selector: (context, lang, theme, notif) => (
        isRTL: lang.isRTL,
        textDirection: lang.textDirection,
        theme: theme.theme,
        notifications: notif.recentNotifications,
        isLoading: notif.isLoading,
        error: notif.error,
        unreadCount: notif.unreadCount,
      ),
      builder: (context, data, child) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: data.theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: data.theme.brightness == Brightness.dark 
                      ? data.theme.colorScheme.outlineVariant 
                      : Colors.grey[400],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildHeader(data),
              ),
              
              // Filter Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildFilterSection(data),
              ),
              
              const SizedBox(height: 10),

              // Notifications List
              Expanded(
                child: _buildNotificationsList(data),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (data.isRTL) ...[
          IconButton(
             onPressed: () {
               setState(() {
                 _isLoading = true;
               });
               Provider.of<NotificationProvider>(context, listen: false)
                   .fetchRecentNotifications()
                   .then((_) {
                     if (mounted) {
                       setState(() {
                         _isLoading = false;
                       });
                     }
                   });
             },
             icon: _isLoading || data.isLoading
                 ? SizedBox(
                     width: 20,
                     height: 20,
                     child: CircularProgressIndicator(
                       strokeWidth: 2,
                       color: _primaryColor,
                     ),
                   )
                 : Icon(
                     Icons.refresh,
                     color: _primaryColor,
                   ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'ئاگادارکردنەوەکان',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'NRT',
                    color: data.theme.colorScheme.onBackground,
                  ),
                ),
                if (data.unreadCount > 0)
                  Text(
                    '${data.unreadCount} نەخوێندراوە',
                    style: TextStyle(
                      fontSize: 12,
                      color: data.theme.colorScheme.primary,
                      fontFamily: 'NRT',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ] else ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ئاگادارکردنەوەکان',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'NRT',
                    color: data.theme.colorScheme.onBackground,
                  ),
                ),
                if (data.unreadCount > 0)
                  Text(
                    '${data.unreadCount} نەخوێندراوە',
                    style: TextStyle(
                      fontSize: 12,
                      color: data.theme.colorScheme.primary,
                      fontFamily: 'NRT',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
               setState(() {
                 _isLoading = true;
               });
               Provider.of<NotificationProvider>(context, listen: false)
                   .fetchRecentNotifications()
                   .then((_) {
                     if (mounted) {
                       setState(() {
                         _isLoading = false;
                       });
                     }
                   });
             },
             icon: _isLoading || data.isLoading
                 ? SizedBox(
                     width: 20,
                     height: 20,
                     child: CircularProgressIndicator(
                       strokeWidth: 2,
                       color: _primaryColor,
                     ),
                   )
                 : Icon(
                     Icons.refresh,
                     color: _primaryColor,
                   ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterSection(data) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (data.isRTL) ...[
              _buildFilterChip('read', 'خوێندراوە', data),
              const SizedBox(width: 8),
              _buildFilterChip('unread', 'نەخوێندراوە', data),
              const SizedBox(width: 8),
              _buildFilterChip('all', 'هەموو', data),
            ] else ...[
              _buildFilterChip('all', 'هەموو', data),
              const SizedBox(width: 8),
              _buildFilterChip('unread', 'نەخوێندراوە', data),
              const SizedBox(width: 8),
              _buildFilterChip('read', 'خوێندراوە', data),
            ],
          ],
        ),
        
        if (data.unreadCount > 0) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final provider = Provider.of<NotificationProvider>(context, listen: false);
                await provider.markAllAsRead();
              },
              icon: const Icon(Icons.mark_email_read_rounded, size: 18),
              label: const Text(
                'نیشانکردنی هەموو وەک خوێندراوە',
                style: TextStyle(
                  fontFamily: 'NRT',
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: BorderSide(color: _primaryColor.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotificationsList(data) {
    // Show loading only when we have no items to show yet.
    if (data.isLoading && data.notifications.isEmpty) {
      return _buildLoadingState(data);
    }
    
    if (data.error != null) {
      return _buildErrorState(data);
    }
    
    final filteredNotifications = _getFilteredNotifications(data.notifications);
    
    if (filteredNotifications.isEmpty) {
      return _buildEmptyState(data);
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        final provider = Provider.of<NotificationProvider>(context, listen: false);
        await provider.fetchRecentNotifications();
      },
      color: _primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: filteredNotifications.length,
        itemBuilder: (context, index) {
          final notification = filteredNotifications[index];
          return _buildOptimizedNotificationItem(context, notification, data, index);
        },
      ),
    );
  }

  // Optimized notification item with simplified decoration
  Widget _buildOptimizedNotificationItem(
    BuildContext context,
    NotificationModel notification,
    data,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(notification.id),
        background: _buildSimpleSwipeBackground(true, data),
        secondaryBackground: _buildSimpleSwipeBackground(false, data),
        confirmDismiss: (direction) async {
          final provider = Provider.of<NotificationProvider>(context, listen: false);
          // If swipe is to the left (endToStart), we delete (allow dismissal)
          if (direction == DismissDirection.endToStart) {
            HapticFeedback.mediumImpact();
            // Remove immediately from provider to avoid keeping dismissed widget in tree
            await provider.deleteNotification(notification.id);
            return true; // proceed with dismissal animation
          }

          // For startToEnd, toggle read/unread but DO NOT dismiss
          HapticFeedback.selectionClick();
          if (notification.isRead) {
            await provider.markNotificationAsUnread(notification.id);
          } else {
            await provider.markNotificationAsRead(notification.id);
          }
          return false; // keep item in the list
        },
        onDismissed: (direction) async {
          // Only reached for delete (endToStart) since confirmDismiss returns true there
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: const Text(
                  'ئاگادارکردنەوەکە سڕایەوە',
                  style: TextStyle(fontFamily: 'NRT'),
                ),
                backgroundColor: data.theme.colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: _buildSimplifiedNotificationCard(notification, data),
      ),
    );
  }

  // Simplified notification card with minimal decoration
  Widget _buildSimplifiedNotificationCard(NotificationModel notification, data) {
    final isRead = notification.isRead;
    return Container(
      decoration: BoxDecoration(
        color: isRead
            ? (data.theme.brightness == Brightness.dark ? data.theme.colorScheme.surface : Colors.grey.shade50)
            : _primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? (data.theme.brightness == Brightness.dark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.shade200)
              : _primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            HapticFeedback.selectionClick();
            if (!notification.isRead) {
              final provider = Provider.of<NotificationProvider>(context, listen: false);
              await provider.markNotificationAsRead(notification.id);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    if (data.isRTL) ...[
                      Text(
                        _formatDateTime(notification.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: data.theme.colorScheme.onBackground.withOpacity(0.6),
                          fontFamily: 'NRT',
                        ),
                      ),
                      const Spacer(),
                      _buildSimpleTypeChip(notification.type, data),
                      const SizedBox(width: 8),
                      // Dot for unread
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ] else ...[
                      // LTR Header
                      if (!isRead)
                         Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (!isRead) const SizedBox(width: 8),
                      _buildSimpleTypeChip(notification.type, data),
                      const Spacer(),
                      Text(
                        _formatDateTime(notification.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: data.theme.colorScheme.onBackground.withOpacity(0.6),
                          fontFamily: 'NRT',
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Title
                Text(
                  notification.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: data.theme.colorScheme.onBackground,
                    fontFamily: 'NRT',
                    height: 1.3,
                  ),
                  textAlign: data.isRTL ? TextAlign.right : TextAlign.left,
                ),
                
                const SizedBox(height: 6),
                
                // Content
                Text(
                  notification.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: data.theme.colorScheme.onBackground.withOpacity(0.8),
                    fontFamily: 'NRT',
                    height: 1.4,
                  ),
                  textAlign: data.isRTL ? TextAlign.right : TextAlign.left,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleTypeChip(String type, data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getTypeColor(type).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getSimpleNotificationIconData(type),
            size: 12,
            color: _getTypeColor(type),
          ),
          const SizedBox(width: 4),
          Text(
            _getTypeLabel(type),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _getTypeColor(type),
              fontFamily: 'NRT',
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSimpleNotificationIconData(String type) {
    switch (type.toLowerCase()) {
      case 'drug': return Icons.medical_services_rounded;
      case 'diseases': return Icons.favorite_rounded;
      case 'books': return Icons.menu_book_rounded;
      case 'terminology': return Icons.translate_rounded;
      case 'slides': return Icons.slideshow_rounded;
      case 'tests': return Icons.quiz_rounded;
      case 'notes': return Icons.note_rounded;
      case 'instruments': return Icons.build_rounded;
      case 'normal ranges': return Icons.analytics_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  // Simplified swipe background
  Widget _buildSimpleSwipeBackground(bool isLeft, data) {
    return Container(
      decoration: BoxDecoration(
        color: isLeft ? _primaryColor : data.theme.colorScheme.error,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: isLeft 
          ? (data.isRTL ? Alignment.centerRight : Alignment.centerLeft)
          : (data.isRTL ? Alignment.centerLeft : Alignment.centerRight),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(
        isLeft ? Icons.mark_email_read_rounded : Icons.delete_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  // Helper method to build filter chips
  Widget _buildFilterChip(String filter, String label, data) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'NRT',
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected 
              ? data.theme.colorScheme.onPrimary
              : data.theme.colorScheme.onBackground.withOpacity(0.7),
        ),
      ),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
        HapticFeedback.selectionClick();
      },
      backgroundColor: data.theme.brightness == Brightness.dark ? data.theme.colorScheme.surfaceContainerHighest : Colors.white,
      selectedColor: _primaryColor,
      checkmarkColor: data.theme.colorScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected 
              ? _primaryColor
              : data.theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      elevation: 0,
    );
  }

  Widget _buildLoadingState(data) {
    return Center(
      child: CircularProgressIndicator(
        color: _primaryColor,
      ),
    );
  }

  Widget _buildErrorState(data) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: data.theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'هەڵەیەک ڕوویدا',
            style: TextStyle(
              fontFamily: 'NRT',
              color: data.theme.colorScheme.error,
            ),
          ),
          TextButton(
            onPressed: () => Provider.of<NotificationProvider>(context, listen: false).fetchRecentNotifications(),
            child: const Text('هەوڵدانەوە', style: TextStyle(fontFamily: 'NRT')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(data) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'هیچ ئاگادارکردنەوەیەک نییە',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'NRT',
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // --- Filtering & Helper Logic (Same as Dialog) ---
  
  List<NotificationModel> _getFilteredNotifications(List<NotificationModel> notifications) {
    if (_selectedFilter == 'read') {
      return notifications.where((n) => n.isRead).toList();
    } else if (_selectedFilter == 'unread') {
      return notifications.where((n) => !n.isRead).toList();
    }
    return notifications;
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'drug': return Colors.green;
      case 'diseases': return Colors.red;
      case 'books': return Colors.indigo;
      case 'terminology': return Colors.teal;
      case 'slides': return Colors.orange;
      case 'tests': return Colors.blue;
      case 'notes': return Colors.amber;
      case 'instruments': return Colors.deepPurple;
      case 'normal ranges': return Colors.cyan;
      default: return _primaryColor;
    }
  }

  String _getTypeLabel(String type) {
    // Basic mapping, could be extended
    switch (type.toLowerCase()) {
      case 'drug': return 'دەرمان';
      case 'diseases': return 'نەخۆشی';
      case 'books': return 'کتێب';
      case 'terminology': return 'زاراوە';
      case 'slides': return 'سڵاید';
      case 'tests': return 'پشکنین';
      case 'notes': return 'تێبینی';
      case 'instruments': return 'کەرەستە';
      case 'normal ranges': return 'ڕێژەکان';
      default: return type.toUpperCase();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) return 'دوێنێ';
      if (difference.inDays < 7) return '${difference.inDays} ڕۆژ لەمەوبەر';
      return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} کاتژمێر لەمەوبەر';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} خولەک لەمەوبەر';
    } else {
      return 'ئێستا';
    }
  }
}
