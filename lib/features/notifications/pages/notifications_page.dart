import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/notification_model.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/providers/auth_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final List<String> _filterTabs = [
    'All',
    'Unread',
    'Bot Alerts',
    'Assignments',
    'System'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filterTabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    // Load initial notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadNotifications();
    }
  }

  void _loadNotifications() {
    final authState = ref.read(authProvider);
    final userId = authState.userProfile?.id;
    
    if (userId == null) return;

    final notificationNotifier = ref.read(notificationProvider.notifier);
    
    switch (_tabController.index) {
      case 0: // All
        notificationNotifier.loadNotifications(userId);
        break;
      case 1: // Unread
        notificationNotifier.loadUnreadNotifications(userId);
        break;
      case 2: // Bot Alerts
        notificationNotifier.loadNotificationsByType(userId, NotificationType.botAlert);
        break;
      case 3: // Assignments
        notificationNotifier.loadNotificationsByType(userId, NotificationType.assignment);
        break;
      case 4: // System
        notificationNotifier.loadNotificationsByType(userId, NotificationType.system);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);
    
    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Notifications',
        showDrawer: false,
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.background, AppColors.surface],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              dividerColor: Colors.transparent,
              labelStyle: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              padding: const EdgeInsets.all(4),
              tabs: _filterTabs.map((tab) => Tab(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(tab),
                ),
              )).toList(),
            ),
          ),
          
          // Notifications List
          Expanded(
            child: _buildNotificationsList(notificationState),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(NotificationState notificationState) {
    if (notificationState.isLoading) {
      return const LoadingIndicator();
    }

    if (notificationState.error != null) {
      return ErrorState(
        error: notificationState.error!,
        onRetry: _loadNotifications,
      );
    }

    if (notificationState.notifications.isEmpty) {
      return _buildEmptyState();
    }

    return _buildNotificationsListView(notificationState.notifications);
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    
    switch (_tabController.index) {
      case 1:
        message = 'No unread notifications';
        icon = Icons.mark_email_read;
        break;
      case 2:
        message = 'No bot alerts';
        icon = Icons.directions_boat;
        break;
      case 3:
        message = 'No assignments';
        icon = Icons.assignment;
        break;
      case 4:
        message = 'No system notifications';
        icon = Icons.settings;
        break;
      default:
        message = 'No notifications';
        icon = Icons.notifications_none;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsListView(List<NotificationModel> notifications) {
    // Group notifications by date
    final groupedNotifications = <String, List<NotificationModel>>{};
    
    for (final notification in notifications) {
      final group = notification.dateGroup;
      if (!groupedNotifications.containsKey(group)) {
        groupedNotifications[group] = [];
      }
      groupedNotifications[group]!.add(notification);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: groupedNotifications.length,
      itemBuilder: (context, groupIndex) {
        final groupKey = groupedNotifications.keys.elementAt(groupIndex);
        final groupNotifications = groupedNotifications[groupKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group header
            if (groupIndex == 0 || groupKey != groupedNotifications.keys.elementAt(groupIndex - 1))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  groupKey,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            
            // Notifications in this group
            ...groupNotifications.map((notification) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildNotificationCard(notification),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.isRead 
            ? AppColors.surface 
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead 
              ? AppColors.border.withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _onNotificationTap(notification),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getNotificationColors(notification.type),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getNotificationIcon(notification.type),
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        notification.timeAgo,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  if (notification.hasAction) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _handleNotificationAction(notification),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          notification.actionLabel,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Unread indicator
            if (!notification.isRead)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Color> _getNotificationColors(NotificationType type) {
    switch (type) {
      case NotificationType.botAlert:
        return [Colors.red.shade400, Colors.red.shade600];
      case NotificationType.botUpdate:
        return [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)];
      case NotificationType.userActivity:
        return [Colors.green.shade400, Colors.green.shade600];
      case NotificationType.system:
        return [Colors.blue.shade400, Colors.blue.shade600];
      case NotificationType.assignment:
        return [Colors.orange.shade400, Colors.orange.shade600];
      case NotificationType.maintenance:
        return [Colors.purple.shade400, Colors.purple.shade600];
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.botAlert:
        return Icons.warning;
      case NotificationType.botUpdate:
        return Icons.directions_boat;
      case NotificationType.userActivity:
        return Icons.person;
      case NotificationType.system:
        return Icons.settings;
      case NotificationType.assignment:
        return Icons.assignment;
      case NotificationType.maintenance:
        return Icons.build;
    }
  }

  void _onNotificationTap(NotificationModel notification) {
    if (!notification.isRead) {
      ref.read(notificationProvider.notifier).markAsRead(notification.id);
    }
  }

  void _handleNotificationAction(NotificationModel notification) {
    // Handle specific actions based on notification type
    switch (notification.type) {
      case NotificationType.botAlert:
      case NotificationType.assignment:
        if (notification.relatedEntityId != null) {
          // Navigate to bot details or assignment page
          // Navigator.pushNamed(context, '/bot-details', arguments: notification.relatedEntityId);
        }
        break;
      case NotificationType.userActivity:
        if (notification.relatedEntityId != null) {
          // Navigate to user profile
          // Navigator.pushNamed(context, '/profile', arguments: notification.relatedEntityId);
        }
        break;
      case NotificationType.system:
        // Handle system notification action
        break;
      default:
        break;
    }
  }
}