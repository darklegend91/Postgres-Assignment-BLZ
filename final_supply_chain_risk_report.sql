-- Top 20 Critical Shipments — Highest Risk → Lowest Risk

SELECT
    v.shipment_id                    AS "Shipment ID",
    v.supplier                       AS "Supplier",
    v.country                        AS "Country",
    v.product                        AS "Product",
    s.shipment_volume_tons           AS "Shipment Volume",
    v.route_risk                     AS "Route Risk",
    v.political_risk                 AS "Political Risk",
    v.port_congestion                AS "Port Congestion",
    sup.supplier_reliability         AS "Supplier Reliability",
    v.inventory_days                 AS "Inventory Days",
    s.transit_time_days              AS "Transit Time",
    v.delay_probability              AS "Delay Probability",
    v.current_delay                  AS "Current Delay",
    s.freight_cost_usd               AS "Freight Cost",
    s.revenue_impact_usd             AS "Revenue Impact",

    fn_classify_risk(
        v.route_risk,
        v.delay_probability,
        v.current_delay,
        v.inventory_days
    )                                AS "Risk Classification",

    ROUND(
        (
            (v.route_risk / 10) * 20
            + (v.political_risk / 10) * 15
            + (v.port_congestion / 10) * 15
            + (v.delay_probability * 20)
            + (LEAST(v.current_delay / 30.0, 1) * 10)
            + (GREATEST(1 - sup.supplier_reliability, 0) * 10)
            + (GREATEST(1 - v.inventory_days / 30.0, 0) * 5)
        ),
        2
    )                                AS "Supply Chain Risk Score",

    CASE
        WHEN v.route_risk >= 9
             AND v.delay_probability >= 0.8
             AND v.current_delay >= 10
        THEN 'Critical'

        WHEN v.route_risk >= 8
             AND v.delay_probability >= 0.75
        THEN 'High'

        WHEN v.route_risk >= 7
        THEN 'Medium'

        ELSE 'Low'
    END                              AS "Final Risk Level",

    (
        SELECT ROUND(AVG(s2.freight_cost_usd)::NUMERIC, 2)
        FROM shipments s2
    )                                AS "Average Freight Cost"

FROM vw_shipment_risk v

INNER JOIN shipments s
    ON v.shipment_id = s.shipment_id

INNER JOIN suppliers sup
    ON v.supplier = sup.supplier_id

WHERE v.shipment_id IN (
    SELECT shipment_id FROM vw_critical_shipments
)

ORDER BY "Supply Chain Risk Score" DESC

LIMIT 20;