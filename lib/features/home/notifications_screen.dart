import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Placeholder for real data fetching
  final bool _loading = false;
  final List<Map<String, dynamic>> _notifications = [
    {
      'type': 'like',
      'title': 'Alex liked your post',
      'time': '2m ago',
      'icon': Icons.favorite_rounded,
      'color': Colors.redAccent,
    },
    {
      'type': 'comment',
      'title': 'Sarah commented: "Great shot!"',
      'time': '1h ago',
      'icon': Icons.chat_bubble_rounded,
      'color': Colors.blueAccent,
    },
    {
      'type': 'xp',
      'title': 'You earned 100 XP from Brick Game!',
      'time': '3h ago',
      'icon': Icons.bolt_rounded,
      'color': Colors.amber,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _notifications.isEmpty
              ? _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    return _NotificationTile(data: item);
                  },
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _NotificationTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final IconData icon = data['icon'];
    final Color iconColor = data['color'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['title'],
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['time'],
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, color: colors.textMuted, size: 64),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you get updates, they\'ll appear here.',
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
