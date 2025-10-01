CREATE TABLE IF NOT EXISTS users (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  handle       text UNIQUE NOT NULL,
  display_name text NOT NULL,
  avatar_url   text,
  bio          text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE creators
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES users(id);

CREATE TABLE IF NOT EXISTS follows (
  follower_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id)
);

CREATE TABLE IF NOT EXISTS videos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id    uuid NOT NULL REFERENCES creators(id) ON DELETE CASCADE,
  title         text NOT NULL,
  description   text,
  playback_url  text NOT NULL,
  thumb_url     text,
  duration_s    integer,
  visibility    text NOT NULL DEFAULT 'public',
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS video_likes (
  user_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  video_id  uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, video_id)
);

CREATE TABLE IF NOT EXISTS activities (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  actor       uuid,
  verb        text NOT NULL,
  object_id   uuid,
  object_type text,
  meta        jsonb
);

CREATE INDEX IF NOT EXISTS activities_created_idx ON activities(created_at DESC);
