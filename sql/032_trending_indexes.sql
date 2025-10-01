-- Engagement tables (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_post_likes_recent
  ON post_likes (created_at DESC, post_id);
CREATE INDEX IF NOT EXISTS idx_video_likes_recent
  ON video_likes (created_at DESC, video_id);

CREATE INDEX IF NOT EXISTS idx_post_comments_recent
  ON post_comments (created_at DESC, post_id);
CREATE INDEX IF NOT EXISTS idx_video_comments_recent
  ON video_comments (created_at DESC, video_id);

CREATE INDEX IF NOT EXISTS idx_follows_recent
  ON follows (created_at DESC, followee_id);
