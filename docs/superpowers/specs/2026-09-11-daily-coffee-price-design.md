# Daily Company Coffee Price — Design Spec

Date: 2026-09-11. Status: approved sections 1–3 by product owner.

## Goal

Admin sets a daily advisory buying price per coffee type each morning.
All roles see it on the dashboard. Purchases recorded above the day's price
save normally but are flagged. One company today; `companyId` plumbed for
multi-company later.

## Decisions (from brainstorm)

- Per coffee type (jenfel / wet / special), not a single price.
- Above-price purchases: warning, never a block.
- One company now; `companyId` field reserved with default `"cofiz"`.
- Gap window (00:00 until admin sets): show "not set yet", nothing blocked.
- Price UI lives on the dashboard header, not in settings. No badges on
  transaction lists.
- Rename Yetatebe/Washed (የታጠበ) to Wet (እርጥብ); Wet is the
  default in all coffee-type dropdowns.

## Data model

`settings/daily_prices/{YYYY-MM-DD}` (Addis calendar date):

- `companyId: "cofiz"`
- `prices: { jenfel: double, wet: double, special: double }` (partial allowed)
- `setBy` (admin uid), `setAt` (ms epoch)

`transactions` (type == purchase) gain:

- `dailyPriceAtSale: double?` — that type's price in effect at record time,
  null when unset.
- `aboveDailyPrice: bool` — true when entered `pricePerKg` exceeded it.

`users` gain `companyId: "cofiz"`. Missing field reads as `"cofiz"`; no
migration script. Historical `yetatebe` values display as Wet.

## UX

Top bar (dashboard header, right of the bell, same 28px size):

- Admin: `+` when the selected type has no price today; price chip
  (e.g. `380/kg`) once set. Tapping the chip reopens the modal.
- Collectors/viewers: price chip read-only, or "not set yet". No button.
- Type label on the chip (default Wet); tap cycles Wet → Jenfel → Special.
  Unset types never show a price.

Modal (admin only): type selector (Wet preselected), ETB/kg field prefilled
with yesterday's same-type price. Save merges that type into today's doc.
Same modal for edits.

Notification on set/edit: push + bell doc to all users, all roles, via the
existing relay fan-out (`dailyPriceSet` type, tap opens notifications list).

Purchase dialog: selected type's today-price under the price field; amber
warning when above; snapshot + flag stored. No price set: no comparison.

## Rules & edge cases

- Validity is date comparison only (doc date == today, Addis). No cron.
- `UserRole.canManagePrices` == admin-only, next to `canManageSettings`.
- Each type independent; yesterday never auto-carries; unset stays unset.
- Same-type same-day edit overwrites; `setBy`/`setAt` re-stamped.
- Two admins, same type: last write wins.

## Testing

- Unit: date-validity, per-type merge save, warning threshold, rename mapping.
- Widget: chip states (+ / price / not-set), modal prefill, role gating.
- Relay fan-out test with stubbed HTTP client (ping-test pattern).
