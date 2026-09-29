drop function if exists public.get_global_leaderboard();

create function public.get_global_leaderboard()
returns table (
  user_id uuid,
  player_name text,
  profile_picture text,
  profile_picture_bg_color bigint,
  player_title text,
  player_level integer,
  best_time_seconds integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    players.id as user_id,
    coalesce(nullif(trim(players.name), ''), 'Player') as player_name,
    players.profile_picture,
    coalesce(players.profile_picture_bg_color, 4293836839)::bigint
      as profile_picture_bg_color,
    coalesce(nullif(trim(players.player_title), ''), 'New Explorer')
      as player_title,
    greatest(coalesce(players.current_level, 1), 1) as player_level,
    min(leaderboard.elapsed_seconds)::integer as best_time_seconds
  from public.daily_leaderboard as leaderboard
  join public.users as players on players.id = leaderboard.user_id
  where leaderboard.puzzle_date >=
      date_trunc('month', timezone('utc', now()))::date
    and leaderboard.puzzle_date <
      (date_trunc('month', timezone('utc', now())) + interval '1 month')::date
  group by
    players.id,
    players.name,
    players.profile_picture,
    players.profile_picture_bg_color,
    players.player_title,
    players.current_level
  order by best_time_seconds asc, player_level desc, player_name asc
  limit 25;
$$;

grant execute on function public.get_global_leaderboard()
  to anon, authenticated;
