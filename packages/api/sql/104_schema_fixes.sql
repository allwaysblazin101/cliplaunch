ALTER TABLE tokens
  ADD CONSTRAINT IF NOT EXISTS tokens_mint_unique UNIQUE (mint);

CREATE UNIQUE INDEX IF NOT EXISTS creators_user_id_key ON creators(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS wallet_owners_owner_key ON wallet_owners(owner);

CREATE INDEX IF NOT EXISTS idx_activities_created_at ON activities(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_created_at     ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_follows_follower      ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_followee      ON follows(followee_id);
