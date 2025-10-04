DO $$
DECLARE
  sys_id uuid := '00000000-0000-0000-0000-000000000001'::uuid;
BEGIN
  INSERT INTO public.tokens (
    creator_id, mint, curve, base_token, symbol, decimals,
    supply_cap, fee_bps_protocol, fee_bps_creator,
    initial_liquidity_base, initial_liquidity_asset,
    initial_supply, created_at
  ) VALUES (
    sys_id, 'USDC', 'cpmm', 'USDC', 'USDC', 6,
    NULL, 0, 0, 0, 0, 0, now()
  )
  ON CONFLICT (mint) DO UPDATE
    SET creator_id = EXCLUDED.creator_id,
        decimals   = EXCLUDED.decimals,
        symbol     = EXCLUDED.symbol;
END $$;
