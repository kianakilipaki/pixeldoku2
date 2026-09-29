# PixelDoku

A pixel-art Sudoku game with themed animal boards, campaign progression,
profile customization, daily puzzles, achievements, and cloud leaderboards.

## Runtime requirements

PixelDoku is a Flutter/Dart project, not a Node.js project. Node.js is not
required to build or run the app, and no Node.js version is pinned in this
repository (there is no `package.json`, `.nvmrc`, or `.node-version`).

The Dart SDK constraint in `pubspec.yaml` is `^3.11.5`. Use a compatible
Flutter SDK, which includes Dart.

## Run locally

```sh
flutter pub get
flutter run
```

## Competitions and rewards

Daily boards use a UTC date seed, so every client receives the same Hard
puzzle without downloading puzzle data. Campaign and Daily saves are stored
separately.

Rankings default to Daily, with Weekly and Monthly tabs. Weekly and Monthly
scores sum each day's first completed Daily puzzle; campaign scores do not
enter competitions. All boundaries use UTC; weeks start Monday. Replays are
practice, and Daily retries retain time, hint, and heart-loss penalties.

Score: `max(100, 2000 - min(seconds, 1800) - 200 * hints - 300 * heartsLost)`.
Completion coins: 50/40/30 for campaign puzzles and 100/80/60 for Daily
puzzles, based on zero/one/two-or-more lost hearts. Time and hints do not
affect coins. Daily completion coins are earned once per date.

Podium prizes (coins / free hints / spare hearts):

| Period | Gold | Silver | Bronze |
| --- | --- | --- | --- |
| Daily | 100 / 1 / 0 | 50 / 1 / 0 | 25 / 0 / 0 |
| Weekly | 350 / 3 / 1 | 200 / 2 / 1 | 100 / 1 / 0 |
| Monthly | 1,000 / 10 / 3 | 600 / 6 / 2 | 300 / 3 / 1 |

Only monthly gold unlocks the Monthly Champion title. Deploy
`202609160002_podium_prizes.sql` after the competition migration to enable
silver and bronze payouts. Previously settled events keep their original
gold-only awards; new events pay the top three, or fewer if fewer players enter.

Ties break by total completion time, then the earliest final submission,
then user ID. Spare hearts can continue a failed board without erasing
scoring penalties. Monthly Champion becomes available in profile titles.

Deploy the Supabase migrations before enabling shared scores or payouts:

```sh
supabase db push
```

`202609160001_competitions.sql` introduces scored submissions and an award
ledger. Enable Supabase Cron before deploying to schedule settlement at
midnight UTC; otherwise an authenticated return visit settles closed events.
Winners' cloud balances are credited transactionally once per event. The
completion-style news board stays pending until acknowledged, so closing
the app cannot award the same prize again or permanently hide the news.

Competition entry requires sign-in and a submission received before UTC
midnight. Today's locally recorded first result is retried on return visits;
expired offline results cannot enter a closed event. Debug builds may display
clearly labeled sample rankings; sample players never enter the award ledger.
No historical best-time data is retroactively treated as scored submissions.

Deployment/security note: the server calculates points and enforces one
result per player per day, but timing, hints, and heart counts remain
client-reported. This is not a tamper-proof competition system. Before
offering valuable prizes, add server-validated sessions/results and make
wallet/inventory changes server-authoritative instead of allowing direct
profile writes. The migration must be tested against the deployed `users`
schema (including JSONB statistics); it is not deployed by editing this repo.

## Supabase activity ping

`.github/workflows/keep-supabase-active.yml` reads the daily, weekly, and
monthly leaderboards once each day and can also be run manually from the
GitHub Actions tab. The workflow must be present on the default branch and
GitHub Actions must be enabled. GitHub may disable scheduled workflows in
public repositories after 60 days without repository activity; re-enable the
workflow from the Actions tab if that happens.

## App update alerts

Deploy `202609280002_app_releases.sql` to enable the home-screen update check.
After publishing a Play Store build, update the Android release row:

```sql
update public.app_releases
set
  latest_version = '0.2.0+2',
  minimum_version = '0.1.0+1',
  message = 'A new PixelDoku adventure is ready!',
  updated_at = now()
where platform = 'android';
```

`latest_version` displays an optional alert. Set `minimum_version` above a
player's installed version only when the update must be required. A null
`store_url` automatically uses the installed Android package ID; it may also
be set to the final Play Store listing URL.

## Remove Gameplay Ads purchase

The shop includes a one-time Remove Gameplay Ads purchase. It disables only
automatic post-game interstitials; voluntary coin and hint reward ads remain
available. The suggested US price is **$2.99**, while the button displays the
localized Play Store price when the product is available.

Configure the purchase before release:

1. In Google Play Console, create an in-app, non-consumable product with the
   product ID `remove_gameplay_ads` and set its price to $2.99 USD.
2. In RevenueCat, create the `no_gameplay_ads` entitlement, attach that product,
   and add it to the current offering as a lifetime or custom package.
3. Build with the public RevenueCat Android SDK key:

```sh
flutter build appbundle \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_your_public_sdk_key
```

The purchase button does not grant the benefit unless RevenueCat returns the
active entitlement. Restore Purchases in Settings restores it on another
device using the same Play Store account.
