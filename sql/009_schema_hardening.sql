BEGIN;

-- 1) One creator per user (your code assumes this)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'creators_user_id_key') THEN
    ALTER TABLE creators
      ADD CONSTRAINT creators_user_id_key UNIQUE (user_id);
  END IF;
END$$;

-- 2) Each wallet owner only once (your upserts use ON CONFLICT (owner))
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'wallet_owners_owner_key') THEN
    ALTER TABLE wallet_owners
      ADD CONSTRAINT wallet_owners_owner_key UNIQUE (owner);
  END IF;
END$$;

-- 3) Token mint as primary key (fixes future FKs like ledger_entries.mint)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tokens_pkey') THEN
    ALTER TABLE tokens ADD PRIMARY KEY (mint);
  END IF;
END$$;

-- 4) Consistent created_at defaults (so app doesn’t need to set them)
--    These tables exist in your flow; ignore if a table/column is missing on your branch.
DO $$ BEGIN
  PERFORM 1 FROM information_schema.columns
   WHERE table_name='users' AND column_name='created_at';
  IF FOUND THEN EXECUTE 'ALTER TABLE users ALTER COLUMN created_at SET DEFAULT now()'; END IF;
END $$;

DO $$ BEGIN
  PERFORM 1 FROM information_schema.columns
   WHERE table_name='creators' AND column_name='created_at';
  IF FOUND THEN EXECUTE 'ALTER TABLE creators ALTER COLUMN created_at SET DEFAULT now()'; END IF;
END $$;

DO $$ BEGIN
  PERFORM 1 FROM information_schema.columns
   WHERE table_name='tokens' AND column_name='created_at';
  IF FOUND THEN EXECUTE 'ALTER TABLE tokens ALTER COLUMN created_at SET DEFAULT now()'; END IF;
END $$;

DO $$ BEGIN
  PERFORM 1 FROM information_schema.columns
   WHERE table_name='orders' AND column_name='created_at';
  IF FOUND THEN EXECUTE 'ALTER TABLE orders ALTER COLUMN created_at SET DEFAULT now()'; END IF;
END $$;

DO $$ BEGIN
  PERFORM 1 FROM information_schema.columns
   WHERE table_name='activities' AND column_name='created_at';
  IF FOUND THEN EXECUTE 'ALTER TABLE activities ALTER COLUMN created_at SET DEFAULT now()'; END IF;
END $$;

DO $$ BEGIN
  PERFORM 1 FROM information_schema.columns
   WHERE table_name='follows' AND column_name='created_at';
  IF FOUND THEN EXECUTE 'ALTER TABLE follows ALTER COLUMN created_at SET DEFAULT now()'; END IF;
END $$;

DO $$ BEGIN
  PERFORM 1 FROM information_schema.columns
   WHERE table_name='ledger_entries' AND column_name='created_at';
  IF FOUND THEN EXECUTE 'ALTER TABLE ledger_entries ALTER COLUMN created_at SET DEFAULT now()'; END IF;
END $$;

-- 5) Orders must be positive (amounts are stored as text; cast to numeric to validate)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='orders_amount_in_pos') THEN
    ALTER TABLE orders ADD CONSTRAINT orders_amount_in_pos CHECK ((amount_in)::numeric > 0);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='orders_amount_out_pos') THEN
    ALTER TABLE orders ADD CONSTRAINT orders_amount_out_pos CHECK ((amount_out)::numeric >= 0);
  END IF;
END$$;

COMMIT;
