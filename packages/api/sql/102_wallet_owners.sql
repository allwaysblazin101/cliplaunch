CREATE TABLE IF NOT EXISTS wallet_owners (
  owner   text PRIMARY KEY,         -- pubkey (e.g. 32+ chars)
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
