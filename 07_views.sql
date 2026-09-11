-- Create view  vw_supplier_performance 
CREATE View vw_supplier_performance AS 
SELECT
	s1.supplier_id as Supplier,
	s1.country as Country,
	count(s2.supplier_id) as Shipment_count,
	CAST(avg(s2.current_delay_days) AS Decimal(10,2)) as Average_delay,
	sum(s2.freight_cost_usd) as Total_frienght_cost,
	sum(s2.revenue_impact_usd) as total_revenue_impact,
	sum(s2.shipment_volume_tons) as total_Shipement_volume,
	s1.supplier_reliability as Average_Reliability
FROM
	suppliers s1
	Left Join shipments s2 on s1.supplier_id = s2.supplier_id
GROUP BY
s1.supplier_id
ORDER BY
s1.supplier_id

-- Create view vw_shipment_risk
CREATE OR REPLACE VIEW vw_shipment_risk AS
SELECT
    s.shipment_id            AS shipment_id,
    s.supplier_id            AS supplier,
    sup.country              AS country,
    s.product_type           AS product,
    sr.route_risk_score      AS route_risk,
    sup.political_risk_index AS political_risk,
    sup.port_congestion_index AS port_congestion,
    sr.delay_probability     AS delay_probability,
    s.current_delay_days     AS current_delay,
    inv.inventory_days       AS inventory_days
FROM shipments s
JOIN suppliers sup     ON s.supplier_id  = sup.supplier_id
JOIN shipment_risk sr  ON s.shipment_id  = sr.shipment_id
JOIN inventory inv     ON s.supplier_id  = inv.supplier_id
AND s.product_type = inv.product_type;

select * from vw_shipment_risk 
order by route_risk

CREATE VIEW vw_critical_shipments AS
SELECT
    shipment_id,
    supplier,
    country,
    product,
    route_risk,
    political_risk,
    port_congestion,
    delay_probability,
    current_delay,
    inventory_days
FROM vw_shipment_risk
WHERE route_risk        >= 7
  AND delay_probability >= 0.4
  AND current_delay     >= 10
  AND inventory_days    <= 30;

select * from vw_critical_shipments
ORDER BY route_risk DESC


-- 1 Supplier cladssification on base of reliability with comaprision of the delay and reliability
SELECT
    supplier,
    country,
    shipment_count,
    average_reliability,
    average_delay,
    total_revenue_impact,
    CASE
        WHEN average_reliability >= 0.85 AND average_delay <= 11 THEN 'Preferred'
        WHEN average_reliability >= 0.70 AND average_delay <= 13 THEN 'Approved'
        WHEN average_reliability < 0.60  OR  average_delay > 15 THEN 'Probation'
        ELSE 'Standard'
    END AS supplier_Class,
    RANK() OVER (ORDER BY total_revenue_impact DESC) AS revenue_rank
FROM vw_supplier_performance
ORDER BY supplier_tier, revenue_rank;

--2 Country classification using plitical risk score
SELECT
    country,
    COUNT(*) AS shipments,
    ROUND(AVG(route_risk)::NUMERIC, 2) AS avg_route_risk,
    ROUND(AVG(political_risk)::NUMERIC, 2) AS avg_political_risk,
    ROUND(AVG(port_congestion)::NUMERIC, 2) AS avg_port_congestion,
    ROUND((COUNT(*) * AVG(political_risk))::NUMERIC, 2) AS exposure_score,
    CASE
        WHEN AVG(political_risk) >= 6 AND COUNT(*) > 50 THEN 'High Risk / High Exposure'
        WHEN AVG(political_risk) >= 6 THEN 'High Risk / Low Exposure'
        WHEN COUNT(*) > 50 THEN 'Low Risk / High Exposure'
        ELSE 'Low Risk / Low Exposure'
    END AS risk_category
FROM vw_shipment_risk
GROUP BY country
ORDER BY exposure_score DESC;

