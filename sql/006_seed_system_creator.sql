-- Ensure a deterministic "system" creator exists.
DO $$
DECLARE
  sys_id uuid := '00000000-0000-0000-0000-000000000001';
BEGIN
  INSERT INTO public.creators (id, wallet, handle, created_at)
  VALUES (sys_id, 'system_wallet', 'system', now())
  ON CONFLICT (id) DO NOTHING;
END$$;
