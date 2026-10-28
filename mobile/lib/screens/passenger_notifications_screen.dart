import 'dart:async';

import 'package:flutter/material.dart';

import '../models/passenger_models.dart';
import '../services/uway_data_source.dart';
import '../widgets/notification_bell.dart';
import '../widgets/passenger_state_panel.dart'; 

class PassengerNotificationsScreen extends StatefulWidget {
  const PassengerNotificationsScreen({required this.apiClient, super.key});

  final UwayDataSource apiClient;

  @override
  State<PassengerNotificationsScreen> createState() =>
      _PassengerNotificationsScreenState();
}

class _PassengerNotificationsScreenState
    extends State<PassengerNotificationsScreen> {
  late Future<List<PassengerNotification>> _notifications;
  final Set<String> _markingRead = {};

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _notifications = widget.apiClient.getNotifications();
    // Pick up new messages while the inbox is open.
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final next = widget.apiClient.getNotifications();
      next.then((_) {
        if (mounted) setState(() => _notifications = next);
      }, onError: (_) {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.apiClient.getNotifications();
    setState(() {
      _notifications = future;
    });
    try {
      await future;
    } catch (_) {
      // The error state is shown by the FutureBuilder.
    }
  }

  Future<void> _markRead(PassengerNotification notification) async {
    setState(() => _markingRead.add(notification.id));
    try {
      await widget.apiClient.markNotificationRead(notification.id);
      notificationsChanged.value++;
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.then(
          (items) => items
              .map(
                (item) => item.id == notification.id
                    ? PassengerNotification(
                        id: item.id,
                        tripId: item.tripId,
                        type: item.type,
                        title: item.title,
                        message: item.message,
                        createdAtUtc: item.createdAtUtc,
                        readAtUtc: DateTime.now(),
                      )
                    : item,
              )
              .toList(growable: false),
        );
      });
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _markingRead.remove(notification.id));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<PassengerNotification>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingPanel(message: 'Loading inbox…');
          }
          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  const SizedBox(height: 90),
                  PassengerStatePanel(
                    title: snapshot.error is UwayApiException &&
                            (snapshot.error! as UwayApiException).statusCode ==
                                401
                        ? 'Sign-in is required'
                        : 'Notifications could not load',
                    message: snapshot.error.toString(),
                    icon: Icons.notifications_off_outlined,
                    action: OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data ?? const <PassengerNotification>[];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 100),
                  PassengerStatePanel(
                    title: 'Your inbox is clear',
                    message:
                        'Updates about your trips and reports will appear here.',
                    icon: Icons.notifications_none,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const Text('Updates about your trips and reports. Unread ones are highlighted.'),
                const SizedBox(height: 14),
                for (final notification in items) ...[
                  _NotificationCard(
                    notification: notification,
                    isMarking: _markingRead.contains(notification.id),
                    onMarkRead: notification.isRead
                        ? null
                        : () => _markRead(notification),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isMarking,
    this.onMarkRead,
  });

  final PassengerNotification notification;
  final bool isMarking;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final color = notification.isRead
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.primary;
    return Card(
      color: notification.isRead
          ? null
          : Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(notification.type), color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    notification.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  notification.isRead ? 'Read' : 'Unread',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(notification.message),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(notification.createdAtUtc),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (onMarkRead != null)
                  TextButton(
                    onPressed: isMarking ? null : onMarkRead,
                    child: isMarking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mark read'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String type) => switch (type) {
      'TripStarted' => Icons.play_circle_outline,
      'TripDelayed' => Icons.schedule,
      'TripCancelled' => Icons.event_busy_outlined,
      'TripCompleted' => Icons.check_circle_outline,
      'TripReinstated' => Icons.event_available_outlined,
      'BusApproachingDropOff' => Icons.place_outlined,
      'ReportReceived' => Icons.inbox_outlined,
      'ReportUpdated' => Icons.support_agent_outlined,
      'TripFinished' => Icons.check_circle_outline,
      'TripAssigned' => Icons.assignment_outlined,
      'TripChanged' => Icons.edit_calendar_outlined,
      'BusNearlyFull' => Icons.groups_2_outlined,
      _ => Icons.info_outline,
    };

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
