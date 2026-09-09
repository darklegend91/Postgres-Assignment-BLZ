--Find shipments whose freight cost is above the overall average
SELECT 
    shipment_id,
    supplier_id,
    product_type,
    freight_cost_usd,
    ROUND((SELECT AVG(freight_cost_usd) FROM shipments)::NUMERIC, 2) AS overall_avg_freight
FROM shipments
WHERE freight_cost_usd > (SELECT AVG(freight_cost_usd) FROM shipments)
ORDER BY freight_cost_usd DESC;

--Find shipments whose current delay is above the overall average
SELECT 
    shipment_id,
    supplier_id,
    current_delay_days,
    ROUND((SELECT AVG(current_delay_days) FROM shipments)::NUMERIC, 2) AS overall_avg_delay
FROM shipments
WHERE current_delay_days > (SELECT AVG(current_delay_days) FROM shipments)
ORDER BY current_delay_days DESC;

-- Find suppliers whose reliability is below the overall average
SELECT 
    supplier_id,
    country,
    supplier_reliability,
    ROUND((SELECT AVG(supplier_reliability) FROM suppliers)::NUMERIC, 2) AS overall_avg_reliability
FROM suppliers
WHERE supplier_reliability < (SELECT AVG(supplier_reliability) FROM suppliers)
ORDER BY supplier_reliability ASC;

-- Find countries whose average route risk is above the global average
SELECT 
    sup.country,
    ROUND(AVG(sr.route_risk_score)::NUMERIC, 2) AS country_avg_route_risk,
    ROUND((SELECT AVG(route_risk_score) FROM shipment_risk)::NUMERIC, 2) AS global_avg_route_risk
FROM suppliers sup
JOIN shipments s ON sup.supplier_id = s.supplier_id
JOIN shipment_risk sr ON s.shipment_id = sr.shipment_id
GROUP BY sup.country
HAVING AVG(sr.route_risk_score) > (SELECT AVG(route_risk_score) FROM shipment_risk)
ORDER BY country_avg_route_risk DESC;

-- Find shipments with the maximum revenue impact
SELECT 
    shipment_id,
    supplier_id,
    product_type,
    revenue_impact_usd
FROM shipments
WHERE revenue_impact_usd = (SELECT MAX(revenue_impact_usd) FROM shipments);

-- Find the second-highest freight cost
SELECT 
    shipment_id,
    supplier_id,
    freight_cost_usd
FROM shipments
ORDER BY freight_cost_usd DESC
LIMIT 1 OFFSET 1;

--Find shipments whose revenue impact is higher than their country's average
SELECT 
    s.shipment_id,
    s.supplier_id,
    sup.country,
    s.revenue_impact_usd,
    ROUND(
        (SELECT AVG(s2.revenue_impact_usd) 
         FROM shipments s2 
         JOIN suppliers sup2 ON s2.supplier_id = sup2.supplier_id 
         WHERE sup2.country = sup.country)::NUMERIC, 2
    ) AS country_avg_revenue
FROM shipments s
JOIN suppliers sup ON s.supplier_id = sup.supplier_id
WHERE s.revenue_impact_usd > (
    SELECT AVG(s2.revenue_impact_usd) 
    FROM shipments s2 
    JOIN suppliers sup2 ON s2.supplier_id = sup2.supplier_id 
    WHERE sup2.country = sup.country
)
ORDER BY s.revenue_impact_usd DESC;

-- Find shipments whose freight cost is higher than their product's average
SELECT 
    s.shipment_id,
    s.product_type,
    s.freight_cost_usd,
    ROUND(
        (SELECT AVG(s2.freight_cost_usd) 
         FROM shipments s2 
         WHERE s2.product_type = s.product_type)::NUMERIC, 2
    ) AS product_avg_freight
FROM shipments s
WHERE s.freight_cost_usd > (
    SELECT AVG(s2.freight_cost_usd) 
    FROM shipments s2 
    WHERE s2.product_type = s.product_type
)
ORDER BY s.freight_cost_usd DESC;

-- Find the highest-risk shipment for each country
SELECT 
    sup.country,
    s.shipment_id,
    sr.route_risk_score,
    ROUND(
        (SELECT MAX(sr2.route_risk_score) 
         FROM shipment_risk sr2 
         JOIN shipments s2 ON sr2.shipment_id = s2.shipment_id 
         JOIN suppliers sup2 ON s2.supplier_id = sup2.supplier_id 
         WHERE sup2.country = sup.country)::NUMERIC, 2
    ) AS country_max_risk
FROM shipments s
JOIN suppliers sup ON s.supplier_id = sup.supplier_id
JOIN shipment_risk sr ON s.shipment_id = sr.shipment_id
WHERE sr.route_risk_score = (
    SELECT MAX(sr2.route_risk_score) 
    FROM shipment_risk sr2 
    JOIN shipments s2 ON sr2.shipment_id = s2.shipment_id 
    JOIN suppliers sup2 ON s2.supplier_id = sup2.supplier_id 
    WHERE sup2.country = sup.country
)
ORDER BY sup.country;

