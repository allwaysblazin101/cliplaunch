DO $$
BEGIN
  -- Only add the unique constraint if the column actually exists.
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'creators'
      AND column_name  = 'user_id'
  ) THEN
    -- And only if the constraint isn't already present.
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      WHERE t.relname = 'creators'
        AND c.conname = 'creators_user_id_key'
    ) THEN
      EXECUTE 'ALTER TABLE public.creators
               ADD CONSTRAINT creators_user_id_key UNIQUE (user_id)';
    END IF;
  ELSE
    RAISE NOTICE 'Skipping: creators.user_id does not exist';
  END IF;
END $$;
