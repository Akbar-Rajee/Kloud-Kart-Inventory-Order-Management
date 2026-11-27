-- ============================================================
-- Kloud Kart: Customer spending report
--
-- Lifetime measures:
--   total_spent, order_count and spending_rank use ALL eligible
--   orders dated on or before today.
--
-- Rolling-period measures:
--   trailing_12_month_spend uses the exact rolling 12-month
--   interval [CURRENT_DATE - 12 months, CURRENT_DATE + 1 day).
--   The monthly grid deliberately contains 13 calendar-month
--   labels because an exact rolling 12-month interval can touch
--   13 calendar months (partial first and current months).
--   Monthly amounts and running_total cover only that interval.
--
-- Project reporting policy:
--   completed, complete and shipped are eligible statuses.
--   All other statuses are excluded for reproducible project results.
--   Production use requires business-owner approval of this policy.
--
-- Ranking:
--   Lifetime spend, descending; customer_id ascending breaks ties.
--   ROW_NUMBER guarantees exactly 100 top-ranked customers when
--   at least 100 customers exist.
-- ============================================================

CREATE OR REPLACE VIEW customer_spending_report AS

WITH eligible_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        o.total_amount
    FROM orders AS o
    WHERE LOWER(TRIM(o.status)) IN ('completed', 'complete', 'shipped')
      AND o.order_date < CURRENT_DATE + INTERVAL '1 day'
),

lifetime_totals AS (
    SELECT
        customer_id,
        COALESCE(SUM(total_amount), 0)::numeric AS total_spent,
        COUNT(*)::bigint AS order_count
    FROM eligible_orders
    GROUP BY customer_id
),

rolling_monthly_spend AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', order_date)::date AS spend_month,
        SUM(total_amount)::numeric AS monthly_spend
    FROM eligible_orders
    WHERE order_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY customer_id, DATE_TRUNC('month', order_date)::date
),

rolling_totals AS (
    SELECT
        customer_id,
        COALESCE(SUM(total_amount), 0)::numeric
            AS trailing_12_month_spend
    FROM eligible_orders
    WHERE order_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY customer_id
),

report_months AS (
    SELECT GENERATE_SERIES(
        DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months'),
        DATE_TRUNC('month', CURRENT_DATE),
        INTERVAL '1 month'
    )::date AS spend_month
),

ranked_customers AS (
    SELECT
        c.customer_id,
        c.full_name,
        COALESCE(lt.total_spent, 0)::numeric AS total_spent,
        COALESCE(lt.order_count, 0)::bigint AS order_count,
        COALESCE(rt.trailing_12_month_spend, 0)::numeric
            AS trailing_12_month_spend,
        ROW_NUMBER() OVER (
            ORDER BY COALESCE(lt.total_spent, 0) DESC, c.customer_id ASC
        ) AS spending_rank
    FROM customers AS c
    LEFT JOIN lifetime_totals AS lt
        ON lt.customer_id = c.customer_id
    LEFT JOIN rolling_totals AS rt
        ON rt.customer_id = c.customer_id
),

customer_month_grid AS (
    SELECT
        rc.customer_id,
        rc.full_name,
        rc.total_spent,
        rc.order_count,
        rc.trailing_12_month_spend,
        rc.spending_rank,
        rm.spend_month,
        COALESCE(ms.monthly_spend, 0)::numeric AS monthly_spend
    FROM ranked_customers AS rc
    CROSS JOIN report_months AS rm
    LEFT JOIN rolling_monthly_spend AS ms
        ON ms.customer_id = rc.customer_id
       AND ms.spend_month = rm.spend_month
),

final_report AS (
    SELECT
        *,
        SUM(monthly_spend) OVER (
            PARTITION BY customer_id
            ORDER BY spend_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )::numeric AS running_total
    FROM customer_month_grid
)

SELECT
    customer_id,
    full_name,
    total_spent,
    order_count,
    spending_rank,
    spend_month,
    monthly_spend,
    running_total,
    (spending_rank <= 100) AS is_top_100,
    trailing_12_month_spend
FROM final_report;