-- Find suppliers whose average delay is greater than the overall average delay
SELECT 
    sup.supplier_id,
    sup.country,
    ROUND(AVG(s.current_delay_days)::NUMERIC, 2) AS supplier_avg_delay,
    ROUND((SELECT AVG(current_delay_days) FROM shipments)::NUMERIC, 2) AS overall_avg_delay
FROM suppliers sup
JOIN shipments s ON sup.supplier_id = s.supplier_id
GROUP BY sup.supplier_id, sup.country
HAVING AVG(s.current_delay_days) > (SELECT AVG(current_delay_days) FROM shipments)
ORDER BY supplier_avg_delay DESC;

--Using CAST() to convert to different data types
SELECT 
    shipment_id,
    freight_cost_usd,
    CAST(freight_cost_usd AS INTEGER) AS freight_cost_int
FROM shipments
LIMIT 10;

-- Convert delay probability to percentage with 2 decimal places
SELECT 
    shipment_id,
    delay_probability,
    CAST(delay_probability * 100 AS DECIMAL(5,2)) AS delay_percentage
FROM shipment_risk
LIMIT 10;

-- Using :: syntax (PostgreSQL shorthand)

-- Convert route risk to integer
SELECT 
    shipment_id,
    route_risk_score,
    route_risk_score::INTEGER AS route_risk_int
FROM shipment_risk
LIMIT 10;

-- Calculate disruption percentage with precision
SELECT 
    COUNT(*) AS total_shipments,
    SUM(CASE WHEN disruption_event = '1' THEN 1 ELSE 0 END) AS disrupted,
    ROUND(
        (SUM(CASE WHEN disruption_event = '1' THEN 1 ELSE 0 END)::DECIMAL / COUNT(*) * 100)::DECIMAL(5,2), 
        2
    ) AS disruption_percentage
FROM shipments;

-- Convert revenue impact to millions (integer)
SELECT 
    shipment_id,
    revenue_impact_usd,
    (revenue_impact_usd / 1000000)::INTEGER AS revenue_millions,
    CAST(revenue_impact_usd / 1000000 AS DECIMAL(10,2)) AS revenue_millions_precise
FROM shipments
LIMIT 10;

-- Format route risk as percentage with 1 decimal
SELECT 
    shipment_id,
    route_risk_score,
    CAST(route_risk_score * 10 AS DECIMAL(4,1)) AS risk_percentage
FROM shipment_risk
LIMIT 10;

-- Combine CAST with CASE for risk categorization
SELECT 
    shipment_id,
    route_risk_score,
    CASE 
        WHEN CAST(route_risk_score AS INTEGER) >= 8 THEN 'HIGH RISK'
        WHEN CAST(route_risk_score AS INTEGER) >= 5 THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END AS risk_category
FROM shipment_risk
LIMIT 10;

-- Calculate supplier reliability as percentage
SELECT 
    supplier_id,
    supplier_reliability,
    CAST(supplier_reliability * 100 AS DECIMAL(4,1)) AS reliability_percent,
    CASE 
        WHEN supplier_reliability >= 0.8 THEN 'High'
        WHEN supplier_reliability >= 0.6 THEN 'Medium'
        ELSE 'Low'
    END AS reliability_tier
FROM suppliers
ORDER BY supplier_reliability DESC
LIMIT 10;

-- Complex query with multiple CASTs
SELECT 
    s.shipment_id,
    sup.country,
    p.product_type,
    s.freight_cost_usd,
    CAST(s.freight_cost_usd / 1000 AS DECIMAL(8,2)) AS freight_cost_thousands,
    sr.delay_probability::DECIMAL(3,2) AS delay_probability,
    CAST(sr.delay_probability * 100 AS INTEGER) AS delay_percent_int,
    CASE 
        WHEN CAST(sr.delay_probability * 100 AS INTEGER) > 50 THEN 'High Delay Risk'
        WHEN CAST(sr.delay_probability * 100 AS INTEGER) > 25 THEN 'Medium Delay Risk'
        ELSE 'Low Delay Risk'
    END AS delay_risk_label
FROM shipments s
JOIN suppliers sup ON s.supplier_id = sup.supplier_id
JOIN products p ON s.product_type = p.product_type
JOIN shipment_risk sr ON s.shipment_id = sr.shipment_id
LIMIT 20;

--Count of shipments above average freight cost
SELECT 
    COUNT(*) AS shipments_above_avg_freight
FROM shipments
WHERE freight_cost_usd > (SELECT AVG(freight_cost_usd) FROM shipments);

-- Count of shipments above average delay
SELECT 
    COUNT(*) AS shipments_above_avg_delay
FROM shipments
WHERE current_delay_days > (SELECT AVG(current_delay_days) FROM shipments);

--List all suppliers with their performance category
SELECT 
    supplier_id,
    country,
    supplier_reliability,
    CASE 
        WHEN supplier_reliability >= 0.9 THEN 'Excellent'
        WHEN supplier_reliability >= 0.75 THEN 'Good'
        WHEN supplier_reliability >= 0.6 THEN 'Average'
        ELSE 'Poor'
    END AS reliability_rating
FROM suppliers
ORDER BY supplier_reliability DESC;