-- Auto-grant Pro plan to all new sign-ups and users
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, plan)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)),
    'pro'
  )
  on conflict (id) do update set plan = 'pro';

  insert into public.subscriptions (user_id, plan, status, current_period_end)
  values (
    new.id,
    'pro',
    'active',
    now() + interval '100 years'
  )
  on conflict (user_id) do update set plan = 'pro', status = 'active';

  return new;
end;
$$;

-- Upgrade all existing profiles and subscriptions to Pro
update public.profiles set plan = 'pro';

insert into public.subscriptions (user_id, plan, status, current_period_end)
select id, 'pro', 'active', now() + interval '100 years'
from public.profiles
on conflict (user_id) do update set plan = 'pro', status = 'active';
