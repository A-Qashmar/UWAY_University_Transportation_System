# UWAY Mobile App (Flutter)

One app for Passengers and Drivers. After signing in with an email and password, the account decides which interface opens.

## Run on an Android phone

```powershell
cd mobile
adb reverse tcp:5251 tcp:5251
flutter pub get
flutter run
```

The API must be running on port 5251 (see the [setup guide](../docs/phase-2-setup.md)). `adb reverse` must be repeated after the phone is reconnected.

Options (pass with `--dart-define=NAME=value`):

| Name | Purpose | Default |
| --- | --- | --- |
| `UWAY_API_URL` | API address | `http://localhost:5251` (on Android it becomes `http://127.0.0.1:5251`, which works with `adb reverse`) |
| `UWAY_DEV_PASSENGER_ID`, `UWAY_DEV_DRIVER_ID` | Used only by the optional developer mode | – |

For demos use `flutter run --profile`; debug builds make the map noticeably slower.

## Test accounts

Created by `--seed-test-users` (password `Uway@2026`, local testing only): `omar.hassan@uway.test` and `khalid.saeed@uway.test` (men), `mariam.ali@uway.test` and `noura.salem@uway.test` (women), `driver<ID>@uway.test` for drivers.

## Developer mode

Debug builds show **Developer mode (sample data)** on the login screen. It uses built-in sample data and needs no API or account. Release builds do not show it.

## Tests

```powershell
cd mobile
flutter test
flutter analyze
```

## Reproducible Android build with Docker

`Dockerfile` pins the Linux/AMD64 JDK 17 image by digest, Flutter 3.47.6,
Android command-line tools build 15859902, Android API 36, Build Tools 36.0.0,
and NDK 28.2.13676358. The Flutter and Android tools archives are checksum
verified during the image build.

Run these commands in Windows PowerShell from the `mobile` folder:

```powershell
docker build --platform linux/amd64 --tag uway-flutter-android:3.47.6 --file Dockerfile .
docker run --rm --platform linux/amd64 --mount "type=bind,source=$($PWD.Path),target=/workspace" --workdir /workspace uway-flutter-android:3.47.6
```

The container runs `flutter pub get`, `flutter analyze`, and
`flutter build apk --debug` in that order, from a temporary copy of the mounted
source, then copies the debug APK to `mobile\build\app\outputs\flutter-apk\app-debug.apk`.

## Notes

- The session is kept in memory; the app asks for sign-in after a restart.
- Notifications are in-app only (no push).
- The university logo (`assets/uos-logo.png`) has not been added; campus stops use an icon.
