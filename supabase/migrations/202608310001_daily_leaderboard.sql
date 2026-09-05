create table if not exists public.daily_leaderboard (
  user_id uuid not null references public.users(id) on delete cascade,
  puzzle_date date not null,
  elapsed_seconds integer not null check (elapsed_seconds > 0),
  completed_at timestamptz not null default now(),
  primary key (user_id, puzzle_date)
);

alter table public.daily_leaderboard enable row level security;

create or replace function public.submit_daily_time(
  p_puzzle_date date,
  p_elapsed_seconds integer
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_puzzle_date <> (now() at time zone 'utc')::date then
    raise exception 'Only today''s puzzle can be submitted';
  end if;
  if p_elapsed_seconds <= 0 or p_elapsed_seconds > 86400 then
    raise exception 'Invalid elapsed time';
  end if;

  insert into public.daily_leaderboard (
    user_id,
    puzzle_date,
    elapsed_seconds
  ) values (
    auth.uid(),
    p_puzzle_date,
    p_elapsed_seconds
  )
  on conflict (user_id, puzzle_date) do update
  set elapsed_seconds = least(
        public.daily_leaderboard.elapsed_seconds,
        excluded.elapsed_seconds
      ),
      completed_at = case
        when excluded.elapsed_seconds < public.daily_leaderboard.elapsed_seconds
          then now()
        else public.daily_leaderboard.completed_at
      end;
end;
$$;

create or replace function public.get_daily_leaderboard(
  p_puzzle_date date
) returns table (
  user_id uuid,
  player_name text,
  profile_picture text,
  elapsed_seconds integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    leaderboard.user_id,
    coalesce(nullif(trim(players.name), ''), 'Player') as player_name,
    players.profile_picture,
    leaderboard.elapsed_seconds
  from public.daily_leaderboard as leaderboard
  join public.users as players on players.id = leaderboard.user_id
  where leaderboard.puzzle_date = p_puzzle_date
  order by leaderboard.elapsed_seconds asc, leaderboard.completed_at asc
  limit 25;
$$;

revoke all on function public.submit_daily_time(date, integer) from public;
grant execute on function public.submit_daily_time(date, integer) to authenticated;
grant execute on function public.get_daily_leaderboard(date) to anon, authenticated;
