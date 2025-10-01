ALTER TABLE tokens
  ADD COLUMN IF NOT EXISTS symbol text,
  ADD COLUMN IF NOT EXISTS decimals integer,
  ADD COLUMN IF NOT EXISTS initial_supply numeric(39,0),
  ADD COLUMN IF NOT EXISTS created_at timestamptz;

-- Backfill with safe defaults
UPDATE tokens SET symbol = COALESCE(symbol, 'TKN');
UPDATE tokens SET decimals = COALESCE(decimals, 9);
UPDATE tokens SET initial_supply = COALESCE(initial_supply, 0);
UPDATE tokens SET created_at = COALESCE(created_at, NOW());

-- Enforce NOT NULL
ALTER TABLE tokens
  ALTER COLUMN symbol SET NOT NULL,
  ALTER COLUMN decimals SET NOT NULL,
  ALTER COLUMN initial_supply SET NOT NULL,
  ALTER COLUMN created_at SET NOT NULL;

-- Helpful index
CREATE INDEX IF NOT EXISTS tokens_mint_idx ON tokens(mint);
