import 'uway_data_source.dart';

/// Reads the name of each route with the existing route read. A route that
/// cannot be loaded is simply left out; callers fall back to the route code
/// and never guess a name.
Future<Map<int, String>> loadRouteNames(
  UwayDataSource source,
  Iterable<int> routeIds,
) async {
  final names = <int, String>{};
  await Future.wait(routeIds.toSet().map((id) async {
    try {
      final route = await source.getRoute(id);
      if (route.name.trim().isNotEmpty) names[id] = route.name;
    } catch (_) {
      // Leave this route unnamed.
    }
  }));
  return names;
}
