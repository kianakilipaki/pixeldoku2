-- Preserve previously settled events; new events pay gold, silver and bronze.
select pg_advisory_xact_lock(16092026);

alter table public.competition_awards add column rank integer not null default 1
  check (rank between 1 and 3);
alter table public.competition_awards
  drop constraint competition_awards_period_period_start_key;
alter table public.competition_awards
  add unique (period, period_start, rank),
  add unique (period, period_start, user_id);

create table public.competition_settlements (
  period text not null check (period in ('daily', 'weekly', 'monthly')),
  period_start date not null,
  primary key (period, period_start)
);
alter table public.competition_settlements enable row level security;
insert into public.competition_settlements
  select distinct period, period_start from public.competition_awards;

create or replace function public.settle_competitions()
returns void language plpgsql security definer set search_path = public as $$
declare event record; winner record; award_id uuid;
  prize_coins integer; prize_hints integer; prize_hearts integer;
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
    if exists(select 1 from public.competition_settlements e where e.period = event.period
      and e.period_start = event.first_day) then continue; end if;
    for winner in
      select s.user_id, sum(s.score) as score,
        row_number() over (order by sum(s.score) desc, sum(s.elapsed_seconds) asc,
          max(s.completed_at) asc, s.user_id asc)::integer as rank
      from public.competition_scores s
      where s.puzzle_date >= event.first_day and s.puzzle_date < event.last_day
      group by s.user_id order by rank limit 3
    loop
      prize_coins := case event.period
        when 'daily' then (array[100, 50, 25])[winner.rank]
        when 'weekly' then (array[350, 200, 100])[winner.rank]
        else (array[1000, 600, 300])[winner.rank] end;
      prize_hints := case event.period
        when 'daily' then (array[1, 1, 0])[winner.rank]
        when 'weekly' then (array[3, 2, 1])[winner.rank]
        else (array[10, 6, 3])[winner.rank] end;
      prize_hearts := case event.period
        when 'daily' then 0 when 'weekly' then (array[1, 1, 0])[winner.rank]
        else (array[3, 2, 1])[winner.rank] end;
      insert into public.competition_awards(user_id, period, period_start, rank, score, coins, hints, hearts, title)
        values(winner.user_id, event.period, event.first_day, winner.rank, winner.score,
          prize_coins, prize_hints, prize_hearts,
          case when event.period = 'monthly' and winner.rank = 1 then 'Monthly Champion' end)
        on conflict do nothing returning id into award_id;
      if award_id is not null then
        update public.users set coins = coalesce(coins, 0) + prize_coins,
          hints = coalesce(hints, 0) + prize_hints,
          statistics = coalesce(statistics, '{}'::jsonb) || jsonb_build_object(
            'spare_hearts', coalesce((statistics->>'spare_hearts')::integer, 0) + prize_hearts,
            'monthly_championships', coalesce((statistics->>'monthly_championships')::integer, 0)
              + case when event.period = 'monthly' and winner.rank = 1 then 1 else 0 end)
        where id = winner.user_id;
      end if;
    end loop;
    insert into public.competition_settlements values (event.period, event.first_day)
      on conflict do nothing;
  end loop;
end $$;
revoke all on function public.settle_competitions() from public;

drop function public.get_competition_awards();
create function public.get_competition_awards()
returns table(id uuid, period text, period_start date, score bigint, coins integer,
  hints integer, hearts integer, title text, wallet_coins integer, wallet_hints integer,
  spare_hearts integer, monthly_championships integer, rank integer)
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  perform public.settle_competitions();
  return query select a.id, a.period, a.period_start, a.score, a.coins, a.hints, a.hearts, a.title,
    coalesce(u.coins, 0)::integer, coalesce(u.hints, 0)::integer,
    coalesce((u.statistics->>'spare_hearts')::integer, 0),
    coalesce((u.statistics->>'monthly_championships')::integer, 0), a.rank
  from public.competition_awards a join public.users u on u.id = a.user_id
  where a.user_id = auth.uid() and a.acknowledged_at is null
  order by a.period_start, a.period;
end $$;
revoke all on function public.get_competition_awards() from public;
grant execute on function public.get_competition_awards() to authenticated;
