import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await ApiService.getNotifications();

    if (!mounted) return;

    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      setState(() {
        _notifications =
            data.map((json) => NotificationItem.fromJson(json)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to load notifications';
        _isLoading = false;
      });
    }
  }

  int get unreadCount => _notifications.where((n) => !n.read).length;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, unreadCount);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, unreadCount);
            },
          ),
          actions: [
            if (unreadCount > 0)
              TextButton(
                onPressed: _markAllAsRead,
                child: Text(
                  'Mark all read',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: const Color(0xFF2196F3),
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(_errorMessage,
                        style: const TextStyle(color: Colors.red)))
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No notifications',
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'You\'re all caught up!',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: _notifications.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          thickness: 0.8,
                          color: Colors.grey[200],
                          indent: 68,
                        ),
                        itemBuilder: (context, index) {
                          return NotificationCard(
                            notification: _notifications[index],
                            onTap: () {
                              _markAsRead(_notifications[index].id);
                            },
                            onDismiss: () {
                              _dismissNotification(_notifications[index].id);
                            },
                          );
                        },
                      ),
      ),
    );
  }

  void _markAsRead(String id) async {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(read: true);
      }
    });
    try {
      await ApiService.markNotificationAsRead(id);
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  void _markAllAsRead() async {
    setState(() {
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].read) {
          _notifications[i] = _notifications[i].copyWith(read: true);
        }
      }
    });
    try {
      final result = await ApiService.markAllNotificationsAsRead();
      if (mounted && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'All notifications marked as read',
              style: GoogleFonts.roboto(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error marking all as read: $e");
    }
  }

  void _dismissNotification(String id) async {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
    try {
      await ApiService.deleteNotification(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notification dismissed',
              style: GoogleFonts.roboto(),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String time;
  final String type;
  final bool read;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    required this.read,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Notification',
      message: json['message'] ?? '',
      time: json['created_at']?.toString().split('T').first ?? '',
      type: json['type'] ?? 'info',
      read: json['read'] == true || json['is_read'] == true,
    );
  }

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    String? time,
    String? type,
    bool? read,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      time: time ?? this.time,
      type: type ?? this.type,
      read: read ?? this.read,
    );
  }
}

class NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return Colors.green;
      case 'stock':
        return Colors.blue;
      case 'prescription':
        return Colors.orange;
      case 'delivery':
        return Colors.purple;
      case 'reminder':
        return Colors.amber;
      case 'pharmacy':
        return Colors.teal;
      case 'app':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return Icons.shopping_cart;
      case 'stock':
        return Icons.inventory;
      case 'prescription':
        return Icons.description;
      case 'delivery':
        return Icons.delivery_dining;
      case 'reminder':
        return Icons.notifications_active;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'app':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getNotificationColor(notification.type);
    final icon = _getNotificationIcon(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red[600],
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 24,
        ),
      ),
      onDismissed: (direction) => onDismiss(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: notification.read ? Colors.transparent : const Color(0xFFF4F9FF),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: GoogleFonts.roboto(
                        fontSize: 14.5,
                        fontWeight: notification.read ? FontWeight.normal : FontWeight.w500,
                        color: notification.read ? Colors.black87 : Colors.black,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          notification.time,
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!notification.read)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
