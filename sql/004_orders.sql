-- UUIDs (debian/ubuntu images often have pgcrypto not uuid-ossp)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS orders (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mint        text NOT NULL REFERENCES tokens(mint) ON DELETE CASCADE,
  side        text NOT NULL CHECK (side IN ('buy','sell')),
  amount_in   numeric(39,0) NOT NULL,
  amount_out  numeric(39,0) NOT NULL,
  price       numeric(20,6) NOT NULL,
  payer       text NOT NULL,
  status      text NOT NULL DEFAULT 'preview',
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS orders_mint_idx ON orders(mint);
CREATE INDEX IF NOT EXISTS orders_created_at_desc ON orders(created_at DESC);
