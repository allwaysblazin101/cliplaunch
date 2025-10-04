-- === Cliplaunch Demo Seed (idempotent) ===
-- Uses existing schema: creators, users, videos, video_likes, video_comments

BEGIN;

-- 0) Light reset of demo tables (keeps creators that may already exist)
TRUNCATE TABLE public.video_comment_likes RESTART IDENTITY;
TRUNCATE TABLE public.video_comments RESTART IDENTITY;
TRUNCATE TABLE public.video_likes RESTART IDENTITY;
TRUNCATE TABLE public.videos RESTART IDENTITY;
TRUNCATE TABLE public.users RESTART IDENTITY;

-- 1) Demo creators (wallet is unique)
INSERT INTO public.creators (id, wallet, handle, display_name, created_at)
VALUES
  (gen_random_uuid(), 'wallet_demo_creator1', 'creator1', 'Creator One',   now()),
  (gen_random_uuid(), 'wallet_demo_creator2', 'creator2', 'Creator Two',   now()),
  (gen_random_uuid(), 'wallet_demo_creator3', 'creator3', 'Creator Three', now())
ON CONFLICT (wallet) DO NOTHING;

-- 2) Demo users
INSERT INTO public.users (id, handle, display_name, created_at) VALUES
  (1, 'user1', 'Alice',   now()),
  (2, 'user2', 'Bob',     now()),
  (3, 'user3', 'Charlie', now())
ON CONFLICT (id) DO NOTHING;

-- 3) Demo videos (correct columns: playback_hls_url, visibility)
WITH demo_vids AS (
  SELECT *
  FROM (VALUES
    ('creator1','Welcome to Cliplaunch','Welcome to the on-chain creator economy!','https://cdn.cliplaunch.dev/video1.m3u8'),
    ('creator2','Behind the Build','How Cliplaunch merges social + blockchain.','https://cdn.cliplaunch.dev/video2.m3u8'),
    ('creator3','Pump Your Brand','Why creators thrive with tokenized engagement.','https://cdn.cliplaunch.dev/video3.m3u8')
  ) AS v(handle, title, description, url)
), c AS (
  SELECT id, handle FROM public.creators WHERE handle IN ('creator1','creator2','creator3')
)
INSERT INTO public.videos
  (id,       creator_id, title,           description,              playback_hls_url,              storage_txid, duration_s, visibility, created_at)
SELECT
  gen_random_uuid(), c.id,     v.title,   v.description,            v.url,                          NULL,        NULL,       0,          now()
FROM demo_vids v
JOIN c ON c.handle = v.handle
ON CONFLICT (id) DO NOTHING;

-- 4) Seed engagement on first two videos
WITH v AS (
  SELECT id FROM public.videos ORDER BY created_at ASC LIMIT 2
)
INSERT INTO public.video_likes (video_id, user_id, created_at)
SELECT v.id, u.id, now()
FROM v CROSS JOIN (SELECT id FROM public.users WHERE id IN (1,2)) u
ON CONFLICT DO NOTHING;

WITH v AS (
  SELECT id FROM public.videos ORDER BY created_at DESC LIMIT 1
)
INSERT INTO public.video_comments (video_id, user_id, body, created_at)
SELECT v.id, 1, 'Day 1 on Cliplaunch. Let''s go!', now() FROM v
UNION ALL
SELECT v.id, 2, 'This is the future.', now() FROM v
ON CONFLICT DO NOTHING;

COMMIT;

-- Summary rows (handy when executed with -f)
SELECT 'videos' AS t, count(*) FROM public.videos
UNION ALL SELECT 'video_likes', count(*) FROM public.video_likes
UNION ALL SELECT 'video_comments', count(*) FROM public.video_comments
UNION ALL SELECT 'users', count(*) FROM public.users
UNION ALL SELECT 'creators', count(*) FROM public.creators;
