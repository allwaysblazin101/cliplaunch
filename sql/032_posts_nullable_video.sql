DO $$
BEGIN
  -- If we still have the old text column, relax its nullability
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='posts' AND column_name='video_url'
  ) THEN
    ALTER TABLE public.posts ALTER COLUMN video_url DROP NOT NULL;
    RAISE NOTICE 'dropped NOT NULL on posts.video_url';
  
  -- Otherwise, if we have the FK-style column, relax that
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='posts' AND column_name='video_id'
  ) THEN
    ALTER TABLE public.posts ALTER COLUMN video_id DROP NOT NULL;
    RAISE NOTICE 'dropped NOT NULL on posts.video_id';

  ELSE
    RAISE NOTICE 'posts.video_url / posts.video_id not present; skipping 032_posts_nullable_video.sql';
  END IF;
END $$;
