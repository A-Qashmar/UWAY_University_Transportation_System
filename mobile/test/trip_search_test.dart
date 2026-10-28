import 'package:flutter_test/flutter_test.dart';
import 'package:uway_mobile/data/demo_fixtures.dart';
import 'package:uway_mobile/models/passenger_models.dart';
import 'package:uway_mobile/models/trip_filter.dart';

UwayTrip _trip(String id, String code, DateTime at, String status) => UwayTrip(
      id: id,
      routeId: 1,
      routeCode: code,
      departureAtUtc: at,
      status: status,
    );

void main() {
  dropOffOptionsTests();
  group('routeDirection', () {
    test('the demo routes are classified by their campus stops', () {
      expect(routeDirection(DemoFixtures.route), RouteDirection.toCampus);
      expect(routeDirection(DemoFixtures.routeFromCampus),
          RouteDirection.fromCampus);
      expect(routeDirection(DemoFixtures.routeHeerah), RouteDirection.toCampus);
    });

    test('a route ending at a campus stop goes to the campus', () {
      const reversed = UwayRoute(
        id: 9,
        name: 'Reversed',
        stops: [
          UwayRouteStop(id: 1, name: 'Al Majaz Park', order: 1),
          UwayRouteStop(id: 2, name: 'UOS - Medical College', order: 2),
        ],
      );
      expect(routeDirection(reversed), RouteDirection.toCampus);
    });

    test('routes without a campus end, or not loaded, stay unknown', () {
      const neutral = UwayRoute(
        id: 3,
        name: 'King Faisal',
        stops: [
          UwayRouteStop(id: 1, name: 'Al Majaz Park', order: 1),
          UwayRouteStop(id: 2, name: 'Mega Mall', order: 2),
        ],
      );
      expect(routeDirection(neutral), RouteDirection.unknown);
      expect(routeDirection(null), RouteDirection.unknown);
      expect(directionMatches(TripDirectionFilter.any, neutral), isTrue);
      expect(directionMatches(TripDirectionFilter.toCampus, neutral), isFalse);
      expect(
          directionMatches(TripDirectionFilter.fromCampus, neutral), isFalse);
    });
  });

  group('rankTrips', () {
    final now = DateTime(2026, 10, 26, 12);

    test('in progress first, then day, time of day and route code', () {
      final trips = [
        _trip('tomorrow', 'A', DateTime(2026, 10, 27, 8), 'Scheduled'),
        _trip('late', 'A', DateTime(2026, 10, 26, 9, 30), 'Scheduled'),
        _trip('early-b', 'B', DateTime(2026, 10, 26, 7), 'Scheduled'),
        _trip('early-a', 'A', DateTime(2026, 10, 26, 7), 'Scheduled'),
        _trip('running', 'C', DateTime(2026, 10, 26, 11), 'Started'),
      ];
      final ranked = rankTrips(trips, now: now);
      expect(
        ranked.map((trip) => trip.id).toList(),
        ['running', 'early-a', 'early-b', 'late', 'tomorrow'],
      );
    });

    test('drops trips from before today unless still in progress', () {
      final trips = [
        _trip('old', 'A', DateTime(2026, 10, 25, 20), 'Finished'),
        _trip('old-running', 'A', DateTime(2026, 10, 25, 23), 'Started'),
        _trip('today', 'A', DateTime(2026, 10, 26, 8), 'Scheduled'),
      ];
      final ranked = rankTrips(trips, now: now);
      expect(
        ranked.map((trip) => trip.id).toList(),
        ['old-running', 'today'],
      );
    });

    test('does not hide delayed or cancelled trips the source returned', () {
      final trips = [
        UwayTrip(
          id: 'c',
          routeId: 1,
          routeCode: 'A',
          departureAtUtc: DateTime(2026, 10, 26, 8),
          status: 'Scheduled',
          cancelledAtUtc: DateTime(2026, 10, 26, 6),
        ),
        UwayTrip(
          id: 'd',
          routeId: 1,
          routeCode: 'A',
          departureAtUtc: DateTime(2026, 10, 26, 9),
          status: 'Scheduled',
          delayMinutes: 10,
        ),
      ];
      expect(rankTrips(trips, now: now), hasLength(2));
    });
  });

  test('departure times are distinct, sorted and formatted as HH:mm', () {
    final trips = [
      _trip('1', 'A', DateTime(2026, 10, 26, 9, 5), 'Scheduled'),
      _trip('2', 'A', DateTime(2026, 10, 27, 9, 5), 'Scheduled'),
      _trip('3', 'A', DateTime(2026, 10, 26, 7, 45), 'Scheduled'),
    ];
    final times = departureTimesOfDay(trips);
    expect(times, [7 * 60 + 45, 9 * 60 + 5]);
    expect(times.map(formatMinutes).toList(), ['07:45', '09:05']);
  });
}

void dropOffOptionsTests() {
  group('dropOffOptions', () {
    test('to-campus route offers only campus points', () {
      final names = dropOffOptions(DemoFixtures.routes[0]).map((s) => s.name);
      expect(names.every((n) => n.startsWith('UOS')), isTrue);
      expect(names.length, 4);
    });
    test('return route offers only the other gathering points', () {
      final names = dropOffOptions(DemoFixtures.routes[1]).map((s) => s.name);
      expect(names.any((n) => n.startsWith('UOS')), isFalse);
      expect(names.length, 6);
    });
  });
}
