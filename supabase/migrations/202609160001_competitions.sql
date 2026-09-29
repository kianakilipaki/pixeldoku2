-- UTC periods; weekly competitions start Monday. Legacy times are not scores.
create table public.competition_scores (
  user_id uuid references public.users(id) on delete cascade,
  puzzle_date date not null,
  elapsed_seconds integer not null check (elapsed_seconds between 1 and 86400),
  hints integer not null check (hints between 0 and 81),
  hearts_lost integer not null check (hearts_lost >= 0),
  score integer not null,
  completed_at timestamptz not null default now(),
  primary key (user_id, puzzle_date)
);
alter table public.competition_scores enable row level security;

create table public.competition_awards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  period text not null check (period in ('daily', 'weekly', 'monthly')),
  period_start date not null,
  score bigint not null,
  coins integer not null,
  hints integer not null,
  hearts integer not null,
  title text,
  acknowledged_at timestamptz,
  unique (period, period_start)
);
alter table public.competition_awards enable row level security;

create function public.submit_daily_score(p_puzzle_date date,
  p_elapsed_seconds integer, p_hints integer, p_hearts_lost integer)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_puzzle_date <> timezone('utc', now())::date then
    raise exception 'Only today can be submitted';
  end if;
  if p_elapsed_seconds not between 1 and 86400 or p_hints not between 0 and 81
    or p_hearts_lost not between 0 and 100 then raise exception 'Invalid result'; end if;
  insert into public.competition_scores values (
    auth.uid(), p_puzzle_date, p_elapsed_seconds, p_hints, p_hearts_lost,
    greatest(100, 2000 - least(p_elapsed_seconds, 1800) - p_hints * 200 - p_hearts_lost * 300), now()
  ) on conflict (user_id, puzzle_date) do nothing;
end $$;

create function public.get_competition_leaderboard(p_period text)
returns table(user_id uuid, player_name text, profile_picture text,
  profile_picture_bg_color bigint, player_title text, player_level integer,
  best_time_seconds integer, score bigint)
language plpgsql stable security definer set search_path = public as $$
declare first_day date; last_day date;
begin
  if p_period not in ('daily', 'weekly', 'monthly') then raise exception 'Invalid period'; end if;
  first_day := date_trunc(case p_period when 'daily' then 'day' when 'weekly' then 'week' else 'month' end,
    timezone('utc', now()))::date;
  last_day := first_day + case p_period when 'daily' then interval '1 day'
    when 'weekly' then interval '7 days' else interval '1 month' end;
  return query select u.id, coalesce(nullif(trim(u.name), ''), 'Player'), u.profile_picture,
    coalesce(u.profile_picture_bg_color, 4293836839)::bigint,
    coalesce(u.player_title, 'New Explorer'), coalesce(u.current_level, 1)::integer,
    min(s.elapsed_seconds)::integer, sum(s.score)::bigint
  from public.competition_scores s join public.users u on u.id = s.user_id
  where s.puzzle_date >= first_day and s.puzzle_date < last_day
  group by u.id
  order by sum(s.score) desc, sum(s.elapsed_seconds) asc, max(s.completed_at) asc, u.id asc;
end $$;

-- Run hourly using pg_cron. Also called on return visits as a catch-up.
-- A unique period ledger and transaction lock prevent duplicate payouts.
create function public.settle_competitions()
returns void language plpgsql security definer set search_path = public as $$
declare event record; winner record; award_id uuid; prize_coins integer;
  prize_hints integer; prize_hearts integer;
