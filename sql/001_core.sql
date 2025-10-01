CREATE TABLE IF NOT EXISTS creators (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet TEXT NOT NULL UNIQUE,
  handle CITEXT UNIQUE,
  display_name TEXT,
  bio TEXT,
  avatar_url TEXT,
  token_mint TEXT UNIQUE,
  status SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id UUID NOT NULL REFERENCES creators(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  playback_hls_url TEXT NOT NULL,
  storage_txid TEXT,
  duration_s INT,
  visibility SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tokens (
  creator_id UUID PRIMARY KEY REFERENCES creators(id) ON DELETE CASCADE,
  mint TEXT NOT NULL UNIQUE,
  curve TEXT NOT NULL DEFAULT 'cpmm',
  base_token TEXT NOT NULL,
  supply_cap NUMERIC(38,0),
  fee_bps_protocol INT NOT NULL,
  fee_bps_creator INT NOT NULL,
  initial_liquidity_base NUMERIC(38,0) DEFAULT 0,
  initial_liquidity_asset NUMERIC(38,0) DEFAULT 0
);

CREATE TABLE IF NOT EXISTS trades (
  id BIGSERIAL PRIMARY KEY,
  mint TEXT NOT NULL,
  side SMALLINT NOT NULL, -- 0 buy, 1 sell
  size_base NUMERIC(38,0) NOT NULL,
  size_quote NUMERIC(38,0) NOT NULL,
  price NUMERIC(24,12) NOT NULL,
  tx_sig TEXT NOT NULL,
  wallet TEXT NOT NULL,
  ts TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tips (
  id BIGSERIAL PRIMARY KEY,
  video_id UUID NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  from_wallet TEXT NOT NULL,
  amount NUMERIC(38,0) NOT NULL,
  currency TEXT NOT NULL,
  tx_sig TEXT NOT NULL,
  ts TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS comments (
  id BIGSERIAL PRIMARY KEY,
  video_id UUID NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  wallet TEXT NOT NULL,
  text TEXT NOT NULL,
  status SMALLINT NOT NULL DEFAULT 0, -- 0 visible, 1 removed, 2 shadow
  ts TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS moderation_events (
  id BIGSERIAL PRIMARY KEY,
  subject_type SMALLINT NOT NULL, -- 0 creator, 1 video, 2 comment, 3 token
  subject_id TEXT NOT NULL,
  action SMALLINT NOT NULL,       -- 0 suspend, 1 unsuspend, 2 delete, 3 shadow
  reason TEXT,
  actor TEXT,
  ts TIMESTAMPTZ NOT NULL DEFAULT now()
);
