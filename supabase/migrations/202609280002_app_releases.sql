-- Public, read-only app release metadata used by the in-app update alert.
create table if not exists public.app_releases (
  platform text primary key check (platform in ('android', 'ios')),
  latest_version text not null,
  minimum_version text not null default '0.0.0',
  store_url text,
  message text not null default 'A new version of PixelDoku is ready to play.',
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.app_releases enable row level security;

drop policy if exists "Anyone can read app releases" on public.app_releases;
create policy "Anyone can read app releases"
  on public.app_releases
  for select
  to anon, authenticated
  using (true);

grant select on public.app_releases to anon, authenticated;
revoke insert, update, delete on public.app_releases from anon, authenticated;

insert into public.app_releases (
  platform,
  latest_version,
  minimum_version,
  store_url,
  message
)
values (
  'android',
  '0.1.0+1',
  '0.1.0+1',
  null,
  'A new version of PixelDoku is ready to play.'
)
on conflict (platform) do nothing;
