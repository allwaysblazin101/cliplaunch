-- Create trending-related indexes only if the tables/columns exist

DO $$
BEGIN
  -- Legacy posts tables (safe to skip if they don't exist)
  IF to_regclass('public.post_likes') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='post_likes'
                 AND column_name='post_id')
    THEN
      CREATE INDEX IF NOT EXISTS post_likes_post_id_created_at_idx
        ON public.post_likes (post_id, created_at DESC);
    END IF;
  ELSE
    RAISE NOTICE 'post_likes missing; skipping';
  END IF;

  IF to_regclass('public.post_comments') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='post_comments'
                 AND column_name='post_id')
    THEN
      CREATE INDEX IF NOT EXISTS post_comments_post_id_created_at_idx
        ON public.post_comments (post_id, created_at DESC);
    END IF;
  END IF;

  IF to_regclass('public.post_comment_likes') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='post_comment_likes'
                 AND column_name='post_comment_id')
    THEN
      CREATE INDEX IF NOT EXISTS post_comment_likes_comment_id_created_at_idx
        ON public.post_comment_likes (post_comment_id, created_at DESC);
    END IF;
  END IF;

  -- Newer video tables (use these if present)
  IF to_regclass('public.video_likes') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='video_likes'
                 AND column_name='video_id')
    THEN
      CREATE INDEX IF NOT EXISTS video_likes_video_id_created_at_idx
        ON public.video_likes (video_id, created_at DESC);
    END IF;
  END IF;

  IF to_regclass('public.video_comments') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='video_comments'
                 AND column_name='video_id')
    THEN
      CREATE INDEX IF NOT EXISTS video_comments_video_id_created_at_idx
        ON public.video_comments (video_id, created_at DESC);
    END IF;
  END IF;

  IF to_regclass('public.video_comment_likes') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='video_comment_likes'
                 AND column_name='comment_id')
    THEN
      CREATE INDEX IF NOT EXISTS video_comment_likes_comment_id_created_at_idx
        ON public.video_comment_likes (comment_id, created_at DESC);
    END IF;
  END IF;
END $$;
