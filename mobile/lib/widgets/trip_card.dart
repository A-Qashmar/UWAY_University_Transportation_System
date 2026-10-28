import 'package:flutter/material.dart';

import '../models/passenger_models.dart';
import '../theme/uway_theme.dart';

/// Shared Passenger trip card used by Browse Trips and Your Trips.
class TripCard extends StatelessWidget {
  const TripCard({
    required this.trip,
    required this.onTap,
    this.dropOffName,
    this.routeName,
    super.key,
  });

  final UwayTrip trip;
  final VoidCallback onTap;

  /// Shown only where the passenger has an active Trip Intent.
  final String? dropOffName;

  /// Route (line) name when the caller has loaded it; otherwise the route code
  /// is shown, never a guessed name.
  final String? routeName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: UwayColors.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      color: UwayColors.gold,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (routeName != null && routeName!.trim().isNotEmpty)
                              ? routeName!
                              : trip.displayName,
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Departs ${formatTripDate(trip.departureAtUtc)}',
                          style: textTheme.bodyMedium?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TripStatusPill(status: trip.status),
                ],
              ),
              if (trip.busNumber != null || dropOffName != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    if (trip.busNumber != null)
                      _InfoChip(
                        icon: Icons.confirmation_number_outlined,
                        text: 'Bus ${trip.busNumber}',
                      ),
                    if (dropOffName != null)
                      _InfoChip(
                        icon: Icons.place_outlined,
                        text: 'Drop-off: $dropOffName',
                      ),
                  ],
                ),
              ],
              if (trip.isCancelled) ...[
                const SizedBox(height: 10),
                Text(
                  'Cancelled',
                  style: TextStyle(
                    color: context.uwayDanger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (trip.delayMinutes > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Delayed ${trip.delayMinutes} min${trip.delayMinutes == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: context.uwayWarning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(child: Text(text)),
        ],
      );
}

class TripStatusPill extends StatelessWidget {
  const TripStatusPill({required this.status, super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = tripStatusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            humanTripStatus(status),
            style:
                Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Status is always shown as text next to its colour.
Color tripStatusColor(BuildContext context, String status) =>
    switch (status) {
      'Started' => context.uwaySuccess,
      'Scheduled' => Theme.of(context).colorScheme.primary,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };

String humanTripStatus(String status) => switch (status) {
      'Started' => 'Started',
      'Finished' => 'Finished',
      _ => status,
    };

String formatTripDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatLongDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]} ${date.year}';

String formatShortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
