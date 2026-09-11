-- Find all index in the schema
SELECT 
indexname , tablename
from pg_indexes where schemaname='public'

-- Refresh the database
VACUUM ANALYSE

-- ---------- COMPARISON TABLE ----------
CREATE TABLE public.index_comparison(
    query_name      VARCHAR(50),
    indexed_column  VARCHAR(50),
    before_time     NUMERIC(10,3),
    after_time      NUMERIC(10,3),
    improvement_x   NUMERIC(10,2),
    improved        VARCHAR(10)
);

-- ---------- FUNCTION to measure a query's runtime ----------
CREATE OR REPLACE FUNCTION fn_time_query(p_sql TEXT)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_start TIMESTAMP;
    v_end   TIMESTAMP;
BEGIN
    v_start := clock_timestamp();
    EXECUTE p_sql;
    v_end := clock_timestamp();
    RETURN ROUND(EXTRACT(MILLISECONDS FROM (v_end - v_start))::NUMERIC, 3);
END;
$$;

-- =========================================================
-- STEP 1: MEASURE BEFORE (WITHOUT indexes)
-- =========================================================

INSERT INTO public.index_comparison (query_name, indexed_column, before_time)
SELECT 'Q1 Supplier Filtering', 'supplier_id',
       fn_time_query($$ SELECT * FROM shipments WHERE supplier_id = 'SUP019' $$)
UNION ALL
SELECT 'Q2 Country Filtering', 'country',
       fn_time_query($$ SELECT s.*, sup.country FROM shipments s JOIN suppliers sup ON s.supplier_id = sup.supplier_id WHERE sup.country = 'India' $$)
UNION ALL
SELECT 'Q3 High Route Risk', 'route_risk_score',
       fn_time_query($$ SELECT shipment_id, route_risk_score FROM shipment_risk WHERE route_risk_score >= 8 ORDER BY route_risk_score DESC $$)
UNION ALL
SELECT 'Q4 High Delay Probability', 'delay_probability',
       fn_time_query($$ SELECT shipment_id, delay_probability FROM shipment_risk WHERE delay_probability >= 0.70 ORDER BY delay_probability DESC $$)
UNION ALL
SELECT 'Q5 Disruption Filtering', 'disruption_event',
       fn_time_query($$ SELECT * FROM shipments WHERE disruption_event = '1' $$);

-- ========================================================
-- CREATE INDEXES
-- ========================================================
CREATE INDEX idx_shipments_supplier      ON shipments(supplier_id);
CREATE INDEX idx_suppliers_country       ON suppliers(country);
CREATE INDEX idx_risk_route              ON shipment_risk(route_risk_score);
CREATE INDEX idx_risk_delay_probability  ON shipment_risk(delay_probability);
CREATE INDEX idx_shipments_disruption    ON shipments(disruption_event);

ANALYZE shipments;
ANALYZE suppliers;
ANALYZE shipment_risk;

-- =========================================================
-- MEASURE AFTER (WITH indexes)
-- =========================================================
UPDATE public.index_comparison
SET after_time = CASE query_name
    WHEN 'Q1 Supplier Filtering'     THEN fn_time_query($$ SELECT * FROM shipments WHERE supplier_id = 'SUP019' $$)
    WHEN 'Q2 Country Filtering'      THEN fn_time_query($$ SELECT s.*, sup.country FROM shipments s JOIN suppliers sup ON s.supplier_id = sup.supplier_id WHERE sup.country = 'India' $$)
    WHEN 'Q3 High Route Risk'        THEN fn_time_query($$ SELECT shipment_id, route_risk_score FROM shipment_risk WHERE route_risk_score >= 8 ORDER BY route_risk_score DESC $$)
    WHEN 'Q4 High Delay Probability' THEN fn_time_query($$ SELECT shipment_id, delay_probability FROM shipment_risk WHERE delay_probability >= 0.70 ORDER BY delay_probability DESC $$)
    WHEN 'Q5 Disruption Filtering'   THEN fn_time_query($$ SELECT * FROM shipments WHERE disruption_event = '1' $$)
END;

-- =========================================================
-- IMPROVEMENT
-- =========================================================
UPDATE public.index_comparison
SET improvement_x = ROUND(before_time / NULLIF(after_time, 0), 2),
    improved = CASE WHEN after_time < before_time THEN 'YES' ELSE 'NO' END;

-- =========================================================
-- FINAL OUTPUT
-- =========================================================
SELECT * FROM public.index_comparison ORDER BY query_name;
"query_name"	"indexed_column"	"before_time"	"after_time"	"improvement_x"	"improved"
"Q1 Supplier Filtering"	"supplier_id"	1.476	0.177	8.34	"YES"
"Q2 Country Filtering"	"country"	0.861	0.279	3.09	"YES"
"Q3 High Route Risk"	"route_risk_score"	0.581	0.166	3.50	"YES"
"Q4 High Delay Probability"	"delay_probability"	0.288	0.065	4.43	"YES"
"Q5 Disruption Filtering"	"disruption_event"	0.365	0.104	3.51	"YES"


SELECT
    relname,
    indexrelname,
    idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
-- -- Step 5: Verify index usage and find each time how much these index were used
SELECT
    relname,
    indexrelname,
    idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;


SELECT
    relname,
    indexrelname,
    idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;