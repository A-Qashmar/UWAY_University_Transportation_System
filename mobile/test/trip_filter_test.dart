import 'package:flutter_test/flutter_test.dart';
import 'package:uway_mobile/data/demo_fixtures.dart';
import 'package:uway_mobile/models/passenger_models.dart';
import 'package:uway_mobile/models/trip_filter.dart';

void main() {
  // Men's sample trips only: this mirrors what a male passenger loads.
  final trips =
      DemoFixtures.trips().where((trip) => trip.audience == 'M').toList();

  test('returns all trips, ordered by departure, when no filter is set', () {
    final result = filterTrips(trips);
    expect(result, hasLength(trips.length));
    for (var i = 1; i < result.length; i++) {
      expect(
        result[i - 1].departureAtUtc.isAfter(result[i].departureAtUtc),
        isFalse,
      );
    }
  });

  test('filters by status', () {
    final started = filterTrips(trips, status: 'Started');
    expect(started, hasLength(1));
    expect(started.single.status, 'Started');
  });

  test('query matches route code and bus number, case-insensitively', () {
    expect(filterTrips(trips, query: 'kf-in'), hasLength(4));
    expect(filterTrips(trips, query: 'bus-02'), hasLength(1));
    expect(filterTrips(trips, query: 'does-not-exist'), isEmpty);
  });

  test('date filter matches the local departure day only', () {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final onYesterday = filterTrips(trips, date: yesterday);
    expect(onYesterday.any((trip) => trip.status == 'Finished'), isTrue);
    expect(filterTrips(trips, date: DateTime(2000, 1, 1)), isEmpty);
  });

  test('statusesPresent lists only statuses in the data, in stable order', () {
    expect(
      statusesPresent(trips),
      ['Scheduled', 'Started', 'Finished'],
    );
    expect(statusesPresent(const <UwayTrip>[]), isEmpty);
  });

  group('stop and time filters', () {
    final routes = {for (final r in DemoFixtures.routes) r.id: r};
    const route = DemoFixtures.route;
    final first = route.stops.first.id;
    final middle = route.stops[1].id;
    final last = route.stops.last.id;
    final onRoute = trips.where((trip) => trip.routeId == route.id).toList();
    bool onlyRoute(List<UwayTrip> found) =>
        found.isNotEmpty && found.every((trip) => trip.routeId == route.id);

    test('From before To keeps the trips, the reverse direction does not', () {
      final forward = filterTrips(
        trips,
        fromStopId: first,
        toStopId: last,
        routes: routes,
      );
      expect(forward, hasLength(onRoute.length));
      expect(onlyRoute(forward), isTrue);
      expect(
        filterTrips(trips, fromStopId: last, toStopId: first, routes: {
          route.id: route,
        }),
        isEmpty,
      );
    });

    test('a single stop must not be the wrong end of the route', () {
      final only = {route.id: route};
      expect(filterTrips(trips, fromStopId: last, routes: only), isEmpty);
      expect(filterTrips(trips, toStopId: first, routes: only), isEmpty);
      expect(
        filterTrips(trips, fromStopId: middle, routes: only),
        hasLength(onRoute.length),
      );
      expect(
        filterTrips(trips, toStopId: last, routes: only),
        hasLength(onRoute.length),
      );
    });

    test('trips with an unloaded route are hidden by a stop filter only', () {
      expect(filterTrips(trips, fromStopId: first), isEmpty);
      expect(filterTrips(trips), hasLength(trips.length));
    });

    test('departure-time filter uses the local time of day', () {
      expect(filterTrips(trips, afterMinutes: 0), hasLength(trips.length));
      expect(filterTrips(trips, afterMinutes: 24 * 60), isEmpty);
    });

    test('distinctStops de-duplicates stops shared by several routes', () {
      final stops = distinctStops(DemoFixtures.routes);
      final ids = stops.map((stop) => stop.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      // 10 King Faisal/campus stops + 6 Al Heerah stops.
      expect(stops, hasLength(16));
    });
  });
}
