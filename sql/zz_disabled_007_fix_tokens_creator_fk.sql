-- If tokens.creator_id exists, set any NULLs to the system creator
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='tokens' AND column_name='creator_id'
  ) THEN
    UPDATE public.tokens SET creator_id = 1 WHERE creator_id IS NULL;
  END IF;
END
$$;
