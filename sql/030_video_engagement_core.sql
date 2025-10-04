DO $$
BEGIN
  -- video_comments
  IF to_regclass('public.video_comments') IS NULL THEN
    CREATE TABLE public.video_comments (
      id         BIGSERIAL PRIMARY KEY,
      video_id   UUID    NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
      user_id    BIGINT  NOT NULL REFERENCES public.users(id)  ON DELETE CASCADE,
      body       TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  END IF;

  -- video_likes
  IF to_regclass('public.video_likes') IS NULL THEN
    CREATE TABLE public.video_likes (
      id         BIGSERIAL PRIMARY KEY,
      video_id   UUID    NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
      user_id    BIGINT  NOT NULL REFERENCES public.users(id)  ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  END IF;

  -- video_comment_likes
  IF to_regclass('public.video_comment_likes') IS NULL THEN
    CREATE TABLE public.video_comment_likes (
      id               BIGSERIAL PRIMARY KEY,
      video_comment_id BIGINT  NOT NULL REFERENCES public.video_comments(id) ON DELETE CASCADE,
      user_id          BIGINT  NOT NULL REFERENCES public.users(id)          ON DELETE CASCADE,
      created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  END IF;
END $$;
