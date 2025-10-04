-- Only run if ledger_entries exists
DO $$
BEGIN
  IF to_regclass('public.ledger_entries') IS NULL THEN
    RAISE NOTICE 'public.ledger_entries not found; skipping 005_fix_ledger_entries.sql';
    RETURN;
  END IF;
END$$;

-- If the view wallet_balances is referenced, keep this defensive too:
DO $$
BEGIN
  IF to_regclass('public.wallet_balances') IS NULL THEN
    RAISE NOTICE 'public.wallet_balances view not found; skipping related statements';
    RETURN;
  END IF;
END$$;

-- Place your real ALTER/UPDATE/INDEX statements below.
-- They will execute only when the table/view exist.
-- Example (harmless no-op to show structure):
-- ALTER TABLE public.ledger_entries
--   ADD COLUMN IF NOT EXISTS note TEXT;
