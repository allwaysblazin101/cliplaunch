-- Drop anything depending on ledger_entries.mint so we can change its type
DROP VIEW IF EXISTS wallet_balances;

BEGIN;

-- Make sure we can change the column type
ALTER TABLE ledger_entries DROP CONSTRAINT IF EXISTS ledger_entries_mint_fkey;

-- Align type with tokens.mint (text)
ALTER TABLE ledger_entries
  ALTER COLUMN mint TYPE text USING mint::text;

-- Recreate FK to tokens(mint)
ALTER TABLE ledger_entries
  ADD CONSTRAINT ledger_entries_mint_fkey
  FOREIGN KEY (mint) REFERENCES tokens(mint) ON DELETE CASCADE;

COMMIT;

-- Recreate the balances view (simple aggregate)
CREATE VIEW wallet_balances AS
SELECT owner, mint, SUM(delta) AS balance
FROM ledger_entries
GROUP BY owner, mint;

-- Helpful index for reads
CREATE INDEX IF NOT EXISTS ledger_entries_owner_mint_idx
  ON ledger_entries(owner, mint);