--3 Inventory management for supplier on basis of current inventory and past delay record
SELECT
    shipment_id,
    supplier,
    country,
    product,
    route_risk,
    delay_probability,
    current_delay,
    inventory_days,
    GREATEST(inventory_days - current_delay, 0) AS days_remaining,
    ROUND((inventory_days / 30.0)::NUMERIC, 2) AS months_of_buffer,
    CASE
        WHEN GREATEST(inventory_days - current_delay, 0) = 0 THEN 'STOCKED OUT'
        WHEN GREATEST(inventory_days - current_delay, 0) <= 10 THEN 'CRITICAL — Reorder NOW'
        WHEN GREATEST(inventory_days - current_delay, 0) <= 25 THEN 'WARNING — Reorder this week'
        WHEN GREATEST(inventory_days - current_delay, 0) <= 45 THEN 'MONITOR'
        ELSE 'SAFE'
    END AS action_flag
FROM vw_critical_shipments
ORDER BY days_remaining ASC, route_risk DESC;

-- 4 Supplier profile on basis of reliability and risk
SELECT
    sp.supplier,
    sp.country,
    sp.total_revenue_impact,
    sp.average_reliability,
    ROUND(AVG(vr.route_risk)::NUMERIC, 2) AS avg_route_risk,
    ROUND(AVG(vr.delay_probability)::NUMERIC, 3) AS avg_delay_prob,
    ROUND(AVG(vr.current_delay)::NUMERIC, 2) AS avg_delay_days,
    ROUND(AVG(vr.inventory_days)::NUMERIC, 1) AS avg_inventory_days,
    CASE
        WHEN sp.total_revenue_impact > 10000000 AND AVG(vr.route_risk) >= 6 
            THEN 'High Value / High Risk'
        WHEN sp.total_revenue_impact > 10000000 
            THEN 'High Value / Low Risk'
        WHEN AVG(vr.route_risk) >= 6 
            THEN 'Low Value / High Risk'
        ELSE ' Standard'
    END AS strategic_position
FROM vw_supplier_performance sp
JOIN vw_shipment_risk vr ON sp.supplier = vr.supplier
GROUP BY sp.supplier, sp.country, sp.total_revenue_impact, sp.average_reliability
ORDER BY sp.total_revenue_impact DESC;


--5 Prodcut impact and its route risk classification
WITH product_summary AS (
    SELECT
        vr.product,
        COUNT(*)                       AS shipment_count,
        SUM(s.revenue_impact_usd)      AS total_revenue,
        AVG(vr.route_risk)             AS avg_risk,
        AVG(vr.delay_probability)      AS avg_delay_prob
    FROM vw_shipment_risk vr
    JOIN shipments s ON vr.shipment_id = s.shipment_id
    GROUP BY vr.product
)
SELECT
    product,
    shipment_count,
    ROUND(total_revenue::NUMERIC, 2)  AS total_revenue_impact,
    ROUND(avg_risk::NUMERIC, 2)       AS avg_route_risk,
    ROUND(avg_delay_prob::NUMERIC, 3) AS avg_delay_prob,
    ROUND((SELECT AVG(total_revenue) FROM product_summary)::NUMERIC, 2) AS threshold_revenue,
    ROUND((SELECT AVG(avg_risk) FROM product_summary)::NUMERIC, 2)      AS threshold_risk,
    CASE
        WHEN total_revenue >= (SELECT AVG(total_revenue) FROM product_summary)
         AND avg_risk      >= (SELECT AVG(avg_risk) FROM product_summary)
            THEN 'Strategic Risk'
        WHEN total_revenue >= (SELECT AVG(total_revenue) FROM product_summary)
            THEN 'Strategic Asset'
        WHEN avg_risk      >= (SELECT AVG(avg_risk) FROM product_summary)
            THEN 'Watch'
        ELSE 'Stable'
    END AS product_classification
FROM product_summary
ORDER BY total_revenue DESC;

