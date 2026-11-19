-- Gym Membership & Revenue Analytics System
-- PDM-022 validation: role existence, positive grants, and prohibited privileges
-- Prerequisite: run 00_create_schema.sql through 09_create_roles_grants.sql first.

USE gym_membership_analytics;

DROP TEMPORARY TABLE IF EXISTS tmp_expected_pdm022_role;
DROP TEMPORARY TABLE IF EXISTS tmp_expected_pdm022_owner_privilege;
DROP TEMPORARY TABLE IF EXISTS tmp_expected_pdm022_application_reference;
DROP TEMPORARY TABLE IF EXISTS tmp_expected_pdm022_application_procedure;
DROP TEMPORARY TABLE IF EXISTS tmp_expected_pdm022_analyst_object;
DROP TEMPORARY TABLE IF EXISTS tmp_pdm022_routine_privilege;

-- MySQL 8.0 does not expose the standard INFORMATION_SCHEMA.ROUTINE_PRIVILEGES
-- table. Normalize role procedure grants from MySQL's authoritative grant table.
CREATE TEMPORARY TABLE tmp_pdm022_routine_privilege AS
SELECT
    CONCAT('''', User, '''@''', Host, '''') AS grantee,
    Db AS routine_schema,
    Routine_name AS routine_name,
    'EXECUTE' AS privilege_type,
    CASE WHEN FIND_IN_SET('Grant', Proc_priv) > 0 THEN 'YES' ELSE 'NO' END
        AS is_grantable
FROM mysql.procs_priv
WHERE Routine_type = 'PROCEDURE'
  AND FIND_IN_SET('Execute', Proc_priv) > 0;

CREATE TEMPORARY TABLE tmp_expected_pdm022_role (
    role_grantee VARCHAR(100) NOT NULL,
    CONSTRAINT pk_tmp_expected_pdm022_role PRIMARY KEY (role_grantee)
);

INSERT INTO tmp_expected_pdm022_role (role_grantee)
VALUES
    ('''gym_database_owner''@''%'''),
    ('''gym_application_writer''@''%'''),
    ('''gym_analyst_powerbi''@''%'''),
    ('''gym_audit_reviewer''@''%''');

CREATE TEMPORARY TABLE tmp_expected_pdm022_owner_privilege (
    privilege_type VARCHAR(64) NOT NULL,
    CONSTRAINT pk_tmp_expected_pdm022_owner_privilege PRIMARY KEY (privilege_type)
);

INSERT INTO tmp_expected_pdm022_owner_privilege (privilege_type)
VALUES
    ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('CREATE'), ('ALTER'), ('DROP'),
    ('INDEX'), ('REFERENCES'), ('CREATE VIEW'), ('SHOW VIEW'), ('TRIGGER'),
    ('CREATE ROUTINE'), ('ALTER ROUTINE'), ('EXECUTE');

CREATE TEMPORARY TABLE tmp_expected_pdm022_application_reference (
    object_name VARCHAR(64) NOT NULL,
    CONSTRAINT pk_tmp_expected_pdm022_application_reference PRIMARY KEY (object_name)
);

INSERT INTO tmp_expected_pdm022_application_reference (object_name)
VALUES
    ('branch'),
    ('membership_plan'),
    ('membership_plan_version'),
    ('member'),
    ('member_branch_assignment');

CREATE TEMPORARY TABLE tmp_expected_pdm022_application_procedure (
    procedure_name VARCHAR(64) NOT NULL,
    CONSTRAINT pk_tmp_expected_pdm022_application_procedure PRIMARY KEY (procedure_name)
);

INSERT INTO tmp_expected_pdm022_application_procedure (procedure_name)
VALUES
    ('sp_create_membership_plan_version'),
    ('sp_assign_member_home_branch'),
    ('sp_create_membership_contract'),
    ('sp_submit_membership_status_event'),
    ('sp_decide_membership_status_event'),
    ('sp_ingest_check_in'),
    ('sp_resolve_check_in_quality_issue'),
    ('sp_create_payment'),
    ('sp_record_payment_attempt'),
    ('sp_transition_payment_attempt'),
    ('sp_allocate_successful_payment'),
    ('sp_request_refund'),
    ('sp_transition_refund'),
    ('sp_complete_refund'),
    ('sp_scan_financial_exceptions'),
    ('sp_open_financial_exception'),
    ('sp_update_financial_exception_workflow'),
    ('sp_resolve_financial_exception');

CREATE TEMPORARY TABLE tmp_expected_pdm022_analyst_object (
    object_name VARCHAR(64) NOT NULL,
    CONSTRAINT pk_tmp_expected_pdm022_analyst_object PRIMARY KEY (object_name)
);

INSERT INTO tmp_expected_pdm022_analyst_object (object_name)
VALUES
    ('vw_reporting_check_in'),
    ('vw_reporting_financial_source_disposition'),
    ('vw_reporting_financial_exception'),
    ('vw_reporting_financial_exception_summary'),
    ('vw_reporting_gross_collected_revenue'),
    ('vw_reporting_refund'),
    ('vw_reporting_obligation_balance'),
    ('vw_reporting_net_collected_revenue'),
    ('vw_dq_financial_release_readiness');

-- Expected result: PASS with all four project roles visible as accounts with USAGE.
SELECT
    'PDM022_ROLE_COUNT' AS validation_control,
    4 AS expected_result,
    COUNT(privilege.grantee) AS actual_result,
    CASE WHEN COUNT(privilege.grantee) = 4 THEN 'PASS' ELSE 'FAIL' END
        AS validation_result
FROM tmp_expected_pdm022_role AS expected
LEFT JOIN information_schema.user_privileges AS privilege
    ON privilege.grantee = expected.role_grantee
   AND privilege.privilege_type = 'USAGE';

-- Expected result: zero rows. Any row is a missing owner/migration capability.
SELECT expected.privilege_type AS missing_owner_privilege
FROM tmp_expected_pdm022_owner_privilege AS expected
LEFT JOIN information_schema.schema_privileges AS privilege
    ON privilege.grantee = '''gym_database_owner''@''%'''
   AND privilege.table_schema = DATABASE()
   AND privilege.privilege_type = expected.privilege_type
WHERE privilege.privilege_type IS NULL
ORDER BY expected.privilege_type;

-- Expected result: five PASS rows for application reference reads.
SELECT
    expected.object_name,
    CASE WHEN privilege.table_name IS NOT NULL THEN 'PASS' ELSE 'FAIL' END
        AS validation_result
FROM tmp_expected_pdm022_application_reference AS expected
LEFT JOIN information_schema.table_privileges AS privilege
    ON privilege.grantee = '''gym_application_writer''@''%'''
   AND privilege.table_schema = DATABASE()
   AND privilege.table_name = expected.object_name
   AND privilege.privilege_type = 'SELECT'
ORDER BY expected.object_name;

-- Expected result: eighteen PASS rows for public application procedures.
SELECT
    expected.procedure_name,
    CASE WHEN privilege.routine_name IS NOT NULL THEN 'PASS' ELSE 'FAIL' END
        AS validation_result
FROM tmp_expected_pdm022_application_procedure AS expected
LEFT JOIN tmp_pdm022_routine_privilege AS privilege
    ON privilege.grantee = '''gym_application_writer''@''%'''
   AND privilege.routine_schema = DATABASE()
   AND privilege.routine_name = expected.procedure_name
   AND privilege.privilege_type = 'EXECUTE'
ORDER BY expected.procedure_name;

-- Expected result: PASS. The internal cancellation helper is not directly exposed.
SELECT
    'PDM022_INTERNAL_HELPER_NOT_EXPOSED' AS validation_control,
    0 AS expected_result,
    COUNT(*) AS actual_result,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM tmp_pdm022_routine_privilege
WHERE grantee = '''gym_application_writer''@''%'''
  AND routine_schema = DATABASE()
  AND routine_name = 'sp_record_cancellation_adjustments'
  AND privilege_type = 'EXECUTE';

-- Expected result: nine PASS rows for curated analyst/Power BI reads.
SELECT
    expected.object_name,
    CASE WHEN privilege.table_name IS NOT NULL THEN 'PASS' ELSE 'FAIL' END
        AS validation_result
FROM tmp_expected_pdm022_analyst_object AS expected
LEFT JOIN information_schema.table_privileges AS privilege
    ON privilege.grantee = '''gym_analyst_powerbi''@''%'''
   AND privilege.table_schema = DATABASE()
   AND privilege.table_name = expected.object_name
   AND privilege.privilege_type = 'SELECT'
ORDER BY expected.object_name;

-- Expected result: PASS. Analyst receives exactly one read-only procedure.
SELECT
    'PDM022_ANALYST_RELEASE_EXECUTE_COUNT' AS validation_control,
    1 AS expected_result,
    COUNT(*) AS actual_result,
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM tmp_pdm022_routine_privilege
WHERE grantee = '''gym_analyst_powerbi''@''%'''
  AND routine_schema = DATABASE()
  AND routine_name = 'sp_assert_financial_release_ready'
  AND privilege_type = 'EXECUTE';

-- Expected result after SQLA-003C: PASS with SELECT on all 24 tables and 35 views.
SELECT
    'PDM022_AUDIT_SELECT_OBJECT_COUNT' AS validation_control,
    59 AS expected_result,
    COUNT(*) AS actual_result,
    CASE WHEN COUNT(*) = 59 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM information_schema.table_privileges
WHERE grantee = '''gym_audit_reviewer''@''%'''
  AND table_schema = DATABASE()
  AND privilege_type = 'SELECT';

-- Expected result: zero rows. Every approved table or view must be auditable.
SELECT
    object_catalog.table_name AS missing_audit_select_object,
    object_catalog.table_type
FROM information_schema.tables AS object_catalog
LEFT JOIN information_schema.table_privileges AS privilege
    ON privilege.grantee = '''gym_audit_reviewer''@''%'''
   AND privilege.table_schema = object_catalog.table_schema
   AND privilege.table_name = object_catalog.table_name
   AND privilege.privilege_type = 'SELECT'
WHERE object_catalog.table_schema = DATABASE()
  AND privilege.table_name IS NULL
ORDER BY object_catalog.table_type, object_catalog.table_name;

-- Expected result: PASS. Audit reviewer can run the release disclosure gate.
SELECT
    'PDM022_AUDIT_RELEASE_EXECUTE_COUNT' AS validation_control,
    1 AS expected_result,
    COUNT(*) AS actual_result,
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM tmp_pdm022_routine_privilege
WHERE grantee = '''gym_audit_reviewer''@''%'''
  AND routine_schema = DATABASE()
  AND routine_name = 'sp_assert_financial_release_ready'
  AND privilege_type = 'EXECUTE';

-- Expected result: zero rows. Non-owner roles never receive operational DML.
SELECT
    grantee,
    table_name,
    privilege_type AS prohibited_operational_privilege
FROM information_schema.table_privileges
WHERE table_schema = DATABASE()
  AND grantee IN (
      '''gym_application_writer''@''%''',
      '''gym_analyst_powerbi''@''%''',
      '''gym_audit_reviewer''@''%'''
  )
  AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE')
ORDER BY grantee, table_name, privilege_type;

-- Expected result: zero rows. Analyst / Power BI has no raw base-table access.
SELECT privilege.table_name AS prohibited_analyst_base_table
FROM information_schema.table_privileges AS privilege
JOIN information_schema.tables AS object_catalog
    ON object_catalog.table_schema = privilege.table_schema
   AND object_catalog.table_name = privilege.table_name
WHERE privilege.grantee = '''gym_analyst_powerbi''@''%'''
  AND privilege.table_schema = DATABASE()
  AND privilege.privilege_type = 'SELECT'
  AND object_catalog.table_type = 'BASE TABLE'
ORDER BY privilege.table_name;

-- Expected result: zero rows. Role delegation remains outside these schema roles.
SELECT
    grantee,
    privilege_type,
    is_grantable
FROM (
    SELECT grantee, privilege_type, is_grantable
    FROM information_schema.schema_privileges
    WHERE table_schema = DATABASE()
    UNION ALL
    SELECT grantee, privilege_type, is_grantable
    FROM information_schema.table_privileges
    WHERE table_schema = DATABASE()
    UNION ALL
    SELECT grantee, privilege_type, is_grantable
    FROM tmp_pdm022_routine_privilege
    WHERE routine_schema = DATABASE()
) AS project_privilege
WHERE grantee IN (SELECT role_grantee FROM tmp_expected_pdm022_role)
  AND is_grantable = 'YES'
ORDER BY grantee, privilege_type;

DROP TEMPORARY TABLE tmp_expected_pdm022_analyst_object;
DROP TEMPORARY TABLE tmp_pdm022_routine_privilege;
DROP TEMPORARY TABLE tmp_expected_pdm022_application_procedure;
DROP TEMPORARY TABLE tmp_expected_pdm022_application_reference;
DROP TEMPORARY TABLE tmp_expected_pdm022_owner_privilege;
DROP TEMPORARY TABLE tmp_expected_pdm022_role;
