-- Idempotently ensure a "system" user/creator and a USDC token with creator_id

WITH sys_user AS (
  INSERT INTO users (handle, display_name)
  VALUES ('system','System')
  ON CONFLICT (handle) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING id
),
cre_upd AS (
  UPDATE creators
     SET handle = 'system',
         wallet = 'USDC_TREASURY',
         bio    = 'System treasury'
   WHERE user_id = (SELECT id FROM sys_user)
  RETURNING id
),
cre_ins AS (
  INSERT INTO creators (user_id, handle, wallet, bio)
  SELECT (SELECT id FROM sys_user), 'system', 'USDC_TREASURY', 'System treasury'
  WHERE NOT EXISTS (SELECT 1 FROM cre_upd)
  RETURNING id
),
sys_creator AS (
  SELECT COALESCE((SELECT id FROM cre_upd), (SELECT id FROM cre_ins)) AS id
),
tok_upd AS (
  UPDATE tokens t
     SET symbol = 'USDC',
         decimals = 6,
         initial_supply = 0,
         base_token = 'USDC',
         creator_id = (SELECT id FROM sys_creator)
   WHERE mint = 'USDC'
  RETURNING 1
)
INSERT INTO tokens (mint, symbol, decimals, initial_supply, base_token, creator_id, created_at)
SELECT 'USDC','USDC',6,0,'USDC', (SELECT id FROM sys_creator), now()
WHERE NOT EXISTS (SELECT 1 FROM tok_upd);
