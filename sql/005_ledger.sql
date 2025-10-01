-- id + timestamp helpers
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Movements of value
CREATE TABLE IF NOT EXISTS ledger_entries (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner      text        NOT NULL,              -- wallet pubkey
  mint       text        NOT NULL,              -- token mint (or base symbol)
  delta      numeric(39,0) NOT NULL,            -- signed base units
  reason     text        NOT NULL,              -- e.g. 'order-exec', 'faucet'
  order_id   uuid        NULL REFERENCES orders(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ledger_owner_idx       ON ledger_entries(owner);
CREATE INDEX IF NOT EXISTS ledger_owner_mint_idx  ON ledger_entries(owner, mint);
CREATE INDEX IF NOT EXISTS ledger_created_idx     ON ledger_entries(created_at);

-- Lightweight balances view (sum of deltas)
CREATE OR REPLACE VIEW wallet_balances AS
SELECT owner, mint, COALESCE(SUM(delta),0)::numeric(39,0) AS balance
FROM ledger_entries
GROUP BY owner, mint;
