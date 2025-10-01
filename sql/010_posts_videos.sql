-- Safe, idempotent helpers
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- POSTS
CREATE TABLE IF NOT EXISTS posts (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title       text NOT NULL,
  description text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_posts_user_created ON posts(user_id, created_at DESC);

-- VIDEOS
CREATE TABLE IF NOT EXISTS videos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title           text NOT NULL,
  description     text,
  video_url       text NOT NULL,
  thumbnail_url   text,
  duration_sec    integer,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_videos_user_created ON videos(user_id, created_at DESC);

-- LIKES (unique per user per video)
CREATE TABLE IF NOT EXISTS video_likes (
  video_id   uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (video_id, user_id)
);

-- COMMENTS
CREATE TABLE IF NOT EXISTS video_comments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id   uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body       text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_video_comments_vid_created ON video_comments(video_id, created_at DESC);
