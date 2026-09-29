-- Upgrade the original minimal users table for the current PixelDoku app.
-- This migration must run before the leaderboard and competition migrations.

alter table public.users
  add column if not exists name text,
  add column if not exists profile_picture text,
  add column if not exists profile_picture_bg_color bigint,
  add column if not exists player_title text,
  add column if not exists unlocked_themes text[],
  add column if not exists active_theme text,
  add column if not exists hints integer,
  add column if not exists music_on boolean,
  add column if not exists sfx_on boolean,
  add column if not exists board_highlights_on boolean,
  add column if not exists statistics jsonb;

-- Backfill existing players before applying non-null constraints.
update public.users
set
  coins = coalesce(coins, 100),
  current_level = coalesce(current_level, 1),
  saved_game = coalesce(saved_game, '{}'::jsonb),
  name = coalesce(nullif(trim(name), ''), 'Player'),
  profile_picture = coalesce(
    nullif(trim(profile_picture), ''),
    'lib/assets/themes/birds/bird_1.png'
  ),
  profile_picture_bg_color = coalesce(profile_picture_bg_color, 4293836839),
  player_title = coalesce(nullif(trim(player_title), ''), 'New Explorer'),
  unlocked_themes = coalesce(unlocked_themes, array['birds']::text[]),
  active_theme = coalesce(nullif(trim(active_theme), ''), 'birds'),
  hints = coalesce(hints, 10),
  music_on = coalesce(music_on, true),
  sfx_on = coalesce(sfx_on, true),
  board_highlights_on = coalesce(board_highlights_on, true),
  statistics = coalesce(statistics, '{}'::jsonb);

alter table public.users
  alter column coins set default 100,
  alter column coins set not null,
  alter column current_level set default 1,
  alter column current_level set not null,
  alter column saved_game set default '{}'::jsonb,
  alter column saved_game set not null,
  alter column name set default 'Player',
  alter column name set not null,
  alter column profile_picture
    set default 'lib/assets/themes/birds/bird_1.png',
  alter column profile_picture set not null,
  alter column profile_picture_bg_color set default 4293836839,
  alter column profile_picture_bg_color set not null,
  alter column player_title set default 'New Explorer',
  alter column player_title set not null,
  alter column unlocked_themes set default array['birds']::text[],
  alter column unlocked_themes set not null,
  alter column active_theme set default 'birds',
  alter column active_theme set not null,
  alter column hints set default 10,
  alter column hints set not null,
  alter column music_on set default true,
  alter column music_on set not null,
  alter column sfx_on set default true,
  alter column sfx_on set not null,
  alter column board_highlights_on set default true,
  alter column board_highlights_on set not null,
  alter column statistics set default '{}'::jsonb,
  alter column statistics set not null;

-- Automatically provision the public profile whenever an Auth user is made.
create or replace function public.handle_new_pixeldoku_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
      'Player'
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_pixeldoku on auth.users;
create trigger on_auth_user_created_pixeldoku
  after insert on auth.users
  for each row execute function public.handle_new_pixeldoku_user();

-- Provision profiles for Auth users that existed before this migration.
insert into public.users (id, name)
select
  auth_user.id,
  coalesce(
    nullif(trim(auth_user.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(auth_user.raw_user_meta_data ->> 'name'), ''),
    'Player'
  )
from auth.users as auth_user
on conflict (id) do nothing;

-- Players may access only their own mutable profile. Public leaderboard data
-- is exposed through the security-definer leaderboard functions instead.
alter table public.users enable row level security;

drop policy if exists "Players can read their profile" on public.users;
create policy "Players can read their profile"
  on public.users
  for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists "Players can create their profile" on public.users;
create policy "Players can create their profile"
  on public.users
  for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "Players can update their profile" on public.users;
create policy "Players can update their profile"
  on public.users
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

grant select, insert, update on public.users to authenticated;
revoke delete on public.users from anon, authenticated;

