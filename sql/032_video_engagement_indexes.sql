DO $$
BEGIN
  -- video_likes
  IF to_regclass('public.video_likes') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='video_likes'
                 AND column_name='video_id')
    THEN
      CREATE INDEX IF NOT EXISTS video_likes_video_id_created_at_idx
        ON public.video_likes (video_id, created_at DESC);
    END IF;

    -- unique like per (video, user) if both cols exist
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='video_likes' AND column_name='video_id'
    ) AND EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='video_likes' AND column_name='user_id'
    ) THEN
      CREATE UNIQUE INDEX IF NOT EXISTS uniq_video_like_user
        ON public.video_likes (video_id, user_id);
    END IF;
  ELSE
    RAISE NOTICE 'video_likes missing; skipping indexes';
  END IF;

  -- video_comments
  IF to_regclass('public.video_comments') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='video_comments'
                 AND column_name='video_id')
    THEN
      CREATE INDEX IF NOT EXISTS video_comments_video_id_created_at_idx
        ON public.video_comments (video_id, created_at DESC);
    END IF;
  END IF;

  -- video_comment_likes
  IF to_regclass('public.video_comment_likes') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='video_comment_likes'
                 AND column_name='video_comment_id')
    THEN
      CREATE INDEX IF NOT EXISTS video_comment_likes_comment_id_created_at_idx
        ON public.video_comment_likes (video_comment_id, created_at DESC);
    END IF;
  END IF;
END $$;
