-- requires pgcrypto or uuid-ossp for gen_random_uuid(); assuming pgcrypto
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1) videos
CREATE TABLE IF NOT EXISTS videos (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id        uuid NOT NULL REFERENCES creators(id) ON DELETE CASCADE,
  title             text NOT NULL,
  description       text,
  video_url         text NOT NULL,
  thumb_url         text,
  duration_seconds  integer,
  visibility        text NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','unlisted','private')),
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_videos_creator_created_at
ON videos(creator_id, created_at DESC);

-- 2) video_likes (unique one like per user per video)
CREATE TABLE IF NOT EXISTS video_likes (
  video_id   uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (video_id, user_id)
);

-- 3) video_comments
CREATE TABLE IF NOT EXISTS video_comments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id   uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body       text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_video_comments_video_created_at
ON video_comments(video_id, created_at ASC);
