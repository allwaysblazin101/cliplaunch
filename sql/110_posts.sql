DO $$
BEGIN
  -- Ensure posts table (idempotent)
  IF to_regclass('public.posts') IS NULL THEN
    CREATE TABLE public.posts (
      id         BIGSERIAL PRIMARY KEY,
      author_id  BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
      body       TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  END IF;

  -- If someone created posts with user_id in another branch, normalize to author_id
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='posts' AND column_name='user_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='posts' AND column_name='author_id'
  ) THEN
    ALTER TABLE public.posts RENAME COLUMN user_id TO author_id;
  END IF;

  -- Preferred index on (author_id, created_at)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='posts' AND column_name='author_id'
  ) THEN
    CREATE INDEX IF NOT EXISTS posts_author_created_idx
      ON public.posts (author_id, created_at DESC);
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='posts' AND column_name='user_id'
  ) THEN
    CREATE INDEX IF NOT EXISTS posts_user_created_idx
      ON public.posts (user_id, created_at DESC);
  ELSE
    RAISE NOTICE 'posts has neither author_id nor user_id; skipping index';
  END IF;
END $$;
