# Kloud Kart – Data Quality Diagnosis

## 1. Executive Summary

The initial assessment identified data-integrity weaknesses across inventory, orders, customers, and product categories.

The most serious risks are negative stock balances, orphaned transaction records, unreliable order-item values, inconsistent order statuses, and incomplete inventory traceability.

These issues can lead to overselling, inaccurate revenue reporting, incomplete customer analysis, and poor operational decisions. The database should not be treated as fully reliable until the exceptions have been investigated and the relevant business rules have been agreed.

The implemented diagnostic process scans the source tables and records findings in a persistent data-quality exception register. Original source records are retained for investigation rather than silently corrected.

## 2. Findings Ranked by Business Danger

| Priority | Finding | Evidence | Business impact |
|---|---|---|---|
| Critical | Negative product stock | 14 products had negative stock quantities. | Available-to-sell figures cannot be trusted; overselling or incorrect stock adjustments may result. |
| Critical | Orphaned order items | 692 order items referenced missing orders. | Sales details may be excluded from reports or become difficult to reconcile. |
| Critical | Orders with missing customers | 210 orders referenced customer IDs not found in the customer table. | Customer spending and order-history reports may be incomplete or misattributed. |
| High | Orphaned inventory movements | 120 inventory log records referenced missing products. | Stock movements cannot be reliably attributed to products. |
| High | Missing order-item prices | 148 order items had NULL unit prices. | Revenue and customer-spending calculations may be understated or incomplete. |
| High | Suspicious order quantities and totals | Six order items had quantities of at least 999; one had 9,999. There were 2,279 order-total mismatches. | Could indicate bad imports, data-entry errors, or unusual transactions. Requires investigation before correction. |
| High | Incomplete inventory audit details | 281,927 of 282,352 inventory log rows had no note. | Investigating why stock changed is difficult. |
| Medium | Missing product categories | 37 products had NULL category IDs. | Category-level inventory reporting is incomplete. |
| Medium | Broken category hierarchy | One category had a missing parent; two categories formed a cycle. Three categories were unreachable from roots, leaving 91 of 94 reachable. | Recursive reporting may omit products in unreachable categories. |
| Medium | Duplicate normalized customer emails | 533 email groups involved 1,068 customer records. | Customer counts and identity matching may be unreliable. These records must not be merged automatically. |
| Medium | Inconsistent order statuses | 90,900 orders had status formatting variations, including case and spacing differences. Status values also included `complete`, `completed`, `shipped`, `cancelled`, and `canceled`. | Reports may classify business outcomes differently unless status rules are standardized. |
| Medium | Zero-quantity inventory movements | 90 inventory log records had `change_qty = 0`. | May represent no-op or incomplete audit entries; confirm whether these are valid before cleanup. |
| Medium | Inventory reconciliation exceptions | 144 products did not match the zero-opening-balance reconciliation assumption. | Indicates a need to investigate opening balances or missing movements; it does not prove current stock is wrong. |

The 14 products with negative stock are:

| Product ID | Product | Stock |
|---:|---|---:|
| 5005 | LG Mice XL | -4 |
| 5057 | Asus Fan | -4 |
| 5322 | Midea Rice 3 | -2 |
| 5391 | Unilever Keyboard Lite | -4 |
| 6148 | Kasapreko Mice | -1 |
| 6295 | JBL Kettle Mini | -1 |
| 6392 | Tecno Blender 2 | -1 |
| 6399 | Anker Sunscreen Max | -1 |
| 7049 | Tecno Feature Phone 3 | -1 |
| 7390 | Ideal Kettle Mini | -3 |
| 8107 | JBL Speaker Mini | -2 |
| 8353 | Infinix TV Accessorie | -1 |
| 8659 | Zeepay Soft Drink 3 | -1 |
| 8862 | Sunlight Women Accessorie 2 | -1 |

## 3. Detection Methods

The issues were identified using SQL profiling, joins, aggregation, filters, and recursive queries:

- **Negative stock:** Filtered `products` where `stock_quantity < 0`.
- **Orphaned records:** Used missing-reference checks between order items, orders, customers, products, and inventory logs.
- **Missing prices and categories:** Checked for `NULL` values.
- **Zero-priced items:** Filtered order items with a unit price of zero for review.
- **Large quantities:** Filtered order items for quantities of at least 999.
- **Order-total mismatches:** Compared recorded order totals with calculated totals from the associated order items, where the necessary item values were available.
- **Zero-quantity inventory movements:** Filtered inventory log records where `change_qty = 0`.
- **Category hierarchy:** Used recursive CTE traversal from root categories, with path tracking to detect cycles and unreachable categories.
- **Duplicate emails:** Grouped normalized email values using `LOWER(BTRIM(email))`.
- **Status formatting:** Compared raw status values with their lower-case, trimmed forms. Semantic status mapping requires separate business approval.
- **Inventory reconciliation:** Compared current stock with net logged movements, using a zero opening-balance assumption.

