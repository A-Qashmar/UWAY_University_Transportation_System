# UWAY passenger app

The passenger app keeps HTTP requests in `lib/services/uway_api_client.dart` and
the live location connection in `lib/services/trip_location_connection.dart`.
Screens consume those services and display loading, empty, and error states.

## Local development

At launch, choose a mobile role and a data source:

- **Demo Data** uses in-memory sample trips, route stops, intents, and inbox
  items. It does not contact the API or database. Changes last only for the
  current app session. Sample data is labeled in the app.
- **API Data** calls the configured backend and sends the Development-only role
  and passenger/driver identity headers. This is local test access, not sign-in
  or production authentication. API errors remain visible; the app does not
  silently switch to sample data.

The default Passenger ID is `passenger-local` and can be changed with
`--dart-define=UWAY_DEV_PASSENGER_ID=...`. The API-mode Driver ID can be entered
in the development entry screen; its default comes from
`--dart-define=UWAY_DEV_DRIVER_ID=...`.

The local API currently runs on port `5251`. On an Android emulator, point the
emulator's loopback port to the API with `adb reverse tcp:5251 tcp:5251`. The
default API address is `http://127.0.0.1:5251`; override it with
`--dart-define=UWAY_API_URL=http://127.0.0.1:5251` when needed.
Android has the Internet permission in the main manifest. Cleartext HTTP is
enabled only in the debug manifest for this local API; release deployments
must use HTTPS.

The Passenger tracking screen displays the latest bus point on OpenStreetMap
tiles and continues to receive live points from the existing SignalR hub. It
does not require a Trip Intent. The map requires internet access to fetch map
tiles and shows OpenStreetMap attribution.

## Passenger read access

Passengers can read scheduled, delayed, and in-progress trips through the
existing `GET /api/trips` and `GET /api/trips/{id}` endpoints. Passenger trip
responses omit driver, bus, and internal assignment identifiers. Trip
management and operational actions remain role-restricted.

The Android platform scaffold is in `android/`. Passenger browsing, route details, Trip Intent create/change/cancel, and the empty inbox were observed on the Android emulator in an earlier run. The app also contains a basic Driver workflow, which still needs a fresh Driver-mode build and run. Select **Driver** and **API Data** in the development entry screen to test a real assigned driver. Example:

```powershell
flutter run --dart-define=UWAY_DEV_DRIVER_ID=17 --dart-define=UWAY_API_URL=http://127.0.0.1:5251
```

To run the local widget and data-source tests from `mobile/`, use
`flutter test`. To check the Dart code, use `flutter analyze`.

The Driver screen lists only trips assigned to that ID and supports start,
end, delay, Bus Nearly Full, and foreground GPS sharing through the existing
location endpoint. Location permission is requested only when the driver
starts sharing, and updates are sent while the trip screen remains open. The
app does not collect background location or generate simulated coordinates.

In Demo Data mode, trip lifecycle, delay, nearly-full, Trip Intent, drop-off,
and inbox interactions update an in-memory sample session. GPS sharing and
SignalR are intentionally unavailable in that mode; the sample does not move a
bus or fabricate coordinates. Use API Data mode to verify real tracking.

The Account pages explain the local development role and API address. They do
not provide login, registration, or profile editing because the API has no
identity or user-profile endpoints yet. Passenger trip history and general
Passenger/Driver reports are also unavailable from the current API.

The mobile development entry offers Passenger and Driver. Admin remains in the
separate React dashboard; the Flutter app does not provide an Admin screen.
Release builds show that production sign-in is not available and do not send
development authentication headers. Do not use the development header scheme
as a production identity system.

## Reproducible Android build with Docker

`Dockerfile` pins the Linux/AMD64 JDK 17 image by digest, Flutter 3.47.6,
Android command-line tools build 15859902, Android API 36, Build Tools 36.0.0,
and NDK 28.2.13676358. The Flutter and Android tools archives are checksum
verified during the image build. The Android Gradle Plugin, Kotlin plugin, and
Gradle wrapper remain pinned by the existing Android Gradle files.

Run these commands in Windows PowerShell:

```powershell
Set-Location 'C:\Users\Ba_Fa\Desktop\Senior Project\UWAY\mobile'
docker build --platform linux/amd64 --tag uway-flutter-android:3.47.6 --file Dockerfile .
docker run --rm --platform linux/amd64 --mount "type=bind,source=$($PWD.Path),target=/workspace" --workdir /workspace uway-flutter-android:3.47.6
```

The container runs `flutter pub get`, `flutter analyze`, and
`flutter build apk --debug` in that order. It builds from a temporary copy of
the mounted source so the Windows-specific `android/local.properties` is left
untouched, then copies the debug APK back to:

`mobile\build\app\outputs\flutter-apk\app-debug.apk`

The resolved `pubspec.lock` and APK are copied back; other dependency and
intermediate build files remain in the temporary container workspace. The
database Compose setup is independent and is not used by this build.