begin
  perform pg_advisory_xact_lock(16092026);
  for event in
    select distinct periods.period,
      date_trunc(periods.unit, s.puzzle_date::timestamp)::date as first_day,
      (date_trunc(periods.unit, s.puzzle_date::timestamp) + periods.duration)::date as last_day
    from public.competition_scores s cross join
      (values ('daily','day',interval '1 day'), ('weekly','week',interval '7 days'),
        ('monthly','month',interval '1 month')) as periods(period, unit, duration)
    where date_trunc(periods.unit, s.puzzle_date::timestamp) + periods.duration <= timezone('utc', now())
  loop
    if exists(select 1 from public.competition_awards a where a.period = event.period
      and a.period_start = event.first_day) then continue; end if;
    select s.user_id, sum(s.score) as score into winner from public.competition_scores s
      where s.puzzle_date >= event.first_day and s.puzzle_date < event.last_day
      group by s.user_id order by sum(s.score) desc, sum(s.elapsed_seconds) asc,
        max(s.completed_at) asc, s.user_id asc limit 1;
    if winner.user_id is null then continue; end if;
    prize_coins := case event.period when 'daily' then 100 when 'weekly' then 350 else 1000 end;
    prize_hints := case event.period when 'daily' then 1 when 'weekly' then 3 else 10 end;
    prize_hearts := case event.period when 'daily' then 0 when 'weekly' then 1 else 3 end;
    insert into public.competition_awards(user_id, period, period_start, score, coins, hints, hearts, title)
      values(winner.user_id, event.period, event.first_day, winner.score,
        prize_coins, prize_hints, prize_hearts,
        case when event.period = 'monthly' then 'Monthly Champion' end)
      on conflict do nothing returning id into award_id;
    if award_id is not null then
      update public.users set coins = coalesce(coins, 0) + prize_coins,
        hints = coalesce(hints, 0) + prize_hints,
        statistics = coalesce(statistics, '{}'::jsonb) || jsonb_build_object(
          'spare_hearts', coalesce((statistics->>'spare_hearts')::integer, 0) + prize_hearts,
          'monthly_championships', coalesce((statistics->>'monthly_championships')::integer, 0)
            + case when event.period = 'monthly' then 1 else 0 end)
      where id = winner.user_id;
    end if;
  end loop;
end $$;

create function public.get_competition_awards()
returns table(id uuid, period text, period_start date, score bigint, coins integer,
  hints integer, hearts integer, title text, wallet_coins integer, wallet_hints integer,
  spare_hearts integer, monthly_championships integer)
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  perform public.settle_competitions();
  return query select a.id, a.period, a.period_start, a.score, a.coins, a.hints, a.hearts, a.title,
    coalesce(u.coins, 0)::integer, coalesce(u.hints, 0)::integer,
    coalesce((u.statistics->>'spare_hearts')::integer, 0),
    coalesce((u.statistics->>'monthly_championships')::integer, 0)
  from public.competition_awards a join public.users u on u.id = a.user_id
  where a.user_id = auth.uid() and a.acknowledged_at is null
  order by a.period_start, a.period;
end $$;

create function public.acknowledge_competition_award(p_id uuid)
returns void language sql security definer set search_path = public as $$
  update public.competition_awards set acknowledged_at = now()
  where id = p_id and user_id = auth.uid() and acknowledged_at is null;
$$;

revoke all on function public.submit_daily_score(date, integer, integer, integer) from public;
revoke all on function public.settle_competitions() from public;
revoke all on function public.get_competition_awards() from public;
revoke all on function public.acknowledge_competition_award(uuid) from public;
revoke all on function public.get_competition_leaderboard(text) from public;
grant execute on function public.submit_daily_score(date, integer, integer, integer) to authenticated;
grant execute on function public.get_competition_awards() to authenticated;
grant execute on function public.acknowledge_competition_award(uuid) to authenticated;
grant execute on function public.get_competition_leaderboard(text) to anon, authenticated;

-- Supabase Cron is optional: enable it before deployment for midnight payouts.
-- Without Cron, the next authenticated visit settles all closed periods.
do $$
begin
  if exists(select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('pixeldoku-competition-settlement', '0 0 * * *',
      'select public.settle_competitions();');
  end if;
end $$;
