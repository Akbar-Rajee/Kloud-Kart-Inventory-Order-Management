# Kloud Kart — Data Quality Diagnosis

## 1. Executive summary

The initial assessment identified data-integrity weaknesses across
inventory, orders, customers, and product categories. The most serious
risks are negative stock balances, orphaned order records, unreliable
order-item values, and incomplete inventory traceability.

These issues can lead to overselling, inaccurate revenue reporting,
incorrect customer analysis, and poor operational decisions. The
database should not be treated as fully reliable until the exceptions
below are reviewed and business rules are agreed.

## 2. Findings ranked by business danger

| Priority | Finding                                | Evidence                                                                                                                       | Business impact                                                                                                       |
|----------|----------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| Critical | Negative product stock                 | 14 products had negative stock quantities                                                                                      | Inventory may be oversold or incorrectly adjusted. Available-to-sell figures cannot be trusted.                       |
| Critical | Orphaned order items                   | 692 order items referenced missing orders                                                                                      | Sales details may be excluded from reports or become impossible to reconcile.                                         |
| Critical | Orders with missing customers          | 210 orders referenced customer IDs not found in the customer table                                                             | Customer spend and order-history reports may be incomplete or misattributed.                                          |
| High     | Orphaned inventory movements           | 120 inventory log records referenced missing products                                                                          | Stock movements cannot be reliably attributed to products.                                                            |
| High     | Missing order-item prices              | 148 order items had NULL unit prices                                                                                           | Revenue and customer-spend calculations may be understated or incomplete.                                             |
| High     | Suspicious order quantities and totals | Six order items had quantities of at least 999; one had 9,999. Some order totals differed substantially from line-item totals. | Could indicate bad imports, data-entry errors, or unusual transactions. Requires investigation before correction.     |
| High     | Incomplete inventory audit details     | 281,927 of 282,352 inventory log rows had no note                                                                              | Investigating why stock changed is difficult.                                                                         |
| Medium   | Missing product categories             | 37 products had NULL category IDs                                                                                              | Category-level inventory reporting is incomplete.                                                                     |
| Medium   | Broken category hierarchy              | One category had a missing parent; two categories formed a cycle. Only 91 of 94 categories were reachable from roots.          | Recursive reporting may omit products in unreachable categories.                                                      |
| Medium   | Duplicate normalized customer emails   | 533 email groups involved 1,068 customer records                                                                               | Customer counts and identity matching may be unreliable. These records must not be merged automatically.              |
| Medium   | Inconsistent order statuses            | Status values included `complete`, `completed`, `shipped`, `cancelled`, and `canceled`, with additional case/spacing variants  | Different reports may classify the same business outcome differently.                                                 |
| Medium   | Inventory reconciliation exceptions    | 144 products did not match the zero-opening-balance reconciliation assumption                                                  | Indicates a need to investigate opening balances or missing movements; it does not prove that current stock is wrong. |

## 3. Detection methods

The issues were identified using SQL profiling and exception queries:

- **Negative stock:** Filtered `products` where `stock_quantity < 0`.
- **Orphaned records:** Used `LEFT JOIN` checks between order items,
  orders, customers, products, and inventory logs.
- **Missing prices and categories:** Checked for `NULL` values.
- **Large quantities:** Filtered order items for unusually high
  quantities.
- **Category hierarchy:** Used recursive CTE traversal from root
  categories, with path tracking to avoid cycles.
- **Duplicate emails:** Grouped on normalized email values using
  `LOWER(TRIM(email))`.
- **Status inconsistency:** Grouped by raw status and compared
  normalized values.
- **Inventory reconciliation:** Compared current stock with net logged
  movements.

## 4. Important interpretation and limitations

These findings are exceptions for investigation, not automatic proof of
fraud or incorrect transactions.

In particular:

1.  Duplicate email addresses do not necessarily mean duplicate people.
2.  Zero-priced order items may represent promotions or free gifts.
3.  Large order quantities may be genuine bulk orders, although they
    warrant review.
4.  Inventory reconciliation assumes a zero opening balance. The
    original opening stock is not known, so mismatches must be
    investigated rather than automatically corrected.
5.  Status normalization requires confirmation from the business. For
    the initial customer-spending report, `completed`, `complete`, and
    `shipped` are treated as eligible statuses. Pending, cancelled, and
    refunded orders are excluded.

## 5. Recommended remediation order

1.  Investigate negative stock and validate inventory balances.
2.  Resolve orphaned orders and order items, preserving source records.
3.  Review missing prices and suspicious quantities or order totals.
4.  Investigate orphaned inventory movements and improve audit
    completeness.
5.  Repair category hierarchy cycles and missing parent references.
6.  Review duplicate customer identities and standardize status values
    with business approval.
7.  Introduce appropriate constraints and data-quality monitoring after
    historical exceptions have been addressed.

## 6. Conclusion

The source database contains useful operational data, but its integrity
limitations affect inventory reliability, financial reporting, and
customer analytics. The project therefore adds safer order processing,
exception reporting, recursive category reporting, and inventory
movement logging while keeping the original schema and historical
records intact.
