import 'package:flutter_test/flutter_test.dart';
import 'package:uway_mobile/data/demo_fixtures.dart';
import 'package:uway_mobile/services/demo_uway_data_source.dart';
import 'package:uway_mobile/services/uway_data_source.dart';

void main() {
  group('DemoUwayDataSource', () {
    test('provides clearly identified sample trip and route data', () async {
      final source = DemoUwayDataSource(role: 'Passenger');

      expect(source.isDemoData, isTrue);
      expect(source.supportsGps, isFalse);
      expect(source.supportsRealtimeLocation, isFalse);
      // Finished trips stay listed, like the API now does for 14 days.
      expect(await source.getTrips(), hasLength(8));
      expect((await source.getRoute(1)).stops.map((stop) => stop.order),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect((await source.getRoute(2)).name, 'University City → King Faisal Line');
    });

    test('keeps one active Trip Intent per demo passenger and trip', () async {
      final source = DemoUwayDataSource(role: 'Passenger');
      final existing =
          await source.getMyIntent(DemoFixtures.activeIntentTripId);

      expect(existing, isNotNull);
      expect(existing!.dropOffStopId, 107);
      await expectLater(
        source.createIntent(DemoFixtures.activeIntentTripId, 108),
        throwsA(
          isA<UwayApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            409,
          ),
        ),
      );

      final changed = await source.changeDropOff(
        DemoFixtures.activeIntentTripId,
        108,
      );
      expect(changed.dropOffStopId, 108);
      expect(changed.dropOffStopName, 'UOS - W3');
      expect(changed.expectedRiderCount, 2);

      await source.cancelIntent(DemoFixtures.activeIntentTripId);
      expect(await source.getMyIntent(DemoFixtures.activeIntentTripId), isNull);
      final recreated = await source.createIntent(
        DemoFixtures.activeIntentTripId,
        109,
      );
      expect(recreated.expectedRiderCount, 2);
    });

    test('rejects a drop-off stop outside the sample route', () async {
      final source = DemoUwayDataSource(role: 'Passenger');

      await expectLater(
        source.createIntent(
          '10000000-0000-4000-8000-000000000002',
          999,
        ),
        throwsA(isA<UwayApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          400,
        )),
      );
    });

    test('supports local driver lifecycle actions without GPS simulation',
        () async {
      final source = DemoUwayDataSource(role: 'Driver', driverId: 17);
      final scheduled = (await source.getAssignedTrips()).firstWhere(
        (trip) => trip.status == 'Scheduled',
      );

      final started = await source.startTrip(scheduled.id);
      expect(started.status, 'Started');

      await source.reportNearlyFull(started.id);
      expect(source.wasReportedNearlyFull(started.id), isTrue);

      final ended = await source.endTrip(started.id);
      expect(ended.status, 'Finished');
      expect(source.supportsGps, isFalse);
      await expectLater(
        source.updateTripLocation(started.id, 25.0, 55.0),
        throwsA(isA<UwayApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          501,
        )),
      );
    });

    test('enforces role boundaries and supports marking sample inbox items',
        () async {
      final passenger = DemoUwayDataSource(role: 'Passenger');
      await expectLater(
        passenger.getAssignedTrips(),
        throwsA(isA<UwayApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        )),
      );

      final notifications = await passenger.getNotifications();
      expect(notifications, isNotEmpty);
      final unread = notifications.firstWhere((item) => !item.isRead);
      await passenger.markNotificationRead(unread.id);
      expect(
        (await passenger.getNotifications())
            .firstWhere((item) => item.id == unread.id)
            .isRead,
        isTrue,
      );
    });
  });
}
