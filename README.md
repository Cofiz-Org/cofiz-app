# cofiz-app

Cofiz Flutter app (Android) — money management for coffee businesses.
Releases ship through [cofiz-dist](https://github.com/cofiz-org/cofiz-dist).

## Setup

1. `flutter pub get`.
2. `flutterfire configure` — generates the gitignored `lib/firebase_options.dart`.
3. `cp .env.example .env` and fill `RELAY_SECRET` (must match the worker's
   `RELAY_SECRET` and Firestore `settings/app` relaySecret). No build flags;
   dev and release builds read the same `.env` (CI writes it from secrets).
4. `flutter run`.

## Tests and checks

`flutter test`, `flutter analyze`.

## Release build (same keystore forever)

```
keytool -genkey -v -keystore cofiz-release.jks -alias cofiz -keyalg RSA -keysize 2048 -validity 10000
```

Put the keystore outside the repo, point `key.properties` at it (gitignored),
wire it in `android/app/build.gradle`, then `flutter build apk --release`.
The APK from a `vX.Y.Z` tag attaches to the same-tag `cofiz-dist` release as
`cofiz-vX.Y.Z.apk`.

<!-- ci canary -->
