\# Kloud Kart — Technical Decisions and Trade-offs



\## 1. Overview



The solution improves order safety, customer-spending analytics, category-level stock visibility, and inventory auditability using PostgreSQL features. The existing relational schema is retained. No additional infrastructure is introduced.



\## 2. Preventing overselling



\### Decision



Use an atomic conditional `UPDATE` inside the `place\_order()` PL/pgSQL function:



```sql

UPDATE products

SET stock\_quantity = stock\_quantity - p\_quantity

WHERE product\_id = p\_product\_id

&#x20; AND stock\_quantity >= p\_quantity

RETURNING price;

```



\### Why this works



PostgreSQL obtains a row-level lock when updating a product. If two transactions attempt to buy the last unit, one transaction updates the row first. The other waits and, under the default READ COMMITTED isolation level, rechecks the update condition against the updated row.



Once stock reaches zero, the waiting transaction no longer satisfies `stock\_quantity >= p\_quantity` and updates no row. The function returns a clear out-of-stock response.



The stock deduction and insertion of the order, order item, and inventory movement occur in the same transaction. If a later insert fails, PostgreSQL rolls back the statement, including the stock deduction.



\### Test evidence



The original instructor `race\_test.py` was run without modification:



\- Last-unit contention: 25/25 rounds produced exactly one successful buyer.

\- Flash sale: 400 concurrent buyers competing for 50 units resulted in 50 sales and 350 refusals.

\- No overselling or unexpected errors occurred.

\- Flash-sale test completed in approximately 4.72 seconds.

\- Excess-quantity requests were rejected without changing stock.

\- Inventory movement records were verified after contention.



\### Why a trigger alone is insufficient



A trigger can enforce rules or record changes, but it does not automatically make an unsafe read-then-update sequence concurrency-safe. The critical protection is the atomic conditional update or an equivalent locking strategy. A trigger could supplement this design, but it is not a substitute for correct transaction logic.



\## 3. Customer-spending analytics



\### Decision



Create a `customer\_spending\_report` view using common table expressions and window functions.



The report provides:



\- Total eligible spend and eligible order count per customer.

\- Monthly spend over the reporting window.

\- Running cumulative spend by customer.

\- Spending rank and a top-100 flag.

\- Customers with no eligible orders, retained through `LEFT JOIN` logic.



The initial eligible statuses are `completed`, `complete`, and `shipped`. This is an explicit working assumption pending confirmation from the operations team.



\### Performance evidence



The report returns 525,460 rows, representing 40,420 customers across 13 monthly labels.



`EXPLAIN ANALYZE` measured approximately 1.90 seconds on the test environment. The top-100 validation returned 100 distinct customers and 1,300 customer-month rows.



The report uses a generated month series and a customer-month grid so customers with no orders in a month still receive a zero-spend row.



\### Trade-offs and future optimization



The view calculates results when queried. This avoids maintaining a separate summary table, but repeated report execution still processes the underlying data.



The execution plan showed sequential scans and temporary disk activity. Since a large proportion of orders qualify, a sequential scan can be more efficient than using an index. A materialized view or maintained summary table could improve repeated reporting further, but would introduce refresh and data-freshness considerations.



The current 13 monthly labels include partial boundary months. The business should confirm whether it wants 12 calendar-month labels or a rolling date window.



\## 4. Recursive category reporting



\### Decision



Use a recursive CTE to traverse the category hierarchy from root categories. Each traversal carries a path array to prevent revisiting a category already on that path.



The `low\_stock\_category\_report` view rolls up products with stock quantities of five or fewer to their ancestors. This supports arbitrary hierarchy depth without hardcoding Electronics, Phones, Accessories, or Cases.



\### Trade-offs



The report traverses categories when queried. With only 94 categories in the supplied dataset, this is a reasonable approach. For a much larger hierarchy or very frequent reporting, a maintained closure table could improve query performance at the cost of additional write and maintenance complexity.



The separate `product\_category\_exceptions` view exposes products assigned to missing or unreachable category branches rather than silently treating those branches as normal.



\## 5. Inventory auditability



\### Decision



The `place\_order()` function writes a negative inventory movement for each successful sale to `inventory\_log` in the same transaction as the order.



The movement reason is `sale`, and the note contains the generated order ID.



The `inventory\_reconciliation\_review` view compares current stock against net logged movements and identifies products requiring investigation.



\### Limitation



The existing inventory log does not have a dedicated `order\_id` column. The order ID is therefore stored in the note for traceability. A future schema improvement would add a proper foreign-key relationship and potentially a reference to the source transaction.



The reconciliation view assumes a zero opening balance. Because historical opening balances are unavailable, mismatches are review flags rather than proof of incorrect stock.



\## 6. Additional implementation: data-quality exception views



The project includes `product\_category\_exceptions` and `inventory\_reconciliation\_review` in addition to the required reporting functionality.



These views make historical integrity issues visible without silently modifying or deleting source records. This is safer than applying unverified corrections to operational data.



\## 7. Deployment order



Run the SQL files after the original instructor schema and data load:



1\. `sql/00\_setup/01\_sequences.sql`

2\. `sql/01\_transactions/01\_place\_order.sql`

3\. `sql/02\_analytics/01\_customer\_spending\_report.sql`

4\. `sql/03\_inventory/01\_low\_stock\_category\_report.sql`

5\. `sql/03\_inventory/02\_category\_exceptions.sql`

6\. `sql/03\_inventory/03\_inventory\_reconciliation.sql`



The original instructor files remain unchanged.



\## 8. Conclusion



The solution prioritizes transaction correctness, measurable performance, and transparent data-quality handling. It demonstrates that the required improvements can be implemented within ordinary PostgreSQL infrastructure while documenting the assumptions and limitations that require business approval.





\## 9. Additional improvement: database-level stock protection



A database-level CHECK constraint was added:



```sql

ALTER TABLE products

ADD CONSTRAINT products\_stock\_nonnegative

CHECK (stock\_quantity >= 0)

NOT VALID;

```



The original data contains 14 products with negative stock. Applying a normally validated constraint would fail against these historical records.



Using `NOT VALID` preserves the existing exceptions while enforcing the rule for new inserts and updates.



\### Verification



A test attempted to update a product's stock to -999 inside a transaction. PostgreSQL rejected the update with a violation of `products\_stock\_nonnegative`, and the transaction was rolled back.



The constraint remains unvalidated because the historical negative balances still require investigation. After those records are resolved, the constraint can be validated with:



```sql

ALTER TABLE products

VALIDATE CONSTRAINT products\_stock\_nonnegative;

```



This provides a database-level safeguard in addition to the atomic stock deduction in `place\_order()`.
