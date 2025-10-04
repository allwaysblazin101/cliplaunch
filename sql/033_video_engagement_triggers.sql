DO $$
BEGIN
  -- Ensure bump column & index on videos
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='videos' AND column_name='last_engaged_at'
  ) THEN
    ALTER TABLE public.videos ADD COLUMN last_engaged_at TIMESTAMPTZ;
  ELSE
    RAISE NOTICE 'column "last_engaged_at" of relation "videos" already exists, skipping';
  END IF;

  CREATE INDEX IF NOT EXISTS idx_videos_engaged_at
    ON public.videos (COALESCE(last_engaged_at, created_at) DESC);

  -- Helpful unique if missing (safe if already exists)
  IF to_regclass('public.video_likes') IS NOT NULL THEN
    CREATE UNIQUE INDEX IF NOT EXISTS uniq_video_like_user
      ON public.video_likes (video_id, user_id);
    CREATE INDEX IF NOT EXISTS video_likes_video_id_created_at_idx
      ON public.video_likes (video_id, created_at DESC);
  END IF;

  -- Bump function
  CREATE OR REPLACE FUNCTION public.bump_video_last_engaged()
  RETURNS trigger
  LANGUAGE plpgsql
  AS $FN$
  BEGIN
    UPDATE public.videos
       SET last_engaged_at = GREATEST(COALESCE(last_engaged_at, '-infinity'::timestamptz), now())
     WHERE id = NEW.video_id;
    RETURN NEW;
  END
  $FN$;

  -- Triggers, only if source tables exist
  IF to_regclass('public.video_likes') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_video_like_bump ON public.video_likes;
    CREATE TRIGGER trg_video_like_bump
      AFTER INSERT ON public.video_likes
      FOR EACH ROW EXECUTE FUNCTION public.bump_video_last_engaged();
  END IF;

  IF to_regclass('public.video_comments') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_video_comment_bump ON public.video_comments;
    CREATE TRIGGER trg_video_comment_bump
      AFTER INSERT ON public.video_comments
      FOR EACH ROW EXECUTE FUNCTION public.bump_video_last_engaged();
  END IF;
END $$;
