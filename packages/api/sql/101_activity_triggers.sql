CREATE OR REPLACE FUNCTION log_order_activity() RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'executed' AND (OLD.status IS DISTINCT FROM 'executed') THEN
    INSERT INTO activities (actor, verb, object_id, object_type, meta)
    VALUES (
      NULL,
      'buy',
      NEW.id,
      'order',
      jsonb_build_object(
        'mint', NEW.mint,
        'amount_in', NEW.amount_in,
        'amount_out', NEW.amount_out,
        'payer', NEW.payer
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_orders_activity ON orders;
CREATE TRIGGER trg_orders_activity
AFTER UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION log_order_activity();
