 select * from shipments

-- =========================================================
-- Add column for risk classification
-- =========================================================
ALTER TABLE shipments
ADD COLUMN IF NOT EXISTS risk_classification TEXT DEFAULT 'UNKNOWN';


-- =========================================================
-- FUNCTION — Risk Classification
-- =========================================================
CREATE OR REPLACE FUNCTION fn_classify_risk(
    p_route_risk        NUMERIC,
    p_delay_probability NUMERIC,
    p_current_delay     INTEGER,
    p_inventory_days    INTEGER
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_score INTEGER := 0;
BEGIN
    IF p_route_risk >= 8 THEN v_score := v_score + 3;
    ELSIF p_route_risk >= 6 THEN v_score := v_score + 2;
    ELSIF p_route_risk >= 4 THEN v_score := v_score + 1;
    END IF;

    IF p_delay_probability >= 0.6 THEN v_score := v_score + 3;
    ELSIF p_delay_probability >= 0.4 THEN v_score := v_score + 2;
    ELSIF p_delay_probability >= 0.2 THEN v_score := v_score + 1;
    END IF;

    IF p_current_delay >= 15 THEN v_score := v_score + 3;
    ELSIF p_current_delay >= 8 THEN v_score := v_score + 2;
    ELSIF p_current_delay >= 3 THEN v_score := v_score + 1;
    END IF;

    IF p_inventory_days <= 10 THEN v_score := v_score + 3;
    ELSIF p_inventory_days <= 25 THEN v_score := v_score + 2;
    ELSIF p_inventory_days <= 45 THEN v_score := v_score + 1;
    END IF;

    RETURN CASE
        WHEN v_score >= 9 THEN 'CRITICAL'
        WHEN v_score >= 6 THEN 'HIGH'
        WHEN v_score >= 3 THEN 'MEDIUM'
        ELSE 'LOW'
    END;
END;
$$;

-- Test A:
SELECT
    s.shipment_id,
    sr.route_risk_score,
    sr.delay_probability,
    s.current_delay_days,
    inv.inventory_days,
    fn_classify_risk(sr.route_risk_score, sr.delay_probability,
                     s.current_delay_days, inv.inventory_days) AS risk_class
FROM shipments s
JOIN shipment_risk sr ON s.shipment_id = sr.shipment_id
JOIN inventory inv ON s.supplier_id = inv.supplier_id
                  AND s.product_type = inv.product_type
LIMIT 15;


-- =========================================================
-- B. FUNCTION — Freight Risk Score
-- =========================================================
CREATE OR REPLACE FUNCTION fn_freight_risk_score(
    p_volume     NUMERIC,
    p_fuel_price NUMERIC,
    p_route_risk NUMERIC
)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT ROUND(
        (LEAST(p_volume / 10000.0, 10) * 0.3) +
        (LEAST(p_fuel_price / 10.0, 10) * 0.2) +
        (p_route_risk * 0.5)
    , 2);
$$;

-- Test B:
SELECT
    s.shipment_id,
    s.shipment_volume_tons,
    s.fuel_price_usd,
    sr.route_risk_score,
    fn_freight_risk_score(s.shipment_volume_tons, s.fuel_price_usd, sr.route_risk_score) AS freight_risk_score
FROM shipments s
JOIN shipment_risk sr ON s.shipment_id = sr.shipment_id
LIMIT 15;


-- =========================================================
-- STORED PROCEDURE — Update Risk Classification
-- =========================================================
CREATE OR REPLACE PROCEDURE sp_update_risk_classification(
    IN  p_shipment_id TEXT,
    OUT p_new_class   TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_route_risk      NUMERIC;
    v_delay_prob      NUMERIC;
    v_current_delay   INTEGER;
    v_inventory_days  INTEGER;
    v_old_class       TEXT; -- Added: To remember what the class was BEFORE the update
BEGIN
    -- 1. Fetch the data, including the existing risk classification
    SELECT 
        sr.route_risk_score,
        sr.delay_probability,
        s.current_delay_days,
        inv.inventory_days,
        s.risk_classification
    INTO 
        v_route_risk, 
        v_delay_prob, 
        v_current_delay, 
        v_inventory_days,
        v_old_class
    FROM shipments s
    JOIN shipment_risk sr ON s.shipment_id = sr.shipment_id
    JOIN inventory inv   ON s.supplier_id = inv.supplier_id
                        AND s.product_type = inv.product_type
    WHERE s.shipment_id = p_shipment_id;

    -- 2. Guard clause if shipment doesn't exist
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shipment % not found', p_shipment_id;
    END IF;

    p_new_class := fn_classify_risk(v_route_risk, v_delay_prob, v_current_delay, v_inventory_days);

    IF v_old_class IS DISTINCT FROM p_new_class THEN
        UPDATE shipments
        SET risk_classification = p_new_class
        WHERE shipment_id = p_shipment_id;

        RAISE NOTICE 'Shipment % upgraded: % ➔ %', p_shipment_id, COALESCE(v_old_class, 'None'), p_new_class;
    ELSE
        RAISE NOTICE 'Shipment % unchanged (remains %)', p_shipment_id, p_new_class;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE NOTICE 'Failed to update risk for %: %', p_shipment_id, SQLERRM;
END;
$$;

-- Call the procedure:
CALL sp_update_risk_classification('SHP0001', NULL);
CALL sp_update_risk_classification('SHP0002', NULL);

-- Verify the changes
SELECT shipment_id, risk_classification 
FROM shipments 
WHERE shipment_id IN ('SHP0001','SHP0002');

-- =========================================================
-- TRIGGER — Audit Table
-- =========================================================
CREATE TABLE IF NOT EXISTS shipment_audit (
    audit_id       SERIAL PRIMARY KEY,
    shipment_id    TEXT,
    column_name    TEXT,
    old_value      TEXT,
    new_value      TEXT,
    operation      TEXT,
    changed_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by     TEXT DEFAULT CURRENT_USER
);

CREATE OR REPLACE FUNCTION fn_audit_shipment_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.risk_classification IS DISTINCT FROM NEW.risk_classification THEN
        INSERT INTO shipment_audit (shipment_id, column_name, old_value, new_value, operation)
        VALUES (NEW.shipment_id, 'risk_classification',
                OLD.risk_classification, NEW.risk_classification, TG_OP);
    END IF;

    IF OLD.freight_cost_usd IS DISTINCT FROM NEW.freight_cost_usd THEN
        INSERT INTO shipment_audit (shipment_id, column_name, old_value, new_value, operation)
        VALUES (NEW.shipment_id, 'freight_cost_usd',
                OLD.freight_cost_usd::TEXT, NEW.freight_cost_usd::TEXT, TG_OP);
    END IF;

    IF OLD.current_delay_days IS DISTINCT FROM NEW.current_delay_days THEN
        INSERT INTO shipment_audit (shipment_id, column_name, old_value, new_value, operation)
        VALUES (NEW.shipment_id, 'current_delay_days',
                OLD.current_delay_days::TEXT, NEW.current_delay_days::TEXT, TG_OP);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_shipment_changes ON shipments;
CREATE TRIGGER trg_audit_shipment_changes
AFTER UPDATE ON shipments
FOR EACH ROW
EXECUTE FUNCTION fn_audit_shipment_changes();

-- Test D:
UPDATE shipments SET current_delay_days = 100 WHERE shipment_id = 'SHP0001';
SELECT * FROM shipment_audit ORDER BY changed_at DESC LIMIT 5;


-- =========================================================
-- VALIDATION TRIGGER — Reject invalid data
-- =========================================================
CREATE OR REPLACE FUNCTION fn_validate_shipment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.shipment_volume_tons < 0 THEN
        RAISE EXCEPTION 'Invalid shipment_volume_tons: % (must be >= 0)', NEW.shipment_volume_tons;
    END IF;
    IF NEW.freight_cost_usd < 0 THEN
        RAISE EXCEPTION 'Invalid freight_cost_usd: % (must be >= 0)', NEW.freight_cost_usd;
    END IF;
    IF NEW.revenue_impact_usd < 0 THEN
        RAISE EXCEPTION 'Invalid revenue_impact_usd: % (must be >= 0)', NEW.revenue_impact_usd;
    END IF;
    IF NEW.current_delay_days < 0 THEN
        RAISE EXCEPTION 'Invalid current_delay_days: % (must be >= 0)', NEW.current_delay_days;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_shipment ON shipments;
CREATE TRIGGER trg_validate_shipment
BEFORE INSERT OR UPDATE ON shipments
FOR EACH ROW
EXECUTE FUNCTION fn_validate_shipment();

-- Same for shipment_risk (delay probability 0–1)
CREATE OR REPLACE FUNCTION fn_validate_shipment_risk()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.delay_probability < 0 OR NEW.delay_probability > 1 THEN
        RAISE EXCEPTION 'Invalid delay_probability: % (must be 0–1)', NEW.delay_probability;
    END IF;
    IF NEW.route_risk_score < 0 THEN
        RAISE EXCEPTION 'Invalid route_risk_score: %', NEW.route_risk_score;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_shipment_risk ON shipment_risk;
CREATE TRIGGER trg_validate_shipment_risk
BEFORE INSERT OR UPDATE ON shipment_risk
FOR EACH ROW
EXECUTE FUNCTION fn_validate_shipment_risk();

-- Test E (should FAIL):
UPDATE shipments SET freight_cost_usd = -999 WHERE shipment_id = 'SHP0002';