-- Unique like per (video,user)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'uniq_video_like_user'
  ) THEN
    CREATE UNIQUE INDEX uniq_video_like_user
      ON video_likes(video_id, user_id);
  END IF;
END$$;

-- Speed comment lookups & trending aggregation
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'idx_video_comments_video_created'
  ) THEN
    CREATE INDEX idx_video_comments_video_created
      ON video_comments(video_id, created_at DESC);
  END IF;
END$$;
