import 'passenger_models.dart';

/// Local filtering of the already-loaded trip list. Nothing here calls the API.
///
/// * [query] matches the route code or bus number (when the API provides it).
/// * [date] matches the local departure day.
/// * [status] matches the trip status.
/// * [afterMinutes] keeps trips whose trip departure time of day is at or after
///   that many minutes past midnight. It is the departure from the start of the
///   route; per-stop times are not available from the API.
/// * [fromStopId] / [toStopId] keep trips whose route serves those stops in the
///   travelling direction (the From stop comes before the To stop in the route
///   order). A trip whose route could not be loaded is excluded while a stop
///   filter is active, never guessed.
List<UwayTrip> filterTrips(
  List<UwayTrip> trips, {
  String query = '',
  DateTime? date,
  String? status,
  int? fromStopId,
  int? toStopId,
  int? afterMinutes,
  Map<int, UwayRoute> routes = const {},
}) {
  final needle = query.trim().toLowerCase();
  final result = trips.where((trip) {
    if (status != null && trip.status != status) return false;
    if (date != null && !_sameDay(trip.departureAtUtc, date)) return false;
    if (afterMinutes != null) {
      final local = trip.departureAtUtc.toLocal();
      if (local.hour * 60 + local.minute < afterMinutes) return false;
    }
    if (!routeServes(routes[trip.routeId], fromStopId, toStopId)) {
      return false;
    }
    if (needle.isEmpty) return true;
    final haystack = '${trip.routeCode} ${trip.routeName ?? ''} ${trip.busNumber ?? ''}'.toLowerCase();
    return haystack.contains(needle);
  }).toList();
  result.sort((a, b) => a.departureAtUtc.compareTo(b.departureAtUtc));
  return result;
}

/// Whether [route] carries a passenger from [fromStopId] to [toStopId].
/// With only one of them set, the stop must not be the wrong end of the route.
bool routeServes(UwayRoute? route, int? fromStopId, int? toStopId) {
  if (fromStopId == null && toStopId == null) return true;
  if (route == null) return false;
  final stops = [...route.stops]..sort((a, b) => a.order.compareTo(b.order));
  final fromIndex =
      fromStopId == null ? null : stops.indexWhere((s) => s.id == fromStopId);
  final toIndex =
      toStopId == null ? null : stops.indexWhere((s) => s.id == toStopId);
  if (fromIndex == -1 || toIndex == -1) return false;
  if (fromIndex != null && toIndex != null) return fromIndex < toIndex;
  if (fromIndex != null) return fromIndex < stops.length - 1;
  return toIndex! > 0;
}

/// Distinct stops across [routes], sorted by name, for the From/To pickers.
List<UwayRouteStop> distinctStops(Iterable<UwayRoute> routes) {
  final byId = <int, UwayRouteStop>{};
  for (final route in routes) {
    for (final stop in route.stops) {
      byId.putIfAbsent(stop.id, () => stop);
    }
  }
  return byId.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Distinct statuses present in [trips], in a stable passenger-friendly order.
List<String> statusesPresent(List<UwayTrip> trips) {
  const order = ['Scheduled', 'Started', 'Finished'];
  final present = trips.map((trip) => trip.status).toSet();
  final known = order.where(present.contains).toList();
  final other = present.where((status) => !order.contains(status)).toList()
    ..sort();
  return [...known, ...other];
}

bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// Direction chosen in the search form. The API trip/route data has no
/// direction field, so it is inferred from the route's stop names (see
/// [routeDirection]); routes it cannot classify only appear under "Any".
enum TripDirectionFilter { any, toCampus, fromCampus }

enum RouteDirection { toCampus, fromCampus, unknown }

const _campusMarkers = [
  'campus',
  'university',
  'uos',
  'hct',
  'qasimia',
  'aus -',
  'medical college',
  'fine arts',
];

/// Whether a stop is one of the University City (campus) points.
bool isCampusStopName(String name) => _isCampusStop(name);

bool _isCampusStop(String name) {
  final lower = name.toLowerCase();
  return _campusMarkers.any((marker) => lower.contains(marker));
}

/// A route that starts at a campus stop leaves the campus; one that ends at a
/// campus stop goes to it. Anything else (including a route that could not be
/// loaded) is [RouteDirection.unknown] and is never guessed.
RouteDirection routeDirection(UwayRoute? route) {
  if (route == null || route.stops.isEmpty) return RouteDirection.unknown;
  final stops = [...route.stops]..sort((a, b) => a.order.compareTo(b.order));
  final first = _isCampusStop(stops.first.name);
  final last = _isCampusStop(stops.last.name);
  if (first && !last) return RouteDirection.fromCampus;
  if (last && !first) return RouteDirection.toCampus;
  return RouteDirection.unknown;
}

/// Stops a rider may pick as drop-off. Trips to the campus end at one of the
/// campus points; trips from the campus drop riders at the other gathering
/// points. A route that cannot be classified offers all of its stops.
List<UwayRouteStop> dropOffOptions(UwayRoute? route) {
  if (route == null) return const [];
  final stops = [...route.stops]..sort((a, b) => a.order.compareTo(b.order));
  return switch (routeDirection(route)) {
    RouteDirection.toCampus =>
      stops.where((s) => _isCampusStop(s.name)).toList(growable: false),
    RouteDirection.fromCampus =>
      stops.where((s) => !_isCampusStop(s.name)).toList(growable: false),
    RouteDirection.unknown => stops,
  };
}

bool directionMatches(TripDirectionFilter filter, UwayRoute? route) =>
    switch (filter) {
      TripDirectionFilter.any => true,
      TripDirectionFilter.toCampus =>
        routeDirection(route) == RouteDirection.toCampus,
      TripDirectionFilter.fromCampus =>
        routeDirection(route) == RouteDirection.fromCampus,
    };

/// Local departure time of day in minutes after midnight.
int tripMinutes(UwayTrip trip) {
  final local = trip.departureAtUtc.toLocal();
  return local.hour * 60 + local.minute;
}

String formatMinutes(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Distinct departure times of day (sorted) present in [trips].
List<int> departureTimesOfDay(Iterable<UwayTrip> trips) =>
    trips.map(tripMinutes).toSet().toList()..sort();

/// Search-result order: trips in progress first, then by day from today, then
/// by time of day, then by route code. Trips that departed before today are
/// dropped unless they are still in progress. Nothing is removed for being
/// delayed or cancelled when the data source returns them.
List<UwayTrip> rankTrips(List<UwayTrip> trips, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final startOfToday = DateTime(current.year, current.month, current.day);
  final kept = trips
      .where((trip) =>
          trip.isInProgress ||
          !trip.departureAtUtc.toLocal().isBefore(startOfToday))
      .toList();
  kept.sort((a, b) {
    final progress = (a.isInProgress ? 0 : 1).compareTo(b.isInProgress ? 0 : 1);
    if (progress != 0) return progress;
    final la = a.departureAtUtc.toLocal();
    final lb = b.departureAtUtc.toLocal();
    final day = DateTime(la.year, la.month, la.day)
        .compareTo(DateTime(lb.year, lb.month, lb.day));
    if (day != 0) return day;
    final time = tripMinutes(a).compareTo(tripMinutes(b));
    if (time != 0) return time;
    return a.routeCode.compareTo(b.routeCode);
  });
  return kept;
}
