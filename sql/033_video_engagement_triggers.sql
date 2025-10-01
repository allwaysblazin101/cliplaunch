-- Add + backfill last_engaged_at; keep it maintained by likes/comments
ALTER TABLE videos
  ADD COLUMN IF NOT EXISTS last_engaged_at timestamptz;

UPDATE videos
SET last_engaged_at = COALESCE(last_engaged_at, created_at)
WHERE last_engaged_at IS NULL;

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_videos_engaged_at ON videos (GREATEST(created_at, COALESCE(last_engaged_at, created_at)));
CREATE UNIQUE INDEX IF NOT EXISTS uniq_video_like_user ON video_likes (video_id, user_id);
CREATE INDEX IF NOT EXISTS idx_video_comments_video_time ON video_comments (video_id, created_at);

-- Trigger function bumps last_engaged_at whenever there is new engagement
CREATE OR REPLACE FUNCTION bump_video_last_engaged()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE videos
  SET last_engaged_at = now()
  WHERE id = NEW.video_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_video_like_bump ON video_likes;
CREATE TRIGGER trg_video_like_bump
AFTER INSERT ON video_likes
FOR EACH ROW EXECUTE FUNCTION bump_video_last_engaged();

DROP TRIGGER IF EXISTS trg_video_comment_bump ON video_comments;
CREATE TRIGGER trg_video_comment_bump
AFTER INSERT ON video_comments
FOR EACH ROW EXECUTE FUNCTION bump_video_last_engaged();
