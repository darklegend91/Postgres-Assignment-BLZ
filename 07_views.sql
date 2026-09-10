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
  AND inventory_days    <= 40;


select * from vw_critical_shipments
ORDER BY route_risk DESC