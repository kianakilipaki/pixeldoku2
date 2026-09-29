-- Case-insensitive unique usernames and automatic Player#### names.

create or replace function public.next_pixeldoku_player_name()
returns text
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  candidate text;
begin
  for attempt in 1..20000 loop
    candidate := 'Player' || lpad(floor(random() * 10000)::integer::text, 4, '0');
    if not exists (
      select 1 from public.users
      where lower(btrim(name)) = lower(candidate)
    ) then
      return candidate;
    end if;
  end loop;
  raise exception 'No Player number is currently available';
end;
$$;

-- Replace blank/default names and all but the first case-insensitive duplicate.
do $$
declare
  profile record;
begin
  for profile in
    with ranked as (
      select
        id,
        name,
        row_number() over (
          partition by lower(btrim(coalesce(name, '')))
          order by created_at nulls last, id
        ) as duplicate_number
      from public.users
    )
    select id
    from ranked
    where btrim(coalesce(name, '')) = ''
       or lower(btrim(name)) = 'player'
       or duplicate_number > 1
  loop
    update public.users
    set name = public.next_pixeldoku_player_name()
    where id = profile.id;
  end loop;
end;
$$;

create unique index if not exists users_name_unique_ci
  on public.users (lower(btrim(name)));

alter table public.users
  alter column name set default public.next_pixeldoku_player_name();

-- New Auth users always receive a unique neutral display name. The insert is
-- retried if two signups happen to generate the same four-digit number.
create or replace function public.handle_new_pixeldoku_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  candidate text;
begin
  if exists (select 1 from public.users where id = new.id) then
    return new;
  end if;

  for attempt in 1..100 loop
    candidate := public.next_pixeldoku_player_name();
    begin
      insert into public.users (id, name) values (new.id, candidate);
      return new;
    exception when unique_violation then
      -- Another signup claimed the generated number; generate another.
    end;
  end loop;

  raise exception 'Could not allocate a unique Player number';
end;
$$;

create or replace function public.set_player_name(p_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  cleaned_name text;
begin
  if auth.uid() is null then
    raise exception using errcode = 'P0001', message = 'USERNAME_AUTH_REQUIRED';
  end if;

  cleaned_name := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  if char_length(cleaned_name) < 3 or char_length(cleaned_name) > 20 then
    raise exception using errcode = 'P0001', message = 'USERNAME_LENGTH';
  end if;
  if cleaned_name ~ '[[:cntrl:]]' then
    raise exception using errcode = 'P0001', message = 'USERNAME_CHARACTERS';
  end if;
  if exists (
    select 1 from public.users
    where lower(btrim(name)) = lower(cleaned_name)
      and id <> auth.uid()
  ) then
    raise exception using errcode = 'P0001', message = 'USERNAME_TAKEN';
  end if;

  begin
    update public.users set name = cleaned_name where id = auth.uid();
  exception when unique_violation then
    raise exception using errcode = 'P0001', message = 'USERNAME_TAKEN';
  end;

  if not found then
    raise exception using errcode = 'P0001', message = 'USERNAME_PROFILE_MISSING';
  end if;
  return cleaned_name;
end;
$$;

revoke all on function public.next_pixeldoku_player_name() from public;
revoke all on function public.set_player_name(text) from public;
grant execute on function public.next_pixeldoku_player_name() to authenticated;
grant execute on function public.set_player_name(text) to authenticated;

