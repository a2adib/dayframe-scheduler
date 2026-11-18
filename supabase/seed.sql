-- Dayframe dev seed (local only). Two test users for RLS verification:
--   User A: 11111111-1111-1111-1111-111111111111 (adib+dev-a@dayframe.app)
--   User B: 22222222-2222-2222-2222-222222222222 (adib+dev-b@dayframe.app)

-- ── Auth users (local dev only; production uses the auth API) ───────────────
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '11111111-1111-1111-1111-111111111111',
  'authenticated', 'authenticated', 'adib+dev-a@dayframe.app', crypt('dayframe-dev', gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Adib A"}',
  now(), now()
) on conflict (id) do nothing;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '22222222-2222-2222-2222-222222222222',
  'authenticated', 'authenticated', 'adib+dev-b@dayframe.app', crypt('dayframe-dev', gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Adib B"}',
  now(), now()
) on conflict (id) do nothing;

-- Profiles are created by the on_auth_user_created trigger; set timezones.
update profiles set timezone = 'Asia/Dhaka' where id = '11111111-1111-1111-1111-111111111111';
update profiles set timezone = 'Asia/Dhaka' where id = '22222222-2222-2222-2222-222222222222';

-- ── User A: two channels, two scheduled posts, slots, notification prefs ─────
insert into channels (id, user_id, platform, external_account_id, handle, display_name, status, token_expires_at) values
  ('aaaa1111-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'instagram', 'ig-1', '@adib.builds', 'Adib Builds', 'connected'::channel_status, now() + interval '60 days'),
  ('aaaa1111-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'x', 'x-1', '@adib', 'Adib', 'connected'::channel_status, now() + interval '30 days'),
  ('aaaa1111-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'linkedin', 'li-1', 'in/adibrahman', 'Adib Rahman', 'expired'::channel_status, now() - interval '2 days');

insert into posts (id, user_id, body, status, schedule_mode, scheduled_at) values
  ('aaaa2222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'Morning rhythm check: framing your day before opening your feeds changes everything. What''s your #1 priority today?',
   'scheduled'::post_status, 'queue'::schedule_mode, date_trunc('day', now()) + interval '9 hours 15 minutes'),
  ('aaaa2222-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   'Quick breakdown of our new content pipeline. Batching on Mondays gives you back 6 hours every single week. 🚀',
   'scheduled'::post_status, 'custom'::schedule_mode, date_trunc('day', now()) + interval '1 day 13 hours 30 minutes'),
  ('aaaa2222-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   'Draft: ideas for the studio refresh tour.', 'draft'::post_status, null::schedule_mode, null);

insert into post_targets (id, post_id, user_id, channel_id, status, scheduled_at) values
  ('aaaa3333-0000-0000-0000-000000000001', 'aaaa2222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aaaa1111-0000-0000-0000-000000000002', 'scheduled'::post_status, date_trunc('day', now()) + interval '9 hours 15 minutes'),
  ('aaaa3333-0000-0000-0000-000000000002', 'aaaa2222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aaaa1111-0000-0000-0000-000000000003', 'scheduled'::post_status, date_trunc('day', now()) + interval '9 hours 15 minutes'),
  ('aaaa3333-0000-0000-0000-000000000003', 'aaaa2222-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'aaaa1111-0000-0000-0000-000000000001', 'scheduled'::post_status, date_trunc('day', now()) + interval '1 day 13 hours 30 minutes');

insert into posting_slots (user_id, weekday, local_time, active) values
  ('11111111-1111-1111-1111-111111111111', 1, '09:00', true),
  ('11111111-1111-1111-1111-111111111111', 1, '13:30', true),
  ('11111111-1111-1111-1111-111111111111', 3, '09:00', true),
  ('11111111-1111-1111-1111-111111111111', 5, '17:00', false);

insert into notification_prefs (user_id) values ('11111111-1111-1111-1111-111111111111');

-- ── User A: ideas board and community engagement items ──────────────────────
insert into ideas (id, user_id, title, notes, stage, tags, link) values
  ('aaaa4444-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'Why 90% of creators burn out', 'Break down the creator treadmill vs sustainable batching. Mention 3 systems that worked for us.', 'raw', array['creator-economy', 'productivity'], 'https://dayframe.app/blog/burnout'),
  ('aaaa4444-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   '10 AI tools that save 10 hours a week', 'Outline: 1. Research 2. Voice transcription 3. Graphic resizing 4. Repurposing 5. Dayframe scheduler.', 'drafting', array['ai', 'tools', 'tips'], null),
  ('aaaa4444-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   'Behind the scenes iOS 18 widgets', 'Show our interactive calendar widgets with swift animations. Include video clip.', 'ready', array['ios', 'buildinpublic', 'swiftui'], 'https://x.com/adib');

insert into engagement_items (id, user_id, channel_id, post_id, author_name, author_handle, content, platform, is_replied, is_starred) values
  ('aaaa5555-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'aaaa1111-0000-0000-0000-000000000001', 'aaaa2222-0000-0000-0000-000000000001',
   'Sarah Lin', '@sarahlin_designs', 'Love this approach! How do you handle spontaneous posts alongside scheduled queues?', 'instagram'::platform, false, true),
  ('aaaa5555-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   'aaaa1111-0000-0000-0000-000000000002', 'aaaa2222-0000-0000-0000-000000000001',
   'Marcus Vance', '@marcus_v', 'This routine literally saved my mornings last week. Highly recommend framing the day first!', 'x'::platform, true, false);

-- ── User B: one channel, no posts (empty-queue test case) ────────────────────
insert into channels (id, user_id, platform, external_account_id, handle, display_name, status) values
  ('bbbb1111-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'tiktok', 'tt-1', '@adibmakes', 'Adib Makes', 'connected'::channel_status);
