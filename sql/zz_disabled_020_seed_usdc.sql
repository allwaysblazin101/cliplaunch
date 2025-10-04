-- Seed USDC owned by the system creator, idempotently.
DO $$
DECLARE
  sys_creator uuid := '00000000-0000-0000-0000-000000000001'::uuid;
BEGIN
  -- Ensure the system creator exists with required NOT NULL columns.
  INSERT INTO public.creators (id, wallet, handle, created_at)
  VALUES (sys_creator, 'system_wallet', 'system', now())
  ON CONFLICT (id) DO NOTHING;

  -- Insert USDC if missing. Column list prevents misalignment, and creator_id is explicit.
  INSERT INTO public.tokens (
    creator_id, mint, curve, base_token, supply_cap,
    fee_bps_protocol, fee_bps_creator,
    initial_liquidity_base, initial_liquidity_asset,
    symbol, decimals, initial_supply, created_at
  ) VALUES (
    sys_creator, 'USDC', 'cpmm', 'USDC', NULL,
    0, 0,
    0, 0,
    'USDC', 6, 0, now()
  )
  ON CONFLICT (mint) DO NOTHING;
END $$;
