# PixelDoku

A pixel-art Sudoku game with themed animal boards, campaign progression,
profile customization, daily puzzles, achievements, and cloud leaderboards.

## Run locally

```sh
flutter pub get
flutter run
```

## Daily leaderboard setup

Daily boards use a UTC date seed, so every client receives the same Hard
puzzle without downloading puzzle data. Campaign and Daily saves are stored
separately.

Deploy the Supabase migration before enabling shared rankings:

```sh
supabase db push
```

The migration in `supabase/migrations` creates the best-time table plus the
`submit_daily_time` and `get_daily_leaderboard` RPCs. Without it, the app stays
usable and displays locally saved Daily results.
