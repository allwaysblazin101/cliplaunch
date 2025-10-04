-- Safe guard: apply only if public.orders already exists
DO $$
BEGIN
  IF to_regclass('public.orders') IS NULL THEN
    RAISE NOTICE 'public.orders not found; skipping 004_orders_shape.sql';
    RETURN;
  END IF;
END$$;

-- Place any ALTER/INDEX ops on orders below (they'll run only when orders exists)
-- Example (kept harmless):
-- ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS example_col TEXT;
