## v1.0.4

Daily coffee prices: admin sets per-type prices from the dashboard, everyone
sees them, above-price purchases warn and flag. Coffee type Washed is now Wet
and the default. Release notes are now plain text, current version only.

## v1.0.3

Notification reliability: nightly reminder is now solely the backend cron
(removed the dead local 18:00 alarm), push titles show the real event title,
and opted-out users no longer receive pushes.

## v1.0.2

Fix Telegram native login on release builds: use the release-key
native-login domain (per-build-type redirect host).

## v1.0.1

Pipeline rehearsal release. No behavior changes.
