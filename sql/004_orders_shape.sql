-- 004_orders_shape.sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS payer text;

UPDATE orders SET payer = COALESCE(payer, '');
ALTER TABLE orders ALTER COLUMN payer SET NOT NULL;

ALTER TABLE orders
  ALTER COLUMN id         SET DEFAULT gen_random_uuid(),
  ALTER COLUMN created_at SET DEFAULT NOW(),
  ALTER COLUMN status     SET DEFAULT 'preview';

CREATE INDEX IF NOT EXISTS orders_mint_idx        ON orders(mint);
CREATE INDEX IF NOT EXISTS orders_created_at_idx  ON orders(created_at DESC);
