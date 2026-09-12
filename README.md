# cofiz-app

Cofiz Flutter app (Android) — money management for Ethiopian coffee businesses.
Releases ship through [cofiz-dist](https://github.com/cofiz-org/cofiz-dist).

## Features

- **Daily coffee prices** — per-type rates (Jenfel, Wet, Special) set from the dashboard chip; Wet default, over-price sales warn.
- **Cash distribution** — fund collectors in the morning; balances update instantly.
- **Purchase logging** — type, weight, price per kg and receipt photo per purchase.
- **Cash returns** — collectors return leftover cash against their balance.
- **Income & expenses** — investor funds and sales as income, running costs as expenses, custom categories, Cash In vs Cash Out with Net Balance.
- **Debts** — shortfalls become tracked open debts automatically; repayments close them.
- **Reports & PDF export** — unified activity feed (Today / 7 days / Month / any date) with one-tap PDF.
- **Collectors management** — balances, history, per-collector debts.
- **Notifications** — bell center plus FCM pushes for prices, payments and debts.
- **Telegram & WhatsApp login** — phone OTP over Telegram/WhatsApp, native Telegram sign-in.
- **Offline-first** — Hive cache with outbox queue; auto-sync on reconnect.
- **PIN & idle lock** — PIN gate with automatic lock when idle.
- **Roles** — Admin (full access), Collector (own book), Investor (read-only).
- **Audit log & backup** — every change recorded; backup and restore built in.
- **Amharic & English** — full bilingual UI with ETB and Ethiopian calendar.
- **In-app updates** — plain-language update prompts served from cofiz-dist releases.

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
