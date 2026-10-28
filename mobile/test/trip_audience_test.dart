import 'package:flutter_test/flutter_test.dart';
import 'package:uway_mobile/data/demo_fixtures.dart';
import 'package:uway_mobile/services/demo_uway_data_source.dart';
import 'package:uway_mobile/services/uway_data_source.dart';

void main() {
  test('a passenger only sees trips for their own gender', () async {
    final men = DemoUwayDataSource(role: 'Passenger', passengerGender: 'M');
    final women = DemoUwayDataSource(role: 'Passenger', passengerGender: 'F');

    final menTrips = await men.getTrips();
    final womenTrips = await women.getTrips();

    expect(menTrips, isNotEmpty);
    expect(womenTrips, isNotEmpty);
    expect(menTrips.every((t) => t.audience == 'M'), isTrue);
    expect(womenTrips.every((t) => t.audience == 'F'), isTrue);
  });

  test('a trip for the other gender cannot be opened or joined', () async {
    final women = DemoUwayDataSource(role: 'Passenger', passengerGender: 'F');
    await expectLater(
      women.getTrip(DemoFixtures.activeIntentTripId),
      throwsA(isA<UwayApiException>()),
    );
    await expectLater(
      women.createIntent(DemoFixtures.activeIntentTripId, 107),
      throwsA(isA<UwayApiException>()),
    );
  });
}