-- 6 The shippments that are worse than the average country delay
SELECT
    s.shipment_id,
    sup.country,
    s.supplier_id,
    s.current_delay_days,
    ROUND((
        SELECT AVG(s2.current_delay_days)
        FROM shipments s2
        JOIN suppliers sup2 ON s2.supplier_id = sup2.supplier_id
        WHERE sup2.country = sup.country
    )::NUMERIC, 2) AS country_avg_delay,
    s.current_delay_days - (
        SELECT AVG(s2.current_delay_days)
        FROM shipments s2
        JOIN suppliers sup2 ON s2.supplier_id = sup2.supplier_id
        WHERE sup2.country = sup.country
    ) AS delay_gap
FROM shipments s
JOIN suppliers sup ON s.supplier_id = sup.supplier_id
WHERE s.current_delay_days > (
    SELECT AVG(s2.current_delay_days)
    FROM shipments s2
    JOIN suppliers sup2 ON s2.supplier_id = sup2.supplier_id
    WHERE sup2.country = sup.country
)
ORDER BY delay_gap DESC;

--7 Shippers daly as compared to the world deplay
SELECT
    s.supplier_id,
    sup.country,
    sup.supplier_reliability,
    COUNT(s.shipment_id) AS shipment_count,
    ROUND(AVG(s.current_delay_days)::NUMERIC, 2) AS supplier_avg_delay,
    ROUND((SELECT AVG(current_delay_days) FROM shipments)::NUMERIC, 2) AS global_avg_delay,
    ROUND((AVG(s.current_delay_days) - (SELECT AVG(current_delay_days) FROM shipments))::NUMERIC, 2) 
        AS gap_vs_global,
    CASE
        WHEN AVG(s.current_delay_days) > (SELECT AVG(current_delay_days) FROM shipments) * 1.25 
            THEN 'Severely Underperforming'
        WHEN AVG(s.current_delay_days) > (SELECT AVG(current_delay_days) FROM shipments)
            THEN 'Below Average'
        ELSE 'At or Above Average'
    END AS performance_flag
FROM shipments s
JOIN suppliers sup ON s.supplier_id = sup.supplier_id
GROUP BY s.supplier_id, sup.country, sup.supplier_reliability
HAVING AVG(s.current_delay_days) > (SELECT AVG(current_delay_days) FROM shipments)
ORDER BY gap_vs_global DESC;

-- display critical shipments

select *
from supply_chain.vw_critical_shipments;


-- 1. Which suppliers have the highest total shipment volume?

select supplier,country total_shipment_volume
from supply_chain.vw_supplier_performance
order by total_shipment_volume desc
limit 5;


-- 2. Which suppliers have below-average reliability?

select supplier, average_reliability,country
from supply_chain.vw_supplier_performance
where average_reliability < (
    select avg(average_reliability)
    from supply_chain.vw_supplier_performance
)
order by average_reliability;


-- 3. Which shipments have high route risk and high delay probability?

select shipment_id, supplier, country, product, route_risk, delay_probability
from supply_chain.vw_shipment_risk
where route_risk >= 7
and delay_probability >= 0.7
order by route_risk desc, delay_probability desc;


-- 4. Which shipments have low inventory coverage and significant current delay?

select shipment_id, supplier, country, product, current_delay, inventory_days
from supply_chain.vw_shipment_risk
where current_delay >= 10
and inventory_days < 15
order by current_delay desc, inventory_days;


-- 5. Which shipments are classified as critical?

select shipment_id, supplier, country, product,
       route_risk, delay_probability, current_delay, inventory_days
from supply_chain.vw_critical_shipments
order by route_risk desc, delay_probability desc;


-- 6. Which country has the highest average route risk? (without using views)

select s.country, round(avg(r.route_risk_score),2) as average_route_risk
from supply_chain.shipments s
join supply_chain.shipment_risk r
on s.shipment_id = r.shipment_id
group by s.country
order by average_route_risk desc
limit 1;