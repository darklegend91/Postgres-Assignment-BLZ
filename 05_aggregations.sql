-- Which supplier has the highest shipment volume?
SELECT 
    s.supplier_id,
    SUM(s.shipment_volume_tons) AS total_shipment_volume
FROM shipments s
GROUP BY s.supplier_id
ORDER BY total_shipment_volume DESC
LIMIT 1;

--Which supplier has the highest revenue impact?
SELECT 
    s.supplier_id,
    SUM(s.revenue_impact_usd) AS total_revenue_impact
FROM shipments s
GROUP BY s.supplier_id
ORDER BY total_revenue_impact DESC
LIMIT 1;

-- Which supplier has the highest average delay?
SELECT 
    s.supplier_id,
    AVG(s.current_delay_days) AS avg_delay
FROM shipments s
GROUP BY s.supplier_id
ORDER BY avg_delay DESC
LIMIT 1;

-- Which suppliers have below-average reliability?
SELECT 
    sup.supplier_id,
    sup.country,
    sup.supplier_reliability,
    (SELECT AVG(supplier_reliability) FROM suppliers) AS overall_avg_reliability
FROM suppliers sup
WHERE sup.supplier_reliability < (SELECT AVG(supplier_reliability) FROM suppliers)
ORDER BY sup.supplier_reliability ASC;

-- Which suppliers have more than 5 shipments?
SELECT 
    s.supplier_id,
    COUNT(s.shipment_id) AS shipment_count
FROM shipments s
GROUP BY s.supplier_id
HAVING COUNT(s.shipment_id) > 5
ORDER BY shipment_count DESC;

--Which country has the highest average route risk?
SELECT 
    sup.country,
    AVG(sr.route_risk_score) AS avg_route_risk
FROM suppliers sup
JOIN shipments s ON sup.supplier_id = s.supplier_id
JOIN shipment_risk sr ON s.shipment_id = sr.shipment_id
GROUP BY sup.country
ORDER BY avg_route_risk DESC
LIMIT 1;

--Which country has the highest political risk?
SELECT 
    country,
    AVG(political_risk_index) AS avg_political_risk
FROM suppliers
GROUP BY country
ORDER BY avg_political_risk DESC
LIMIT 1;

-- Which country has the highest total revenue impact?
SELECT 
    sup.country,
    SUM(s.revenue_impact_usd) AS total_revenue_impact
FROM suppliers sup
JOIN shipments s ON sup.supplier_id = s.supplier_id
GROUP BY sup.country
ORDER BY total_revenue_impact DESC
LIMIT 1;

-- What is the average delay by country?
SELECT 
    sup.country,
    AVG(s.current_delay_days) AS avg_delay_days
FROM suppliers sup
JOIN shipments s ON sup.supplier_id = s.supplier_id
GROUP BY sup.country
ORDER BY avg_delay_days DESC;

--Which product has the highest demand?
SELECT 
    product_type,
    monthly_demand_tons AS demand
FROM products
ORDER BY monthly_demand_tons DESC
LIMIT 1;

-- Which product has the highest freight cost?
SELECT 
    p.product_type,
    AVG(s.freight_cost_usd) AS avg_freight_cost
FROM products p
JOIN shipments s ON p.product_type = s.product_type
GROUP BY p.product_type
ORDER BY avg_freight_cost DESC
LIMIT 1;

-- Which product has experienced the highest number of disruptions?
SELECT 
    p.product_type,
    SUM(CASE WHEN s.disruption_event = '1' THEN 1 ELSE 0 END) AS disruption_count,
    COUNT(s.shipment_id) AS total_shipments,
    ROUND(
        (SUM(CASE WHEN s.disruption_event = '1' THEN 1 ELSE 0 END) * 100.0) / COUNT(s.shipment_id), 
        2
    ) AS disruption_percentage
FROM products p
JOIN shipments s ON p.product_type = s.product_type
GROUP BY p.product_type
ORDER BY disruption_count DESC
LIMIT 1;

--What percentage of shipments experienced disruption?
SELECT 
    COUNT(*) AS total_shipments,
    SUM(CASE WHEN disruption_event = '1' THEN 1 ELSE 0 END) AS disrupted_shipments,
    ROUND(
        (SUM(CASE WHEN disruption_event = '1' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 
        2
    ) AS disruption_percentage
FROM shipments;

-- What is the total revenue impact?
SELECT 
    SUM(revenue_impact_usd) AS total_revenue_impact
FROM shipments;

-- What is the average shipment delay?
SELECT 
    AVG(current_delay_days) AS avg_delay_days,
    MIN(current_delay_days) AS min_delay_days,
    MAX(current_delay_days) AS max_delay_days
FROM shipments;


-- One query to see all supplier metrics in one view
SELECT 
    sup.supplier_id,
    sup.country,
    sup.supplier_reliability,
    COUNT(s.shipment_id) AS shipment_count,
    SUM(s.shipment_volume_tons) AS total_volume,
    AVG(s.current_delay_days) AS avg_delay,
    SUM(s.revenue_impact_usd) AS total_revenue_impact,
    ROUND(
        (SUM(CASE WHEN s.disruption_event = '1' THEN 1 ELSE 0 END) * 100.0) / COUNT(s.shipment_id), 
        2
    ) AS disruption_percentage,
    CASE 
        WHEN COUNT(s.shipment_id) >= 20 THEN 'High Volume'
        WHEN COUNT(s.shipment_id) >= 10 THEN 'Medium Volume'
        ELSE 'Low Volume'
    END AS volume_category
FROM suppliers sup
JOIN shipments s ON sup.supplier_id = s.supplier_id
GROUP BY sup.supplier_id, sup.country, sup.supplier_reliability
ORDER BY total_revenue_impact DESC;