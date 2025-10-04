-- Seed USDC owned by the system creator (created earlier).
DO $$
DECLARE
  sys_id uuid := '00000000-0000-0000-0000-000000000001'::uuid;
BEGIN
  INSERT INTO public.tokens (
    creator_id,
    mint,
    curve,
    base_token,
    symbol,
    decimals,
    supply_cap,              -- nullable in your describe; keep NULL if allowed
    fee_bps_protocol,        -- NOT NULL
    fee_bps_creator,         -- NOT NULL
    initial_liquidity_base,  -- NOT NULL
    initial_liquidity_asset, -- NOT NULL
    initial_supply,          -- NOT NULL
    created_at               -- NOT NULL
  ) VALUES (
    sys_id,
    'USDC',
    'cpmm',
    'USDC',
    'USDC',
    6,
    NULL,       -- change to a number if supply_cap is NOT NULL in your build
    0,
    0,
    0,
    0,
    0,
    now()
  )
  ON CONFLICT (mint) DO UPDATE
    SET creator_id = EXCLUDED.creator_id,
        decimals   = EXCLUDED.decimals,
        symbol     = EXCLUDED.symbol;
END $$;
