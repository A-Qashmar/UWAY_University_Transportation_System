import '../models/passenger_models.dart';

/// Sample data for the Demo Data mode. The routes, stop names and departure
/// times are taken from the university's real bus-stop list (King Faisal and
/// Al Heerah routes, campus stops) so the demo looks like the real service.
/// It is still sample data: nothing here comes from the API.
class DemoFixtures {
  const DemoFixtures._();

  static const activeIntentTripId = '10000000-0000-4000-8000-000000000002';
  static const secondIntentTripId = '10000000-0000-4000-8000-000000000003';
  static const activeIntentId = '30000000-0000-4000-8000-000000000001';

  /// King Faisal line, morning direction: ends at the campus stops.
  static const route = UwayRoute(
    id: 1,
    name: 'King Faisal Line → University City',
    stops: [
      UwayRouteStop(
          id: 101, name: 'Next to the Sharjah Cooperative Society', order: 1,
          latitude: 25.334213,
          longitude: 55.371695),
      UwayRouteStop(id: 102, name: 'In front of Adnoc Station', order: 2,
          latitude: 25.329886,
          longitude: 55.37174),
      UwayRouteStop(id: 103, name: 'In front of Alhalabi Factory', order: 3,
          latitude: 25.315974,
          longitude: 55.381562),
      UwayRouteStop(id: 104, name: 'In front of Al-Majaz Park', order: 4,
          latitude: 25.3232514,
          longitude: 55.3884364),
      UwayRouteStop(id: 105, name: 'In front of King Faisal Mosque', order: 5,
          latitude: 25.3488178,
          longitude: 55.3870176),
      UwayRouteStop(id: 106, name: 'In front of Mega Mall', order: 6,
          latitude: 25.3443917,
          longitude: 55.3970298),
      UwayRouteStop(id: 107, name: 'UOS - M3', order: 7,
          latitude: 25.283234,
          longitude: 55.474651),
      UwayRouteStop(id: 108, name: 'UOS - W3', order: 8,
          latitude: 25.291245,
          longitude: 55.48056),
      UwayRouteStop(id: 109, name: 'UOS - Fine Arts', order: 9,
          latitude: 25.296264,
          longitude: 55.482804),
      UwayRouteStop(id: 110, name: 'UOS - Medical College', order: 10,
          latitude: 25.301524,
          longitude: 55.486406),
    ],
  );

  /// King Faisal line, return direction: starts at the campus.
  static const routeFromCampus = UwayRoute(
    id: 2,
    name: 'University City → King Faisal Line',
    stops: [
      UwayRouteStop(id: 107, name: 'UOS - M3', order: 1,
          latitude: 25.283234,
          longitude: 55.474651),
      UwayRouteStop(id: 106, name: 'In front of Mega Mall', order: 2,
          latitude: 25.3443917,
          longitude: 55.3970298),
      UwayRouteStop(id: 105, name: 'In front of King Faisal Mosque', order: 3,
          latitude: 25.3488178,
          longitude: 55.3870176),
      UwayRouteStop(id: 104, name: 'In front of Al-Majaz Park', order: 4,
          latitude: 25.3232514,
          longitude: 55.3884364),
      UwayRouteStop(id: 103, name: 'In front of Alhalabi Factory', order: 5,
          latitude: 25.315974,
          longitude: 55.381562),
      UwayRouteStop(id: 102, name: 'In front of Adnoc Station', order: 6,
          latitude: 25.329886,
          longitude: 55.37174),
      UwayRouteStop(
          id: 101, name: 'Next to the Sharjah Cooperative Society', order: 7,
          latitude: 25.334213,
          longitude: 55.371695),
    ],
  );

  static const routeHeerah = UwayRoute(
    id: 3,
    name: 'Al Heera Line → University City',
    stops: [
      UwayRouteStop(id: 201, name: 'Rona Square', order: 1,
          latitude: 25.3932825,
          longitude: 55.4266167),
      UwayRouteStop(id: 202, name: 'In front of Al-Hira Police', order: 2,
          latitude: 25.386643,
          longitude: 55.414513),
      UwayRouteStop(id: 203, name: 'In front of Al-Fisht Park', order: 3,
          latitude: 25.383798,
          longitude: 55.408108),
      UwayRouteStop(id: 204, name: 'Nasiriyah Station', order: 4,
          latitude: 25.3711055,
          longitude: 55.4112827),
      UwayRouteStop(
          id: 205, name: "In front of HH the Ruler's office", order: 5,
          latitude: 25.3580182,
          longitude: 55.4256892),
      UwayRouteStop(id: 206, name: 'Opposite to Sharjah TV', order: 6,
          latitude: 25.3529984,
          longitude: 55.4257253),
      UwayRouteStop(id: 107, name: 'UOS - M3', order: 7,
          latitude: 25.283234,
          longitude: 55.474651),
      UwayRouteStop(id: 110, name: 'UOS - Medical College', order: 8,
          latitude: 25.301524,
          longitude: 55.486406),
    ],
  );

  static const routes = [route, routeFromCampus, routeHeerah];

