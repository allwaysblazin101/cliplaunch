-- 032_fix_null_video_users.sql
-- Backfill and enforce non-null user_id for videos

BEGIN;

-- 1. Backfill missing user_id with the system creator (bob) if available
UPDATE videos v
SET user_id = u.id
FROM users u
WHERE v.user_id IS NULL
  AND u.handle = 'bob';

-- 2. Hide any videos that still lack a user_id (cannot resolve creator)
UPDATE videos
SET visibility = 2   -- hidden
WHERE user_id IS NULL;

-- 3. Enforce constraint: videos.user_id must not be null
ALTER TABLE videos
ALTER COLUMN user_id SET NOT NULL;

COMMIT;
