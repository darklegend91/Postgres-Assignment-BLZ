COPY (
    SELECT
        ship.shipment_id,
        ship.supplier_id,
        sup.country,
        ship.product_type,
        srisk.route_risk_score,
        srisk.delay_probability,
        ship.current_delay_days,
        inv.inventory_days,
        ship.freight_cost_usd,
        ship.revenue_impact_usd,
        ship.risk_classification
    FROM shipments ship
    JOIN suppliers sup       ON ship.supplier_id = sup.supplier_id
    JOIN shipment_risk srisk    ON ship.shipment_id = srisk.shipment_id
    JOIN inventory inv       ON ship.supplier_id = inv.supplier_id
                            AND ship.product_type = inv.product_type
    WHERE srisk.route_risk_score >= 7
      AND srisk.delay_probability >= 0.4
      AND ship.current_delay_days >= 10
      AND inv.inventory_days <= 40
)
TO '/tmp/critical_shipments.csv'
WITH (FORMAT CSV, HEADER true, DELIMITER ',', ENCODING 'UTF8');


COPY (
    SELECT
        ship.shipment_id,
        ship.supplier_id,
        sup.country,
        ship.product_type,
        srisk.route_risk_score,
        srisk.delay_probability,
        ship.current_delay_days,
        inv.inventory_days,
        ship.freight_cost_usd,
        ship.revenue_impact_usd,
        ship.risk_classification
    FROM shipments ship
    JOIN suppliers sup       ON ship.supplier_id = sup.supplier_id
    JOIN shipment_risk srisk    ON ship.shipment_id = srisk.shipment_id
    JOIN inventory inv       ON ship.supplier_id = inv.supplier_id
                            AND ship.product_type = inv.product_type
    WHERE srisk.route_risk_score >= 7
      AND srisk.delay_probability >= 0.4
      AND ship.current_delay_days >= 10
      AND inv.inventory_days <= 40
)
TO '/tmp/critical_shipments.csv'
WITH (FORMAT CSV, HEADER true, DELIMITER ',', ENCODING 'UTF8');


CREATE TABLE critical_shipments_staging (
    shipment_id         TEXT,
    supplier_id         TEXT,
    country             TEXT,
    product_type        TEXT,
    route_risk_score    NUMERIC,
    delay_probability   NUMERIC,
    current_delay_days  INTEGER,
    inventory_days      INTEGER,
    freight_cost_usd    NUMERIC,
    revenue_impact_usd  NUMERIC,
    risk_classification TEXT
);


CREATE TABLE supplier_summary_staging (
    supplier_id           TEXT,
    country               TEXT,
    supplier_reliability  NUMERIC,
    shipment_count        INTEGER,
    total_volume          NUMERIC,
    avg_delay             NUMERIC,
    total_freight_cost    NUMERIC,
    total_revenue_impact  NUMERIC
);
psql -d SupplyChainRiskDB


SELECT 'critical_shipments_staging' AS t, COUNT(*) FROM critical_shipments_staging
UNION ALL
SELECT 'supplier_summary_staging', COUNT(*) FROM supplier_summary_staging;

SELECT table_name, COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('critical_shipments_staging', 'supplier_summary_staging')
GROUP BY table_name;

SELECT table_name, COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('critical_shipments_staging', 'supplier_summary_staging')
GROUP BY table_name;

SELECT 'CRITICAL MATCH' AS check_name,
       (SELECT COUNT(*) FROM vw_critical_shipments) AS source_count,
       (SELECT COUNT(*) FROM critical_shipments_staging) AS staging_count,
       CASE WHEN (SELECT COUNT(*) FROM vw_critical_shipments) =
                 (SELECT COUNT(*) FROM critical_shipments_staging)
            THEN 'PASS' ELSE 'FAIL' END AS result
UNION ALL
SELECT 'SUPPLIER MATCH',
       (SELECT COUNT(*) FROM suppliers),
       (SELECT COUNT(*) FROM supplier_summary_staging),
       CASE WHEN (SELECT COUNT(*) FROM suppliers) =
                 (SELECT COUNT(*) FROM supplier_summary_staging)
            THEN 'PASS' ELSE 'FAIL' END;

-- TO be run in terminal
pg_dump -d SupplyChainRiskDB -F c -f ~/backup_full.dump

pg_dump -d SupplyChainRiskDB --schema-only -f ~/backup_schema.sql

