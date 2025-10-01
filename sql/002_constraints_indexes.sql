-- Uniqueness (handle already CITEXT UNIQUE, enforce other invariants)
ALTER TABLE creators
  ALTER COLUMN wallet SET NOT NULL,
  ALTER COLUMN handle SET NOT NULL;

ALTER TABLE videos
  ALTER COLUMN title SET NOT NULL,
  ALTER COLUMN playback_hls_url SET NOT NULL,
  ALTER COLUMN created_at SET NOT NULL;

-- Helpful composite indexes
CREATE INDEX IF NOT EXISTS videos_creator_created_idx
  ON videos (creator_id, created_at DESC);

CREATE INDEX IF NOT EXISTS creators_created_idx
  ON creators (created_at DESC);

-- Fast lookups by handle and wallet
CREATE INDEX IF NOT EXISTS creators_handle_idx
  ON creators (handle);

CREATE INDEX IF NOT EXISTS creators_wallet_idx
  ON creators (wallet);

-- Comments/trades indexes were defined before; ensure they exist
CREATE INDEX IF NOT EXISTS comments_video_ts_idx
  ON comments (video_id, ts DESC);

CREATE INDEX IF NOT EXISTS trades_mint_ts_idx
  ON trades (mint, ts DESC);
