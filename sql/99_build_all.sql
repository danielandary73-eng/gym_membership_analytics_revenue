-- Gym Membership & Revenue Analytics: structural build, packaging revision 2026-11-16
-- Fresh/empty gym_membership_analytics schema ONLY. Not for the existing populated project.
-- MySQL command-line client: run from this sql directory with source 99_build_all.sql
-- For Workbench, execute the individual files in the order in README.md.
-- Review every result. SELECT-based FAIL results do not automatically abort this script.
-- Do not use --force. Any SQL error, FAIL result, or unexpected exception row blocks approval.

SELECT 'STEP 01/18 - 00_create_schema.sql' AS build_progress;
source 00_create_schema.sql

SELECT 'STEP 02/18 - 01_create_tables.sql' AS build_progress;
source 01_create_tables.sql

SELECT 'STEP 03/18 - 02_create_keys_indexes.sql' AS build_progress;
source 02_create_keys_indexes.sql

SELECT 'STEP 04/18 - 90_validate_schema_foundation.sql' AS build_progress;
source 90_validate_schema_foundation.sql

SELECT 'STEP 05/18 - 03_create_triggers.sql' AS build_progress;
source 03_create_triggers.sql

SELECT 'STEP 06/18 - 91_validate_history_triggers.sql' AS build_progress;
source 91_validate_history_triggers.sql

SELECT 'STEP 07/18 - 04_create_views.sql' AS build_progress;
source 04_create_views.sql

SELECT 'STEP 08/18 - 92_validate_views.sql' AS build_progress;
source 92_validate_views.sql

SELECT 'STEP 09/18 - 05_create_membership_check_in_procedures.sql' AS build_progress;
source 05_create_membership_check_in_procedures.sql

SELECT 'STEP 10/18 - 93_validate_membership_check_in_procedures.sql' AS build_progress;
source 93_validate_membership_check_in_procedures.sql

SELECT 'STEP 11/18 - 06_create_payment_procedures.sql' AS build_progress;
source 06_create_payment_procedures.sql

SELECT 'STEP 12/18 - 94_validate_payment_procedures.sql' AS build_progress;
source 94_validate_payment_procedures.sql

SELECT 'STEP 13/18 - 07_create_refund_procedures.sql' AS build_progress;
source 07_create_refund_procedures.sql

SELECT 'STEP 14/18 - 95_validate_refund_procedures.sql' AS build_progress;
source 95_validate_refund_procedures.sql

SELECT 'STEP 15/18 - 08_create_financial_exception_procedures.sql' AS build_progress;
source 08_create_financial_exception_procedures.sql

SELECT 'STEP 16/18 - 96_validate_financial_exception_procedures.sql' AS build_progress;
source 96_validate_financial_exception_procedures.sql

SELECT 'STEP 17/18 - 09_create_roles_grants.sql' AS build_progress;
source 09_create_roles_grants.sql

SELECT 'STEP 18/18 - 97a_validate_structural_roles_grants.sql' AS build_progress;
source 97a_validate_structural_roles_grants.sql

SELECT 'Structural source execution finished; inspect every validation result before proceeding.' AS build_completion_notice;
