-- Gym Membership & Revenue Analytics System
-- PDM-023 cleanup: remove only the disposable functional-test environment.
-- This script does not modify the production gym_membership_analytics schema.

DROP DATABASE IF EXISTS gym_membership_analytics_test;

SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_schema_removed
FROM information_schema.schemata
WHERE schema_name = 'gym_membership_analytics_test';

