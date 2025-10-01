-- UUIDs for ledger ids
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1) Wallet balances (source of truth for the stub executor)
CREATE TABLE IF NOT EXISTS wallets (
  owner      text        NOT NULL,                     -- public key
  mint       text        NOT NULL REFERENCES tokens(mint) ON DELETE CASCADE,
  balance    numeric(39,0) NOT NULL DEFAULT 0,         -- base units
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (owner, mint)
);
CREATE INDEX IF NOT EXISTS wallets_owner_idx ON wallets(owner);

-- 2) Double-entry ledger (append-only)
CREATE TABLE IF NOT EXISTS ledger_entries (
  id         uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  owner      text         NOT NULL,
  mint       text         NOT NULL REFERENCES tokens(mint) ON DELETE CASCADE,
  delta      numeric(39,0) NOT NULL,                   -- +credit / -debit
  reason     text         NOT NULL,                    -- e.g. order:debit_base, order:credit_asset
  order_id   uuid         REFERENCES orders(id) ON DELETE SET NULL,
  created_at timestamptz  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ledger_owner_idx ON ledger_entries(owner);
CREATE INDEX IF NOT EXISTS ledger_order_idx ON ledger_entries(order_id);