  static List<UwayTrip> trips() {
    final now = DateTime.now();
    DateTime at(int hour, int minute, {int dayOffset = 0}) =>
        DateTime(now.year, now.month, now.day + dayOffset, hour, minute);
    return [
      UwayTrip(
        id: '10000000-0000-4000-8000-000000000001',
        routeId: route.id,
        routeCode: 'KF-IN',
        routeName: route.name,
        departureAtUtc: at(8, 30),
        audience: 'M',
        status: 'Scheduled',
        busNumber: 'DEMO-BUS-01',
        driverName: 'Sample Driver',
      ),
      UwayTrip(
        id: '10000000-0000-4000-8000-000000000002',
        routeId: route.id,
        routeCode: 'KF-IN',
        routeName: route.name,
        departureAtUtc: at(8, 0),
        audience: 'M',
        status: 'Scheduled',
        delayMinutes: 8,
        delayReason: 'Traffic on Jamal Abdul Nasser Street',
        busNumber: 'DEMO-BUS-02',
        driverName: 'Sample Driver',
      ),
      UwayTrip(
        id: '10000000-0000-4000-8000-000000000003',
        routeId: route.id,
        routeCode: 'KF-IN',
        routeName: route.name,
        departureAtUtc: at(6, 15),
        audience: 'M',
        status: 'Started',
        startedAtUtc: at(6, 17),
        busNumber: 'DEMO-BUS-03',
        driverName: 'Sample Driver',
      ),
      UwayTrip(
        id: '10000000-0000-4000-8000-000000000004',
        routeId: route.id,
        routeCode: 'KF-IN',
        routeName: route.name,
        departureAtUtc: at(8, 0, dayOffset: -1),
        audience: 'M',
        status: 'Finished',
        startedAtUtc: at(8, 2, dayOffset: -1),
        endedAtUtc: at(8, 55, dayOffset: -1),
        busNumber: 'DEMO-BUS-01',
        driverName: 'Sample Driver',
      ),
      UwayTrip(
        id: '10000000-0000-4000-8000-000000000005',
        routeId: routeFromCampus.id,
        routeCode: 'KF-OUT',
        routeName: routeFromCampus.name,
        departureAtUtc: at(12, 0),
        audience: 'M',
        status: 'Scheduled',
        busNumber: 'DEMO-BUS-04',
        driverName: 'Sample Driver',
      ),
      UwayTrip(
        id: '10000000-0000-4000-8000-000000000006',
        routeId: routeFromCampus.id,
        routeCode: 'KF-OUT',
        routeName: routeFromCampus.name,
        departureAtUtc: at(13, 0),
        audience: 'M',
        status: 'Scheduled',
        busNumber: 'DEMO-BUS-05',
        driverName: 'Sample Driver',
      ),
      UwayTrip(
        id: '10000000-0000-4000-8000-000000000007',
        routeId: routeHeerah.id,
        routeCode: 'HRH-IN',
        routeName: routeHeerah.name,
        departureAtUtc: at(8, 0),
        audience: 'M',
        status: 'Scheduled',
        busNumber: 'DEMO-BUS-06',
        driverName: 'Sample Driver',
      ),
      UwayTrip(
        id: '10000000-0000-4000-8000-000000000008',
        routeId: routeHeerah.id,
        routeCode: 'HRH-IN',
        routeName: routeHeerah.name,
        departureAtUtc: at(9, 0),
        audience: 'M',
        status: 'Scheduled',
        busNumber: 'DEMO-BUS-07',
        driverName: 'Sample Driver',
      ),
      UwayTrip(
        id: '10000000-0000-4000-8000-000000000009',
        routeId: route.id,
        routeCode: 'KF-IN',
        routeName: route.name,
        departureAtUtc: at(8, 15),
        audience: 'F',
        status: 'Scheduled',
        busNumber: 'DEMO-BUS-08',
        driverName: 'Sample Driver',
      ),
      UwayTrip(
        id: '10000000-0000-4000-8000-000000000010',
        routeId: route.id,
        routeCode: 'KF-IN',
        routeName: route.name,
        departureAtUtc: at(9, 45),
        audience: 'F',
        status: 'Scheduled',
        busNumber: 'DEMO-BUS-08',
        driverName: 'Sample Driver',
      ),
      UwayTrip(
        id: '10000000-0000-4000-8000-000000000011',
        routeId: routeFromCampus.id,
        routeCode: 'KF-OUT',
        routeName: routeFromCampus.name,
        departureAtUtc: at(12, 30),
        audience: 'F',
        status: 'Scheduled',
        busNumber: 'DEMO-BUS-08',
        driverName: 'Sample Driver',
      ),
      UwayTrip(
        id: '10000000-0000-4000-8000-000000000012',
        routeId: routeHeerah.id,
        routeCode: 'HRH-IN',
        routeName: routeHeerah.name,
        departureAtUtc: at(8, 30),
        audience: 'F',
        status: 'Scheduled',
        busNumber: 'DEMO-BUS-09',
        driverName: 'Sample Driver',
      ),
    ];
  }

  static List<PassengerNotification> notifications() {
    final now = DateTime.now();
    return [
      PassengerNotification(
        id: '20000000-0000-4000-8000-000000000001',
        tripId: '10000000-0000-4000-8000-000000000002',
        type: 'TripDelayed',
        title: 'Trip delayed',
        message:
            'The 08:00 King Faisal trip is delayed by 8 minutes. Traffic on Jamal Abdul Nasser Street.',
        createdAtUtc: now.subtract(const Duration(minutes: 3)),
      ),
      PassengerNotification(
        id: '20000000-0000-4000-8000-000000000002',
        tripId: '10000000-0000-4000-8000-000000000003',
        type: 'TripStarted',
        title: 'Trip started',
        message: 'The driver started the 06:15 King Faisal trip.',
        createdAtUtc: now.subtract(const Duration(minutes: 5)),
        readAtUtc: now.subtract(const Duration(minutes: 4)),
      ),
      PassengerNotification(
        id: '20000000-0000-4000-8000-000000000003',
        tripId: '10000000-0000-4000-8000-000000000002',
        type: 'BusApproachingDropOff',
        title: 'Approaching your selected stop',
        message: 'The bus is approaching UOS - M3.',
        createdAtUtc: now.subtract(const Duration(minutes: 1)),
      ),
    ];
  }
}
