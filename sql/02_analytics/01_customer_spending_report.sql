-- ============================================================
-- Kloud Kart: Customer spending report
--
-- Includes:
-- 1. All customers, including customers with no eligible orders.
-- 2. Total spend and eligible order count.
-- 3. Monthly spend over the trailing 12 months.
-- 4. Running cumulative spend by customer.
-- 5. Customer spending rank and top-100 flag.
--
-- Business assumption:
-- completed, complete, and shipped orders count as spend.
-- Pending, cancelled, and refunded orders are excluded.
--
-- Date assumption:
-- The rolling 12-month period is anchored to CURRENT_DATE.
-- The monthly grid includes the current month and the month
-- containing the date 12 months ago (13 month labels).
-- ============================================================

CREATE OR REPLACE VIEW customer_spending_report AS

WITH eligible_orders AS (

    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        o.total_amount
    FROM orders o
    WHERE LOWER(TRIM(o.status))
              IN ('completed', 'complete', 'shipped')
      AND o.order_date >= CURRENT_DATE - INTERVAL '12 months'
      AND o.order_date < CURRENT_DATE + INTERVAL '1 day'
),

customer_totals AS (

    SELECT
        customer_id,
        SUM(total_amount) AS total_spent,
        COUNT(*) AS order_count
    FROM eligible_orders
    GROUP BY customer_id
),

monthly_spend AS (

    SELECT
        customer_id,
        DATE_TRUNC('month', order_date)::date AS spend_month,
        SUM(total_amount) AS monthly_spend
    FROM eligible_orders
    GROUP BY
        customer_id,
        DATE_TRUNC('month', order_date)::date
),

report_months AS (

    SELECT GENERATE_SERIES(
        DATE_TRUNC(
            'month',
            CURRENT_DATE - INTERVAL '12 months'
        ),
        DATE_TRUNC('month', CURRENT_DATE),
        INTERVAL '1 month'
    )::date AS spend_month
),

ranked_customers AS (

    SELECT
        c.customer_id,
        c.full_name,

        COALESCE(ct.total_spent, 0) AS total_spent,

        COALESCE(ct.order_count, 0) AS order_count,

        RANK() OVER (
            ORDER BY COALESCE(ct.total_spent, 0) DESC
        ) AS spending_rank

    FROM customers c

    LEFT JOIN customer_totals ct
        ON ct.customer_id = c.customer_id
),

customer_month_grid AS (

    SELECT
        rc.customer_id,
        rc.full_name,
        rc.total_spent,
        rc.order_count,
        rc.spending_rank,
        rm.spend_month,

        COALESCE(ms.monthly_spend, 0) AS monthly_spend

    FROM ranked_customers rc

    CROSS JOIN report_months rm

    LEFT JOIN monthly_spend ms
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
        ) AS running_total

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
    (spending_rank <= 100) AS is_top_100

FROM final_report;
