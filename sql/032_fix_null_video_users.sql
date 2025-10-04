DO $$
BEGIN
  -- Only run if videos.user_id actually exists
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='videos' AND column_name='user_id'
  ) THEN
    -- If we also have creator_id, opportunistically backfill from creators
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='videos' AND column_name='creator_id'
    ) THEN
      UPDATE public.videos v
      SET user_id = c.id
      FROM public.creators c
      WHERE v.user_id IS NULL
        AND v.creator_id = c.id;
    END IF;
  ELSE
    RAISE NOTICE 'videos.user_id not present; skipping 032_fix_null_video_users.sql';
  END IF;
END $$;
