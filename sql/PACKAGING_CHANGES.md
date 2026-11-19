# SQL packaging changes — 2026-11-16

This revision changes deployment orchestration and documentation, not business
rules, data generation, DAX, or the existing database.

1. Added `97a_validate_structural_roles_grants.sql`: a structural-stage copy of
   script 97 with audit SELECT expectation 46 rather than the final-stage 59.
   The original `97_validate_roles_grants.sql` remains byte-for-byte unchanged.
2. Reordered `99_build_all.sql` to run validators at their corresponding build
   stage. In particular, 93/94/95 contain unexpected-procedure checks for the
   cumulative 8/12/15-routine inventories; running them only after all 20 routines
   exist would produce misleading exception rows.
3. The master now uses 97a before the analytical extension. The final sequence
   still uses the original 97 and unchanged 99c after scripts 21, 23, 24, and 22.
4. Replaced the SQL README with stage-specific setup and validation guidance.

Validation performed: source existence/order checks, audit-count comparison,
unchanged-byte checks for the other 35 original SQL scripts, and ZIP integrity.
No MySQL server was executed for this revision. A fresh-instance execution is
still required before claiming fully reproduced setup.

The original source package contained 36 SQL scripts and one SQL-folder README.
This upload contains 37 SQL scripts and two Markdown files. Archived project
reviews outside this folder remain historical documentation, not revised evidence.