ls -lh ~/backup_*
-- -rw-r--r--@ 1 adityapathania  staff   102K 11 Sep 20:43 /Users/adityapathania/backup_full.dump
-- -rw-r--r--@ 1 adityapathania  staff    26K 11 Sep 20:44 /Users/adityapathania/backup_schema.sql

createdb SupplyChainRiskDB_Restore

pg_restore -d SupplyChainRiskDB_Restore --no-owner --no-privileges ~/backup_full.dump

psql -d SupplyChainRiskDB_Restore <<'EOF'
SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name;
SELECT 'suppliers' AS t, COUNT(*) FROM suppliers UNION ALL SELECT 'products', COUNT(*) FROM products UNION ALL SELECT 'inventory', COUNT(*) FROM inventory UNION ALL SELECT 'shipments', COUNT(*) FROM shipments UNION ALL SELECT 'shipment_risk', COUNT(*) FROM shipment_risk UNION ALL SELECT 'shipment_audit', COUNT(*) FROM shipment_audit;


SELECT table_name FROM information_schema.views WHERE table_schema='public' ORDER BY table_name;
SELECT proname, prokind FROM pg_proc WHERE pronamespace='public'::regnamespace ORDER BY proname;
SELECT tgname, tgrelid::regclass AS table_name FROM pg_trigger WHERE NOT tgisinternal;
SELECT tablename, indexname FROM pg_indexes WHERE schemaname='public' ORDER BY tablename, indexname;
SELECT conname, contype, conrelid::regclass AS table_name FROM pg_constraint WHERE connamespace='public'::regnamespace ORDER BY table_name, conname;
EOF


--Make roles
psql -d SupplyChainRiskDB <<'EOF'
DROP ROLE IF EXISTS supply_chain_admin;
DROP ROLE IF EXISTS supply_chain_analyst;
DROP ROLE IF EXISTS supply_chain_viewer;
CREATE ROLE supply_chain_admin WITH LOGIN PASSWORD 'Admin@123';
CREATE ROLE supply_chain_analyst WITH LOGIN PASSWORD 'Analyst@123';
CREATE ROLE supply_chain_viewer WITH LOGIN PASSWORD 'Viewer@123';


GRANT ALL PRIVILEGES ON DATABASE "SupplyChainRiskDB" TO supply_chain_admin;
GRANT ALL PRIVILEGES ON SCHEMA public TO supply_chain_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO supply_chain_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO supply_chain_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO supply_chain_admin;
GRANT CONNECT ON DATABASE "SupplyChainRiskDB" TO supply_chain_analyst;
GRANT USAGE ON SCHEMA public TO supply_chain_analyst;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO supply_chain_analyst;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO supply_chain_analyst;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO supply_chain_analyst;
GRANT CONNECT ON DATABASE "SupplyChainRiskDB" TO supply_chain_viewer;
GRANT USAGE ON SCHEMA public TO supply_chain_viewer;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO supply_chain_viewer;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO supply_chain_viewer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO supply_chain_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO supply_chain_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO supply_chain_viewer;
GRANT DELETE ON shipments TO supply_chain_analyst;
SELECT grantee, privilege_type FROM information_schema.role_table_grants WHERE table_name='shipments' AND grantee='supply_chain_analyst' ORDER BY privilege_type;
REVOKE DELETE ON shipments FROM supply_chain_analyst;
SELECT grantee, privilege_type FROM information_schema.role_table_grants WHERE table_name='shipments' AND grantee='supply_chain_analyst' ORDER BY privilege_type;
SET ROLE supply_chain_viewer;
SELECT COUNT(*) FROM shipments;
RESET ROLE;
SET ROLE supply_chain_analyst;
SELECT COUNT(*) FROM shipments;
UPDATE shipments SET current_delay_days = 5 WHERE shipment_id='SHP0001';
RESET ROLE;
SET ROLE supply_chain_admin;
SELECT COUNT(*) FROM shipments;
RESET ROLE;


SELECT grantee, table_name, privilege_type FROM information_schema.role_table_grants WHERE grantee IN ('supply_chain_admin','supply_chain_analyst','supply_chain_viewer') ORDER BY grantee, table_name, privilege_type;
SELECT r.rolname AS role_name, COUNT(DISTINCT g.table_name) AS tables_with_access, STRING_AGG(DISTINCT g.privilege_type, ', ' ORDER BY g.privilege_type) AS privileges FROM pg_roles r LEFT JOIN information_schema.role_table_grants g ON g.grantee = r.rolname WHERE r.rolname IN ('supply_chain_admin','supply_chain_analyst','supply_chain_viewer') GROUP BY r.rolname ORDER BY r.rolname;