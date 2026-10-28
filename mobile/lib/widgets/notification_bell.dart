import 'dart:async';

import 'package:flutter/material.dart';

import '../services/uway_data_source.dart';

/// Bumped whenever the user reads a notification, so every bell recounts.
final ValueNotifier<int> notificationsChanged = ValueNotifier<int>(0);

/// Bell for the app bar: a red badge shows how many messages are unread. It
/// checks for new messages every [interval] and tells the user when one arrives.
class NotificationBell extends StatefulWidget {
  const NotificationBell({
    required this.apiClient,
    required this.onPressed,
    this.interval = const Duration(seconds: 10),
    super.key,
  });

  final UwayDataSource apiClient;
  final VoidCallback onPressed;
  final Duration interval;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  Timer? _timer;
  int _unread = 0;
  final Set<String> _seen = {};
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    notificationsChanged.addListener(_check);
    _check();
    _timer = Timer.periodic(widget.interval, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    notificationsChanged.removeListener(_check);
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final items = await widget.apiClient.getNotifications(take: 50);
      if (!mounted) return;
      final unread = items.where((item) => !item.isRead).toList();
      final fresh = unread.where((item) => !_seen.contains(item.id)).toList();
      _seen.addAll(unread.map((item) => item.id));
      setState(() => _unread = unread.length);
      if (!_firstLoad && fresh.isNotEmpty) {
        final latest = fresh.first;
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            content: Text(
              fresh.length == 1
                  ? '${latest.title}: ${latest.message}'
                  : '${fresh.length} new notifications',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            action: SnackBarAction(label: 'Open', onPressed: widget.onPressed),
          ),
        );
      }
      _firstLoad = false;
    } on Object {
      // A missed check is fine; the next one tries again.
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: _unread > 0
            ? 'Notifications ($_unread unread)'
            : 'Notifications',
        onPressed: widget.onPressed,
        icon: Badge(
          isLabelVisible: _unread > 0,
          label: Text(_unread > 9 ? '9+' : '$_unread'),
          backgroundColor: const Color(0xFFD32F2F),
          textColor: Colors.white,
          child: Icon(_unread > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded),
        ),
      );
}
