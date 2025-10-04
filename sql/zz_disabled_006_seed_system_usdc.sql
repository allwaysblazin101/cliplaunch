-- Seed a USDC token owned by the "system" creator.
DO $$
DECLARE
  sys_id uuid;
BEGIN
  -- Look up the system creator (inserted by 006_seed_system_creator.sql)
  SELECT id INTO sys_id
  FROM public.creators
  WHERE handle = 'system'
  LIMIT 1;

  -- Insert USDC if it doesn't already exist (mint is UNIQUE)
  INSERT INTO public.tokens (
      creator_id, mint, curve, base_token, supply_cap,
      fee_bps_protocol, fee_bps_creator,
      initial_liquidity_base, initial_liquidity_asset,
      symbol, decimals, initial_supply, created_at
  ) VALUES (
      sys_id, 'USDC', 'cpmm', 'USDC', NULL,
      0, 0,
      0, 0,
      'USDC', 6, 0, now()
  )
  ON CONFLICT (mint) DO NOTHING;
END$$;
