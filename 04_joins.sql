-- Business Queries

-- Write queries to generate:

-- Supplier Shipment Report

-- Supplier ID
-- Country
-- Shipment Count
-- Shipment Volume
-- Average Delay
-- Supplier Reliability
-- Total Freight Cost
-- Revenue Impact


----------------------------------------------|
--| This is for joins implementation in task  |
----------------------------------------------|

SELECT 
    s2.supplier_id,
	s2.country,
    s2.supplier_reliability,
	SUM(s1.revenue_impact_usd) AS Revenue_Impact,
    COUNT(*) AS shipment_count,
    SUM(s1.freight_cost_usd) AS avg_freight_cost,
    SUM(s1.shipment_volume_tons) AS Total_shipment_volume,
    AVG(s1.historical_delay_days) AS avg_delay
FROM shipments s1
JOIN suppliers s2 ON s1.supplier_id = s2.supplier_id
GROUP BY s2.supplier_id, s2.supplier_reliability, s2.country;

-- Product Performance Report
-- Product
-- Shipment Count
-- Total Demand
-- Total Shipment Volume
-- Average Freight Cost
-- Average Delay
-- Disruption Count

SELECT
    p.product_type,
    COUNT(s.shipment_id) AS shipment_count,
    p.monthly_demand_tons AS total_demand,
    SUM(s.shipment_volume_tons) AS total_shipment_volume,
    AVG(s.freight_cost_usd) AS average_freight_cost,
    AVG(s.current_delay_days) AS average_delay_days,
    SUM(s.disruption_event::INTEGER) AS disruption_count
FROM products p
RIGHT JOIN shipments s ON p.product_type = s.product_type
GROUP BY p.product_type;

-- Critical Shipment Report
-- Combine supplier, product, shipment, risk and inventory information.
-- The final result should include:
-- Shipment ID
-- Supplier
-- Country
-- Product
-- Shipment Volume
-- Route Risk
-- Political Risk
-- Port Congestion
-- Delay Probability
-- Current Delay
-- Inventory Days
-- Freight Cost
-- Revenue Impact

SELECT
    s.shipment_id,
    s.supplier_id AS supplier,
    sup.country,
    s.product_type AS product,
    s.shipment_volume_tons AS shipment_volume,
    sr.route_risk_score AS route_risk,
    sup.political_risk_index AS political_risk,
    sup.port_congestion_index AS port_congestion,
    sr.delay_probability AS delay_probability,
    s.current_delay_days AS current_delay,
    inv.inventory_days AS inventory_days,
    s.freight_cost_usd AS freight_cost,
    s.revenue_impact_usd AS revenue_impact
FROM shipments s
JOIN suppliers sup ON s.supplier_id = sup.supplier_id
JOIN inventory inv ON s.supplier_id = inv.supplier_id AND s.product_type = inv.product_type
JOIN shipment_risk sr ON s.shipment_id = sr.shipment_id
ORDER BY s.shipment_id;