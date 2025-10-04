-- Insert a deterministic "system" creator and a USDC token that references it.
-- Runs safely multiple times (idempotent).

DO $$
DECLARE
  sys_id uuid := '00000000-0000-0000-0000-000000000001'::uuid;
BEGIN
  -- creators.wallet is NOT NULL in your schema, so provide it.
  INSERT INTO public.creators (id, wallet, handle, created_at)
  VALUES (sys_id, 'USDC_TREASURY', 'system', now())
  ON CONFLICT (id) DO NOTHING;

  -- Now ensure USDC exists and points to the system creator.
  INSERT INTO public.tokens (
    creator_id, mint, curve, base_token, symbol, decimals, initial_supply, created_at
  )
  VALUES (
    sys_id, 'USDC', 'cpmm', 'USDC', 'USDC', 6, 0, now()
  )
  ON CONFLICT (mint) DO UPDATE
    SET creator_id = EXCLUDED.creator_id
  WHERE public.tokens.creator_id IS DISTINCT FROM EXCLUDED.creator_id;
END$$;
