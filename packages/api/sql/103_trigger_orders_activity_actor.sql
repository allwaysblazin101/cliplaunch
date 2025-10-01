CREATE OR REPLACE FUNCTION log_order_activity() RETURNS trigger AS $$
DECLARE
  actor_user uuid;
BEGIN
  IF NEW.status = 'executed' AND (OLD.status IS DISTINCT FROM 'executed') THEN
    SELECT wo.user_id INTO actor_user
    FROM wallet_owners wo
    WHERE wo.owner = NEW.payer;

    INSERT INTO activities (actor, verb, object_id, object_type, meta, created_at)
    VALUES (
      actor_user,                -- can be NULL if unbound, feed will then skip join
      'buy',
      NEW.id,
      'order',
      jsonb_build_object(
        'mint', NEW.mint,
        'amount_in', NEW.amount_in,
        'amount_out', NEW.amount_out,
        'payer', NEW.payer
      ),
      now()
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_orders_activity ON orders;
CREATE TRIGGER trg_orders_activity
AFTER UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION log_order_activity();
