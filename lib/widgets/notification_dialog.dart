import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../models/notification.dart';
import 'package:flutter/services.dart';

class NotificationDialog extends StatefulWidget {
  const NotificationDialog({Key? key}) : super(key: key);

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String _selectedFilter = 'all';
  
  // Cache expensive calculations
  late Color _primaryColor;
  late Color _backgroundColor;
  late Color _surfaceColor;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animations with optimized duration
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150), // Faster animation
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05), // Minimal slide for performance
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    // Start animation
    _animationController.forward();
    
    // Fetch notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      // Only fetch from backend if we currently have no items.
      // This prevents overwriting freshly inserted local notifications and keeps the dialog live.
      if (notificationProvider.recentNotifications.isEmpty && !notificationProvider.isLoading) {
        notificationProvider.fetchRecentNotifications();
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache theme colors to avoid repeated lookups
    final theme = Theme.of(context);
    _primaryColor = theme.colorScheme.primary;
    _backgroundColor = theme.cardTheme.color ?? Colors.white;
    _surfaceColor = theme.colorScheme.surface;
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        return PopScope(
          canPop: true,
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 4, // Further reduced for performance
                  backgroundColor: _backgroundColor,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.92,
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: Column(
                      children: [
                        // Simplified Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: _buildHeader(data),
                        ),
                        
                        // Filter Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: _buildFilterSection(data),
                        ),

                        // Notifications List
                        Expanded(
                          child: _buildNotificationsList(data),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(data) {
    return Row(
      children: [
        if (data.isRTL) ...[
          IconButton(
            onPressed: () {
              // Close immediately without waiting for animation
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: _surfaceColor,
              padding: const EdgeInsets.all(8),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ئاگادارکردنەوەکان',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: data.theme.colorScheme.onBackground,
                  fontFamily: 'NRT',
                ),
                textAlign: TextAlign.right,
              ),
              if (data.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${data.unreadCount} نەخوێندراوە',
                    style: TextStyle(
                      fontSize: 12,
                      color: data.theme.colorScheme.onPrimary,
                      fontFamily: 'NRT',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: _primaryColor,
              size: 28,
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: _primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ئاگادارکردنەوەکان',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: data.theme.colorScheme.onBackground,
                  fontFamily: 'NRT',
                ),
              ),
              if (data.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${data.unreadCount} نەخوێندراوە',
                    style: TextStyle(
                      fontSize: 12,
                      color: data.theme.colorScheme.onPrimary,
                      fontFamily: 'NRT',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              // Close immediately without waiting for animation
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: _surfaceColor,
              padding: const EdgeInsets.all(8),
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
            child: ElevatedButton.icon(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: data.theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
    return Container(
      decoration: BoxDecoration(
        color: notification.isRead
            ? _backgroundColor
            : _primaryColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.isRead
              ? Colors.grey.withValues(alpha: 0.2)
              : _primaryColor.withValues(alpha: 0.3),
          width: notification.isRead ? 1 : 1.5,
        ),
        // Removed expensive shadows and gradients
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
                // Simplified header
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
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      _getSimpleNotificationIcon(notification.type),
                      const SizedBox(width: 8),
                      _buildSimpleTypeChip(notification.type),
                    ] else ...[
                      _getSimpleNotificationIcon(notification.type),
                      const SizedBox(width: 8),
                      _buildSimpleTypeChip(notification.type),
                      const SizedBox(width: 8),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
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
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Simplified icon without decorative container
  Widget _getSimpleNotificationIcon(String type) {
    IconData iconData;
    Color iconColor;

    switch (type.toLowerCase()) {
      case 'drug':
        iconData = Icons.medical_services_rounded;
        iconColor = Colors.green;
        break;
      case 'diseases':
        iconData = Icons.favorite_rounded;
        iconColor = Colors.red;
        break;
      case 'books':
        iconData = Icons.menu_book_rounded;
        iconColor = Colors.indigo;
        break;
      case 'terminology':
        iconData = Icons.translate_rounded;
        iconColor = Colors.teal;
        break;
      case 'slides':
        iconData = Icons.slideshow_rounded;
        iconColor = Colors.orange;
        break;
      case 'tests':
        iconData = Icons.quiz_rounded;
        iconColor = Colors.blue;
        break;
      case 'notes':
        iconData = Icons.note_rounded;
        iconColor = Colors.amber;
        break;
      case 'instruments':
        iconData = Icons.build_rounded;
        iconColor = Colors.deepPurple;
        break;
      case 'normal ranges':
        iconData = Icons.analytics_rounded;
        iconColor = Colors.cyan;
        break;
      default:
        iconData = Icons.notifications_rounded;
        iconColor = _primaryColor;
    }

    return Icon(
      iconData,
      size: 18,
      color: iconColor,
    );
  }

  // Simplified type chip
  Widget _buildSimpleTypeChip(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getTypeColor(type).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getTypeLabel(type),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _getTypeColor(type),
          fontFamily: 'NRT',
        ),
      ),
    );
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
      backgroundColor: _surfaceColor,
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
      elevation: 0, // Removed elevation for better performance
    );
  }

  // Simplified state builders
  Widget _buildLoadingState(data) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: _primaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'بارکردنی ئاگادارکردنەوەکان...',
            style: TextStyle(
              fontSize: 16,
              color: data.theme.colorScheme.onBackground.withOpacity(0.7),
              fontFamily: 'NRT',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(data) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: data.theme.colorScheme.error,
            ),
            const SizedBox(height: 20),
            Text(
              'هەڵەیەک ڕوویدا لە بارکردنی ئاگادارکردنەوەکان',
              style: TextStyle(
                fontSize: 16,
                color: data.theme.colorScheme.error,
                fontFamily: 'NRT',
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                final provider = Provider.of<NotificationProvider>(context, listen: false);
                provider.fetchRecentNotifications();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'هەوڵدانەوە',
                style: TextStyle(
                  fontFamily: 'NRT',
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: data.theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(data) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'هیچ ئاگادارکردنەوەیەک نییە',
              style: TextStyle(
                fontSize: 18,
                color: data.theme.colorScheme.onBackground.withOpacity(0.7),
                fontFamily: 'NRT',
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'کاتێک ئاگادارکردنەوەت هەیە، لێرە دەیبینیت',
              style: TextStyle(
                fontSize: 14,
                color: data.theme.colorScheme.onBackground.withOpacity(0.5),
                fontFamily: 'NRT',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods remain the same
  List<NotificationModel> _getFilteredNotifications(List<NotificationModel> notifications) {
    switch (_selectedFilter) {
      case 'unread':
        return notifications.where((n) => !n.isRead).toList();
      case 'read':
        return notifications.where((n) => n.isRead).toList();
      case 'all':
      default:
        return notifications;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.isNegative) {
      return 'ئێستا';
    }
    
    if (difference.inDays > 0) {
      return '${difference.inDays} ڕۆژ پێش ئێستا';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} کاتژمێر پێش ئێستا';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} خولەک پێش ئێستا';
    } else {
      return 'ئێستا';
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'drug': return 'دەرمان';
      case 'diseases': return 'نەخۆشییەکان';
      case 'books': return 'کتێبەکان';
      case 'terminology': return 'زاراوەکان';
      case 'slides': return 'سلایدەکان';
      case 'tests': return 'تاقیکردنەوەکان';
      case 'notes': return 'تێبینییەکان';
      case 'instruments': return 'ئامێرەکان';
      case 'normal ranges': return 'نۆرماڵ رێنجەکان';
      default: return 'گشتی';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'drug': return Colors.green;
      case 'diseases': return Colors.red;
      case 'books': return Colors.indigo;
      case 'terminology': return Colors.teal;
      case 'slides': return Colors.orange;
      case 'tests': return Colors.blue;
      case 'notes': return Colors.amber;
      case 'instruments': return Colors.deepPurple;
      case 'normal ranges': return Colors.cyan;
      default: return Colors.grey;
    }
  }
}