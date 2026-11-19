# SQL setup and validation

Owner: Daniel Andari  
Packaging revision: 2026-11-16

## Existing project users

Uploading this folder to GitHub does not execute SQL. Do not rebuild or reseed
an already populated project merely to publish these files. Keep the original
September source archive as historical evidence.

## Requirements

- MySQL 8.0 with enforced CHECK constraints (8.0.16 or later), and MySQL Workbench
  or the MySQL command-line client.
- A fresh or empty `gym_membership_analytics` schema in an isolated development
  instance. The test scripts use a separate `gym_membership_analytics_test` schema.
- A deployment account permitted to create schema objects, routines, triggers,
  roles, and grants, and inspect privilege metadata including `mysql.procs_priv`.
- Named timezone data supporting `Asia/Beirut`. Check before building:

```sql
SELECT CONVERT_TZ('2026-01-15 12:00:00', '+00:00', 'Asia/Beirut') AS beirut_time;
```

A NULL result means named timezone support must be configured by the database
administrator. Do not substitute a fixed offset for Beirut across the dataset.
Run the build files in order in the same connection so the session settings
from script 00 apply. After a reconnect, reapply those session settings.

## 1. Structural build

For Workbench, execute the following files individually in order, reviewing each
validator before proceeding. For the MySQL command-line client only, from this
folder run `source 99_build_all.sql` to perform the same sequence. `source` is a
client command, not server SQL for Workbench's editor.

1. `00_create_schema.sql`
2. `01_create_tables.sql`
3. `02_create_keys_indexes.sql`
4. `90_validate_schema_foundation.sql`
5. `03_create_triggers.sql`
6. `91_validate_history_triggers.sql`
7. `04_create_views.sql`
8. `92_validate_views.sql`
9. `05_create_membership_check_in_procedures.sql`
10. `93_validate_membership_check_in_procedures.sql`
11. `06_create_payment_procedures.sql`
12. `94_validate_payment_procedures.sql`
13. `07_create_refund_procedures.sql`
14. `95_validate_refund_procedures.sql`
15. `08_create_financial_exception_procedures.sql`
16. `96_validate_financial_exception_procedures.sql`
17. `09_create_roles_grants.sql`
18. `97a_validate_structural_roles_grants.sql`

All validation results must be PASS; queries documented as exception queries
must return no rows. Check each result tab. A SELECT that returns FAIL does not
raise a SQL error, so reaching the end of a master script does not prove success.

The structural audit boundary is **46 objects: 21 tables + 25 views**. The
analyst has nine curated view SELECT grants at this stage. The final analytical
boundary is different and must be validated after the analytical extension.

## 2. Functional tests in the disposable test schema

Read `10_build_test_environment.sql` before running it: it drops and rebuilds
only `gym_membership_analytics_test`. Use it only where that test schema is disposable.

Run 10, then the five workflow scripts 11 through 15 in numeric order. Inspect
all outputs against each script's expected results. Script 16 removes the test
schema after its evidence is saved; it does not remove the main project schema.

## 3. Synthetic data

After structural and functional acceptance, execute:

1. `20_seed_synthetic_dataset.sql` once against the empty main schema.
2. Confirm `PDM025_SYNTHETIC_DATASET_LOAD = COMPLETE`.
3. `98_validate_synthetic_dataset.sql`.
4. Confirm all PASS results, zero integrity exceptions, and financial READY.

The deterministic loader refuses to mix its records with an existing dataset.
The historical period is 2023-09-01 through 2026-08-31, with an opening anchor
and a 60-day planning horizon. Data is synthetic and currency is USD.

## 4. Analytical extension

Execute in this exact order:

1. `21_create_analysis_views.sql`
2. `23_build_analysis_mart.sql` — wait for `SQLA003_MART_BUILD = COMPLETE`.
3. `24_build_obligation_activity_mart.sql` — wait for `SQLA003_OBLIGATION_ACTIVITY_MART_BUILD = COMPLETE`.
4. `22_extend_analysis_grants.sql`
5. `97_validate_roles_grants.sql` — the original final-stage grants validator.
6. `99c_validate_final_release_gate.sql` — eight PASS controls and final READY.

Final inventory: 24 tables (21 operational + 3 marts), 35 views (25 original +
10 analytical), 19 analyst view SELECT grants, zero analyst base-table SELECT
grants, and 59 audit SELECT grants. The final gate checks the analyst's exact
view count; script 97 also checks the original nine curated views and prohibited
privileges. Review both rather than relying on either in isolation.

`99_validate_analysis_layer.sql` and `99b_validate_analysis_deep.sql` are optional
diagnostic audits, not normal setup steps. The archived acceptance review records
MySQL Windows internal temporary-table errors during repeated large-view expansion.
`01b_create_missing_tables.sql` is a historical recovery script, not a normal build step.

## 5. Power BI

The report uses the curated MySQL views in `gym_membership_analytics`. The
original local connection was `localhost:3307`; use the server and port of your
own MySQL instance. Configure local credentials in Power BI's data-source
settings, using an account assigned the approved read-only analyst role.
Role creation is included; login creation and role assignment are administrator
steps and are not embedded in this package. Do not add passwords to the repository.

Build and validate the SQL source before refreshing Power BI. Refreshing the
report does not rebuild the SQL marts. The supplied snapshot/mart approach is
for this fixed synthetic dataset, not an automated production update pipeline.
MySQL connector/driver installation and Power BI version compatibility must be
verified on the target workstation; this package does not bundle installers.

## Revision scope and testing

See `PACKAGING_CHANGES.md`. Source dependencies and the new structural count
were checked programmatically. The revised sequence has not been executed against
a fresh MySQL instance in this review. Prior live acceptance belongs to the
original project; do not describe this packaging revision as a new live test pass.
