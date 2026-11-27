-- ============================================================
-- Independent validation for customer_spending_report
-- Run after 01_customer_spending_report.sql.
-- Raises an exception if a key report invariant fails.
-- ============================================================

DO $$
DECLARE
    v_customer_count bigint;
    v_report_rows bigint;
    v_top_100_count bigint;
    v_month_count bigint;
BEGIN
    SELECT COUNT(*) INTO v_customer_count FROM customers;
    SELECT COUNT(*) INTO v_report_rows FROM customer_spending_report;
    SELECT COUNT(DISTINCT spend_month)
      INTO v_month_count
      FROM customer_spending_report;

    -- All customers must appear for each of the 13 calendar labels.
    IF v_month_count <> 13 OR v_report_rows <> v_customer_count * 13 THEN
        RAISE EXCEPTION
            'Expected % customers x 13 months; found % rows across % months',
            v_customer_count, v_report_rows, v_month_count;
    END IF;

    -- Exactly one row per customer/month.
    IF EXISTS (
        SELECT customer_id, spend_month
        FROM customer_spending_report
        GROUP BY customer_id, spend_month
        HAVING COUNT(*) <> 1
    ) THEN
        RAISE EXCEPTION 'Duplicate customer/month rows found';
    END IF;

    -- Lifetime spend and order count must match an independent query.
    IF EXISTS (
        SELECT 1
        FROM customers AS c
        LEFT JOIN (
            SELECT
                customer_id,
                COALESCE(SUM(total_amount), 0)::numeric(18, 2) AS total_spent,
                COUNT(*)::bigint AS order_count
            FROM orders
            WHERE LOWER(TRIM(status)) IN ('completed', 'complete', 'shipped')
              AND order_date < CURRENT_DATE + INTERVAL '1 day'
            GROUP BY customer_id
        ) AS expected ON expected.customer_id = c.customer_id
        JOIN (
            SELECT DISTINCT customer_id, total_spent, order_count
            FROM customer_spending_report
        ) AS actual ON actual.customer_id = c.customer_id
        WHERE actual.total_spent <> COALESCE(expected.total_spent, 0)::numeric(18, 2)
           OR actual.order_count <> COALESCE(expected.order_count, 0)::bigint
    ) THEN
        RAISE EXCEPTION 'Lifetime spend/order count does not match independent calculation';
    END IF;

    -- Rolling-period total must match an independent date-filtered query.
    IF EXISTS (
        SELECT 1
        FROM (
            SELECT DISTINCT customer_id, trailing_12_month_spend
            FROM customer_spending_report
        ) AS actual
        LEFT JOIN (
            SELECT
                customer_id,
                COALESCE(SUM(total_amount), 0)::numeric(18, 2)
                    AS trailing_12_month_spend
            FROM orders
            WHERE LOWER(TRIM(status)) IN ('completed', 'complete', 'shipped')
              AND order_date >= CURRENT_DATE - INTERVAL '12 months'
              AND order_date < CURRENT_DATE + INTERVAL '1 day'
            GROUP BY customer_id
        ) AS expected ON expected.customer_id = actual.customer_id
        WHERE actual.trailing_12_month_spend
              <> COALESCE(expected.trailing_12_month_spend, 0)::numeric(18, 2)
    ) THEN
        RAISE EXCEPTION 'Trailing 12-month spend does not match independent calculation';
    END IF;

    -- The monthly buckets must reconcile to the rolling-period total.
    IF EXISTS (
        SELECT customer_id
        FROM customer_spending_report
        GROUP BY customer_id, trailing_12_month_spend
        HAVING SUM(monthly_spend) <> MAX(trailing_12_month_spend)
    ) THEN
        RAISE EXCEPTION 'Monthly spend does not reconcile to trailing 12-month spend';
    END IF;

    -- The final cumulative month must equal the rolling-period total.
    IF EXISTS (
        SELECT 1
        FROM (
            SELECT DISTINCT ON (customer_id)
                customer_id, running_total, trailing_12_month_spend
            FROM customer_spending_report
            ORDER BY customer_id, spend_month DESC
        ) AS final_month
        WHERE final_month.running_total <> final_month.trailing_12_month_spend
    ) THEN
        RAISE EXCEPTION 'Final running total does not equal trailing 12-month spend';
    END IF;

    -- Ranking must agree with an independent lifetime ranking.
    IF EXISTS (
        WITH expected AS (
            SELECT
                c.customer_id,
                ROW_NUMBER() OVER (
                    ORDER BY COALESCE(t.total_spent, 0) DESC, c.customer_id ASC
                ) AS expected_rank
            FROM customers AS c
            LEFT JOIN (
                SELECT customer_id, SUM(total_amount) AS total_spent
                FROM orders
                WHERE LOWER(TRIM(status)) IN ('completed', 'complete', 'shipped')
                  AND order_date < CURRENT_DATE + INTERVAL '1 day'
                GROUP BY customer_id
            ) AS t ON t.customer_id = c.customer_id
        )
        SELECT 1
        FROM expected AS e
        JOIN (
            SELECT DISTINCT customer_id, spending_rank
            FROM customer_spending_report
        ) AS actual USING (customer_id)
        WHERE actual.spending_rank <> e.expected_rank
    ) THEN
        RAISE EXCEPTION 'Lifetime spending rank does not match independent ranking';
    END IF;

    SELECT COUNT(DISTINCT customer_id)
      INTO v_top_100_count
      FROM customer_spending_report
      WHERE is_top_100;

    IF v_customer_count >= 100 AND v_top_100_count <> 100 THEN
        RAISE EXCEPTION 'Expected exactly 100 top-ranked customers, found %',
            v_top_100_count;
    END IF;

    RAISE NOTICE 'PASS: % customers, % report rows, % months, % top-100 customers',
        v_customer_count, v_report_rows, v_month_count, v_top_100_count;
END;
$$;