## 4. Persistent Exception Monitoring

The project implements three diagnostic database objects:

- `data_quality_exceptions`: Stores one current exception record per source table, source record ID, and issue type. It includes original source values as JSONB, first and last detection timestamps, detection count, investigation status, and resolution information.
- `record_data_quality_exception()`: Retained as an internal helper and not granted to application roles. The scanner performs a set-based batch upsert for repeated detections.
- `scan_data_quality_exceptions()`: Scans the source tables and records the identified data-quality exceptions.

The latest validated scanner results recorded **377,647 open exception records across 15 issue types**. The scanner implements 20 issue checks; 15 produced matching records and five produced none.

| Issue type | Open records |
|---|---:|
| Inventory records missing notes | 281,927 |
| Order status formatting variations | 90,900 |
| Duplicate normalized email records | 1,068 |
| Missing order references in order items | 692 |
| Orders with missing customers | 210 |
| Order-total mismatches | 2,279 |
| Order items with NULL prices | 148 |
| Zero-priced order items for review | 152 |
| Inventory records missing products | 120 |
| Zero-quantity inventory movements | 90 |
| Products with missing categories | 37 |
| Negative product stock | 14 |
| Large order quantities for review | 6 |
| Unreachable categories | 3 |
| Categories with missing parents | 1 |

The five checks with no matching records were `ORDER_ITEM_PRODUCT_MISSING`, `PRODUCT_CATEGORY_NOT_FOUND`, `ORDER_ITEM_QUANTITY_NONPOSITIVE`, `ORDER_ITEM_UNIT_PRICE_NEGATIVE` and `PRODUCT_PRICE_NEGATIVE`.

The counts represent exception records, not necessarily distinct business incidents. For example, the 1,068 duplicate-email exceptions represent implicated customer records across 533 duplicate groups.

The latest validation recorded **1,130,662 cumulative detections**. This is a detection counter across repeated scans, not the number of unique exceptions.

The register has important limitations:

1. It preserves the first captured source-value snapshot; it does not maintain a complete history of every subsequent source-record change.
2. Repeated detection updates the last-detected timestamp and detection count.
3. If an exception has been marked resolved but is detected again, it is reopened.
4. An exception is not automatically resolved merely because a later scan no longer finds the issue. Investigation and explicit resolution are required.
5. The register records exceptions; it does not automatically repair the original source data.

## 5. Important Interpretation and Limitations

These findings are exceptions for investigation, not automatic proof of fraud or incorrect transactions.

1. Duplicate email addresses do not necessarily mean duplicate people.
2. Zero-priced order items may represent promotions or free gifts.
3. Large order quantities may be genuine bulk orders, although they warrant review.
4. Zero-quantity inventory movements may be legitimate system or operational entries and should be investigated before removal.
5. Inventory reconciliation assumes a zero opening balance. The original opening stock is not known, so neither `MATCHES_ZERO_OPENING_BALANCE_ASSUMPTION` nor a review status proves the true balance; mismatches must be investigated rather than automatically corrected.
6. The project's fixed customer-spending policy treats `completed`, `complete`, and `shipped` as eligible; all other statuses are excluded. This makes project results reproducible, but production use still requires business-owner approval.
7. The scanner identifies formatting variations in raw statuses, but it does not establish the correct business meaning of each status.
8. An order-total mismatch is a reason for investigation, not automatic proof that the recorded total is wrong. Discounts, taxes, shipping, or other business rules may explain some differences.

## 6. Recommended Remediation Order

1. Investigate negative stock and validate inventory balances. After correcting the 14 listed products and confirming no negative rows remain, run `sql/00_setup/04_validate_stock_protection.sql` to validate the `NOT VALID` constraint.
2. Resolve orphaned orders and order items, preserving source records.
3. Review missing prices, zero-priced items, suspicious quantities, and order-total differences.
4. Investigate orphaned inventory movements and improve inventory audit completeness.
5. Repair category hierarchy cycles and missing parent references after confirming the intended structure.
6. Review duplicate customer identities and standardize status values with business approval.
7. Investigate zero-quantity inventory movements and establish whether they are valid.
8. Continue running the exception scanner and explicitly track investigation and resolution of outstanding issues.
9. Introduce additional constraints and validation rules after historical exceptions have been addressed.

## 7. Conclusion

The source database contains useful operational data, but its integrity limitations affect inventory reliability, financial reporting, and customer analytics.

The project therefore adds safer order processing, persistent data-quality exception monitoring, recursive category reporting, inventory reconciliation, and controlled inventory movement logging while retaining the original historical records.

The exception register makes data-quality problems visible and trackable, while leaving business-sensitive corrections under controlled investigation.

Historical stock balances and every historical transaction have not been independently certified. The original opening stock is unknown, and several historical data exceptions require investigation before corrections can be trusted.
