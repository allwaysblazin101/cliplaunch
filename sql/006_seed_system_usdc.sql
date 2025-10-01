-- system USDC (idempotent)
INSERT INTO tokens (mint, symbol, decimals, initial_supply, base_token, creator_id, created_at)
VALUES ('USDC','USDC',6,0,'USDC',NULL,now())
ON CONFLICT (mint) DO UPDATE
  SET symbol='USDC', decimals=6, base_token='USDC';
