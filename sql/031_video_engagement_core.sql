-- Minimal schema for engagement so later migrations (032/033) stop failing

-- video_comments: one row per comment on a video
CREATE TABLE IF NOT EXISTS public.video_comments (
  id         BIGSERIAL PRIMARY KEY,
  video_id   UUID    NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  user_id    BIGINT  NOT NULL REFERENCES public.users(id)  ON DELETE CASCADE,
  body       TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- video_likes: one row per (user, video) like
CREATE TABLE IF NOT EXISTS public.video_likes (
  id         BIGSERIAL PRIMARY KEY,
  video_id   UUID    NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  user_id    BIGINT  NOT NULL REFERENCES public.users(id)  ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure only one like per (video,user)
CREATE UNIQUE INDEX IF NOT EXISTS uniq_video_like_user
  ON public.video_likes (video_id, user_id);

-- Helpful read-path index
CREATE INDEX IF NOT EXISTS video_likes_video_id_created_at_idx
  ON public.video_likes (video_id, created_at DESC);

-- video_comment_likes: one row per (user, comment) like
CREATE TABLE IF NOT EXISTS public.video_comment_likes (
  id               BIGSERIAL PRIMARY KEY,
  video_comment_id BIGINT  NOT NULL REFERENCES public.video_comments(id) ON DELETE CASCADE,
  user_id          BIGINT  NOT NULL REFERENCES public.users(id)          ON DELETE CASCADE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure only one like per (comment,user)
CREATE UNIQUE INDEX IF NOT EXISTS uniq_video_comment_like_user
  ON public.video_comment_likes (video_comment_id, user_id);

-- Helpful read-path index
CREATE INDEX IF NOT EXISTS video_comment_likes_comment_id_created_at_idx
  ON public.video_comment_likes (video_comment_id, created_at DESC);
