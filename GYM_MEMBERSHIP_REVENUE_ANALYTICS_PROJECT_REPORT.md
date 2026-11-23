# Gym Membership & Revenue Analytics

## Portfolio Project Report

| Field | Value |
| --- | --- |
| Project owner | Daniel Andari |
| Primary tools | MySQL 8.0, MySQL Workbench 8.0, Power BI, SQL, DAX |
| Current version | 1.2 — GitHub Portfolio Preparation |
| Last documentation update | November 20, 2026 |
| Reporting currency | USD |
| Business scope | Aley Heights, Beirut Central, and Jounieh Coast |
| Analysis period | September 1, 2023–August 31, 2026 |
| Data | Deterministic synthetic data representing a fictional gym business |
| Current status | Archived SQL acceptance complete; five Power BI pages built and reviewed; GitHub publication review in progress |

## 1. Executive Summary

This portfolio project develops an analytics solution for a fictional Lebanese gym company operating across three branches. It consolidates membership, branch, check-in, payment, obligation, refund, and financial-exception data into a MySQL analytical source for Power BI.

The archived SQL acceptance records describe a normalized 21-table operational model, protected historical workflows, a deterministic 36-month synthetic dataset, reporting views, ten additional analytical views, and three indexed analytical marts. The recorded final SQL release gate returned eight controls passed, zero failed, and `READY`.

Five Power BI report pages present membership activity, revenue, collections, attendance, branch comparisons, and financial controls. Selected dashboard results were compared with MySQL outputs during the November review.

The GitHub portfolio includes the SQL package, Power BI report file, operational database diagram and model, dashboard screenshots, and supporting documentation. The revised SQL packaging has not yet been executed in a fresh MySQL environment.

All results describe synthetic data. No real customer records, production deployment, or measured business improvement are claimed.

## 2. Business Problem

The fictional business scenario assumes that membership, payment, and check-in records are fragmented across branches and interpreted using inconsistent definitions.

Management needs reliable answers about:

- membership growth and the closing active membership base;
- contracts approaching expiration;
- collected revenue, refunds, and collection gaps;
- outstanding obligations and payment failures;
- plan mix and branch-level activity;
- financial exceptions and reporting readiness.

The project addresses these needs through documented KPI definitions, historical event preservation, controlled financial workflows, and a shared analytical source.

Financial comparisons distinguish contract value, expected revenue, collected cash, and amounts applied to obligations. Branch comparisons distinguish home, ownership, visited, and processing roles.

## 3. Stakeholders and Decisions

| Stakeholder | Decisions supported |
| --- | --- |
| General Manager | Membership trends, branch comparisons, plan strategy, and investment priorities |
| Finance Manager | Collections, balances, failed payments, refunds, and reconciliation |
| Membership Manager | Renewals, expirations, freezes, cancellations, and member follow-up |
| Branch Managers | Local activity, member engagement, and branch-level payment follow-up |

The approved requirements baseline contains 15 business requirements, 29 business rules, and 51 KPIs with documented SQL source mappings.

This baseline defines the project's intended analytical coverage. It does not mean that every catalogue KPI is displayed in Power BI or independently validated in the November review.

## 4. Project Scope

The dataset represents 36 months of fictional operational history across three Lebanese branches. It covers:

- members, membership plans, and effective-dated plan versions;
- contracts, renewals, reactivations, freezes, cancellations, and expirations;
- home-branch assignments and check-in activity;
- contract list value, discounts, and expected revenue;
- payment obligations, attempts, payments, and allocations;
- refunds, refund allocations, outstanding balances, and overdue ageing;
- financial exceptions, auditability, reporting eligibility, and release readiness.

The solution does not claim causal retention analysis, marketing attribution, staff performance measurement, predictive modelling, or conclusions about real customer behavior.

## 5. Data Architecture

### 5.1 Operational layer

The documented MySQL operational model contains:

| Component | Implemented total |
| --- | ---: |
| Tables | 21 |
| Active fields | 131 |
| Primary-key constraints | 21 |
| Unique constraints | 24 |
| Foreign-key constraints | 27 |
| Supporting indexes | 14 |
| History-protection triggers | 32 |
| Controlled procedures | 20 |
| Initial validation and reporting views | 25 |

Foreign keys use restrictive referential actions. Financial values use exact `DECIMAL(12,2)` storage. Business dates use `DATE`, while event timestamps use UTC `DATETIME(6)` with controlled conversion for Beirut reporting.

Historical plan prices, membership events, branch assignments, and financial status changes are preserved so that later operational changes do not silently overwrite earlier evidence.

### 5.2 Analytical layer

The documented analytical layer contains:

| Component | Implemented total |
| --- | ---: |
| `vw_analysis_*` views | 10 |
| Frozen analytical output columns | 178 |
| Indexed analytical marts | 3 |
| Analyst view SELECT grants | 19 |
| Analyst base-table grants | 0 |
| Audit SELECT grants after analytical extension | 59 |

The three analytical marts add three tables to the 21-table operational inventory.

The analytical layer supports membership, contract, snapshot, payment-attempt, obligation-activity, refund, branch, plan, and date analysis. Power BI reads approved views rather than operational base tables.

### 5.3 Reporting flow

**Operational MySQL tables → reporting views and analytical marts → curated analytical views → Power Query and Power BI model → DAX measures and report visuals**

The operational Workbench model and ERD document the original operational design. They predate the ten additional analytical views and three marts and should not be interpreted as a complete diagram of the final analytical layer.

## 6. Data Quality and Business Controls

The design protects historical and financial accuracy through named constraints, controlled procedures, history-protection triggers, reconciliation views, and release gates.

Key controls include:

- preserving historical plan prices and branch assignments;
- preventing overlapping effective-dated records;
- controlling membership and payment status transitions;
- identifying duplicate check-ins while preserving raw evidence;
- allowing one eligible successful attempt per funded payment path;
- enforcing allocation ceilings and exact payment reconciliation;
- enforcing refund ceilings and allocation reversal rules;
- reopening obligations where refund rules require it;
- excluding unresolved critical financial sources from approved reporting;
- separating gross revenue, discounts, refunds, and net collected revenue;
- disclosing financial release readiness.

The reporting layer distinguishes valid operational records from records eligible for approved financial reporting.

## 7. Synthetic Dataset

The deterministic dataset covers September 1, 2023 through August 31, 2026.

It includes:

- an opening anchor on August 31, 2023;
- 36 months of operational history;
- a 60-day planning horizon through October 30, 2026;
- all three approved branches;
- USD-denominated financial values.

The archived dataset validation record reports successful integrity, completeness, time-period, and financial-reconciliation checks.

The data is synthetic and fixed. Its patterns demonstrate analytical methods and business-rule implementation; they are not evidence of real gym performance or customer behavior.

## 8. Testing and Validation — Archived SQL Acceptance

The results in this section describe the archived SQL acceptance records. They are not results from a new execution of the revised GitHub package.

### 8.1 Functional testing

| Test batch | Automated checks | Recorded result |
| --- | ---: | --- |
| Membership, obligations, and valid check-in | 8 | PASS |
| Payment failure, retry, collection, and allocation | 9 | PASS |
| Refund and obligation reopening | 10 | PASS |
| Financial-exception workflow and release gate | 11 | PASS |
| Negative and history-protection controls | 11 | PASS |
| Total | 49 | PASS |

### 8.2 Final SQL acceptance

| Acceptance control | Recorded result |
| --- | --- |
| Physical schema and metadata | PASS |
| Trigger and procedure behavior | PASS |
| Reporting and analytical views | PASS |
| Synthetic dataset validation | PASS |
| Financial reconciliation | PASS |
| Role and grant boundary | PASS |
| Analytical marts populated and keyed | PASS |
| Final release gate | 8/8 PASS; `READY` |

The original full and deep analytical validators encountered a MySQL 8.0 for Windows internal `#sql` temporary-table failure during repeated expansion of the largest views.

The archived review treated this as an execution-path limitation and adopted `99c_validate_final_release_gate.sql` as the lightweight final validator. Its results complement the separate workflow and reconciliation tests; they do not independently establish the root cause of the larger validators' failure.

The lightweight gate verifies deployment, population, primary keys, and grant coverage. It does not replace the broader workflow and dataset-reconciliation tests.

## 9. Security Model

The design separates:

- schema ownership and administration;
- controlled application writes;
- analyst and Power BI reads;
- audit review.

The `gym_analyst_powerbi` role receives read-only access to approved views. It is not granted operational base-table access, operational DML, write-procedure execution, or Grant Option.

The audit role has broader read-only coverage for reviewing controlled evidence.

MySQL login creation, role assignment, connection settings, and Power BI authentication must be configured for the environment in which the project is reproduced.

## 10. SQL Deliverables and Setup

### 10.1 Original source archive

The original source archive contains 36 SQL scripts and 35 Markdown documents, including:

- schema, table, key, index, trigger, view, procedure, and role definitions;
- a disposable functional-test environment and workflow test batches;
- deterministic synthetic-data generation;
- analytical views and marts;
- structural, behavioral, security, dataset, and analytical validators;
- the final release gate;
- business requirements, KPI rules, data models, traceability records, and review reports.

These archive counts describe the historical source package, not the number of documents currently published in the repository.

### 10.2 GitHub SQL package

The GitHub `sql/` folder contains **37 SQL scripts and two Markdown documents**.

The packaging update:

- adds `97a_validate_structural_roles_grants.sql` for structural-stage grant validation;
- separates structural grant expectations from final analytical-stage expectations;
- places structural validation checks at their relevant build stages;
- retains `97_validate_roles_grants.sql` for final analytical-stage grant validation;
- documents execution stages, prerequisites, and verification limits.

Follow [SQL setup instructions](sql/README.md) for the execution sequence. See [SQL packaging changes](sql/PACKAGING_CHANGES.md) for the changes and their scope.

The packaging changes were checked statically. They have not yet been executed in a fresh MySQL environment.

### 10.3 Reproduction requirements

A reproduction check must account for:

- the documented MySQL version and script execution method;
- MySQL named time-zone availability for `Asia/Beirut`;
- account and role assignment;
- synthetic-data generation prerequisites;
- analytical-view and mart dependencies;
- validation results at each stage;
- local MySQL connection settings;
- Power BI source credentials and refresh configuration.

The analytical marts are not presented as a production incremental-refresh pipeline.

## 11. SQL Phase Outcome

The archived acceptance records describe the SQL phase as complete, with no unresolved implementation, integrity, reconciliation, or release issue at the September acceptance point.

The implementation provides a documented analytical source, preserves historical business events, supports the approved requirements and KPI source mappings, and enforces a restricted Power BI read boundary.

A later source-package review identified a build and validation sequencing issue. The GitHub package was subsequently updated with stage-specific structural grant validation and revised validation ordering.

These later packaging changes remain distinct from the historical SQL acceptance. A fresh execution of the revised package is still pending.

## 12. Power BI Implementation and Review

### 12.1 Report pages

| Page | Main purpose |
| --- | --- |
| Executive Overview | Membership base, net collections, collection rate, financial release status, and monthly revenue |
| Membership Analysis | Active members and contracts, expiration windows, membership plans, home branches, and transfers |
| Revenue & Collections | Contract values, discounts, expected revenue, gross/net collections, outstanding balances, and payment failures |
| Attendance & Branches | Check-ins and distinct visitors by visited branch, month, Beirut hour, and weekday |
| Financial Controls | Exception totals, unresolved exposure, reconciliation, severity filtering, and status history |

The report uses MySQL views through Power Query, dimension/fact relationships, DAX measures, branch/date slicers, and financial control summaries.

### 12.2 Review work completed

During the November review:

- selected KPI outputs were compared with SQL;
- monthly charts were changed to use `Dim_Date[month_start_date]` directly, removing categorical scrolling that hid later months;
- saved report settings were inspected for historical date slicers on Executive Overview and Attendance;
- visual-level obligation due-date and payment-attempt filters were reviewed;
- attendance labels were adjusted to display exact counts;
- the Financial Exception Status History title was reviewed;
- all five page definitions were confirmed in the supplied PBIX;
- the project owner confirmed the final axis-label adjustment and visual/export review.

Dashboard screenshots were subsequently uploaded to GitHub and embedded in the main README.

### 12.3 Review limits

The file inspection did not render the PDF or execute the embedded Power BI model. It does not establish that every measure or relationship is independently correct.

The newer PBIX upload was also checked for the five-page inventory. That inventory check is separate from a full numerical or relationship audit.

## 13. Selected SQL-to-Power BI Comparisons

Unless otherwise noted, historical dates cover September 1, 2023 inclusive through September 1, 2026 exclusive.

These figures come from comparisons supplied and confirmed during the review. They are not results from a new database execution performed for this documentation update.

### 13.1 Main measures

| Metric | Confirmed result | Definition / context |
| --- | ---: | --- |
| Total membership contracts | 3,500 | Distinct membership contract IDs |
| Closing active members | 246 | Closing snapshot, August 31, 2026 |
| Closing active membership contracts | 246 | Closing snapshot, August 31, 2026 |
| Expiring contracts, 1–30 days | 42 | Distinct flagged contracts at the selected latest snapshot |
| Expiring contracts, 31–60 days | 47 | Distinct flagged contracts at the selected latest snapshot |
| Gross collected revenue | $425,637.73 | Eligible collections in the historical transaction period |
| Total refunds | $2,074.61 | Historical transaction period |
| Net collected revenue | $423,563.12 | Gross collections less refunds |
| Net applied amount | $424,922.30 | Obligation collection-rate numerator |
| Collectible obligation amount | $535,497.19 | Obligation collection-rate denominator |
| Collection rate | 79.35% | Net applied / collectible amount |
| Outstanding balance, historical due-date scope | $110,574.89 | Current balances on obligations due within the reporting period |
| Outstanding balance, all dates | $129,334.60 | Includes obligations outside the historical due-date scope |
| Total check-ins | 60,000 | Historical attendance period |
| Distinct checked-in members | 1,000 | Company-wide distinct count |
| Total financial exceptions | 20 | Overall control summary |
| Unresolved financial exceptions | 0 | Current control summary |
| Financially affected amount | $0.00 | Current control summary |
| Revenue reconciliation difference | $0.00 | Rounded gross less refunds less net |
| Financial release status | READY | At the validated evaluation |

Contract cards were confirmed at their displayed whole-dollar precision:

| Contract measure | Displayed value |
| --- | ---: |
| Gross contract value | $578,009 |
| Discount amount | $14,452 |
| Expected contract revenue | $563,557 |

Their SQL reconciliation was confirmed as zero. The rounded card values are not substitutes for the underlying amounts with cents.

### 13.2 Branch comparisons

| Branch | Check-ins | Distinct visitors | Outstanding balance in historical due-date scope | Closing active members |
| --- | ---: | ---: | ---: | ---: |
| Aley Heights | 19,980 | 690 | $36,546.29 | 83 |
| Beirut Central | 20,070 | 689 | $36,398.44 | 81 |
| Jounieh Coast | 19,950 | 687 | $37,630.16 | 82 |

Distinct visitors overlap across visited branches. Their sum is not the company-wide distinct count.

Closing active members are grouped by home branch. Attendance uses the visited branch. These roles are not interchangeable.

### 13.3 Membership plan mix

| Plan | Closing active members |
| --- | ---: |
| Annual | 184 |
| Semiannual | 41 |
| Quarterly | 21 |
| Monthly | 0 |
| Total | 246 |

### 13.4 Payment failures

| Payment method | Failed attempts | Finalized attempts | Failure rate |
| --- | ---: | ---: | ---: |
| Bank transfer | 195 | 1,975 | 9.9% |
| Card | 216 | 2,641 | 8.2% |
| Cash | 187 | 1,970 | 9.5% |

Failure rates use finalized attempts as the denominator and `attempt_date_beirut` for historical filtering.

These values describe the observed synthetic results. They do not establish why payment attempts failed.

## 14. Interpretation Rules

- **Financial measures:** Contract list value, expected contract revenue, collected cash, and amounts applied to obligations are different measures. Collection rate uses net applied amount, not net collected revenue.
- **Outstanding balances:** Filtering by due date produces current obligation balances within that due-date scope. It does not reconstruct balances as they stood on a historical date.
- **Membership snapshots:** Membership measures use an appropriate latest snapshot on or before the selected date. Expiration counts represent contracts, not necessarily unique people.
- **Branch roles:** Home, financial ownership, visited, and payment processing branches represent different business roles and must be interpreted per measure.
- **Financial filter behavior:** Financial summary cards show overall control results. The severity slicer applies to the exception chart and status-history table.
- **Status history:** Historical OPEN and UNDER_REVIEW events can remain visible when the current unresolved count is zero.
- **Release readiness:** READY describes the defined financial controls at evaluation time. It does not certify every dashboard metric or all aspects of production readiness.
- **Distinct counts:** Members can visit multiple branches. Branch-level distinct visitor counts cannot be added to obtain the company-wide distinct count.
- **Synthetic data:** Patterns in this project demonstrate analytical methods and cannot be generalized to actual gym operations.

## 15. Business Findings and Suggested Follow-up

### 15.1 Renewal outreach

The closing snapshot identifies 42 contracts in the next 1–30-day expiration window and 47 in the 31–60-day window.

These groups provide a basis for renewal outreach. The counts do not predict churn or measure the effectiveness of a renewal campaign.

### 15.2 Collection follow-up

The $110,574.89 outstanding balance identifies obligations due within the historical reporting period that retain a current balance.

An ageing breakdown is needed to distinguish overdue amounts and prioritize follow-up. The total should not automatically be labelled overdue debt.

### 15.3 Payment reliability

Card attempts have the lowest displayed failure rate of the three payment methods: 8.2%, compared with 9.5% for cash and 9.9% for bank transfers.

Reason-code analysis would be needed before attributing causes or recommending a process change.

### 15.4 Branch activity

Check-in volumes are similar across the three branches. This supports demonstration of branch comparisons and filtering.

Attendance alone does not establish branch capacity, profitability, or service quality, particularly because the data is synthetic.

### 15.5 Financial reporting

The validated control summary reports zero unresolved financial exceptions and a $0.00 revenue reconciliation difference.

This supports the defined financial release result at the evaluation point. It does not eliminate the need for ongoing controls in a real operational system.

No intervention or business-performance improvement has been measured.

## 16. Evidence, Portfolio Packaging, and Remaining Work

### 16.1 Evidence and its limits

| Evidence | What it establishes | Limitation |
| --- | --- | --- |
| September SQL acceptance documents | Recorded workflow, dataset, grant, and release-gate results | Historical acceptance, not a fresh execution |
| November SQL screenshots and project-owner confirmations | Selected source-to-report numerical agreement | Does not cover every catalogue KPI |
| PBIX layout inspection | Saved pages, visual fields, selected filters, and formatting | No DAX recalculation or full relationship audit |
| Project-owner visual/export review | Owner-confirmed presentation review | PDF was not independently rendered during the file review |
| Original source ZIP comparison | Two identical archives; integrity check passed; 36 SQL and 35 Markdown files | File presence and integrity do not establish execution success |
| Revised SQL packaging checks | Revised stage ordering, script references, and package integrity checked statically | No fresh MySQL execution |
| Workbench model inspection | 21 operational tables, 25 views, 20 procedures, and 32 triggers | Model predates the ten additional analytical views and three marts |

### 16.2 Completed GitHub preparation

The project owner has confirmed completion of the following repository work:

- uploading the SQL package;
- uploading the Power BI report;
- uploading the operational ERD and Workbench model;
- uploading screenshots of all five dashboard pages;
- embedding the dashboard screenshots in the main README;
- replacing the main README with formatted project documentation;
- correcting the project owner to Daniel Andari;
- adding the repository description;
- removing the older duplicate README.

The SQL setup documentation and packaging notes distinguish the original accepted implementation from the later packaging changes.

### 16.3 Remaining checks

Before presenting the repository as a finished public portfolio:

1. Confirm that this report is saved as `GYM_MEMBERSHIP_REVENUE_ANALYTICS_PROJECT_REPORT.md` and opens from the main README link.
2. Check the README links, all five dashboard images, and downloadable Power BI and model files.
3. Confirm that obsolete duplicate reports have been removed without losing unique documentation.
4. Complete the final repository review and make the portfolio publicly accessible.

Further technical verification remains separate from publication:

- perform a clean-environment reproduction check before claiming turnkey setup;
- verify named time zones, account/role assignment, connection settings, and Power BI refresh behavior;
- complete a measure and relationship inventory;
- identify which of the 51 catalogue KPIs are displayed and independently checked;
- reconcile branch transfer measures separately against SQL, since that comparison is not recorded in the November results summarized here.

Existing loaded data does not need to be rebuilt merely to prepare documentation.

Historical SQL acceptance records remain separate from later packaging changes. No production deployment or independent validation of every KPI is claimed.

## 17. Status History

| Date | Recorded milestone |
| --- | --- |
| September 23, 2026 | SQL phase approved. Physical implementation closed under PDM-026 and SQL Analysis under SQLA-004, according to the supplied acceptance records. |
| November 12, 2026 | Five Power BI report pages built and reviewed; selected SQL-to-Power BI comparisons confirmed; portfolio documentation prepared. |
| November 16, 2026 | Revised GitHub SQL package prepared with stage-specific structural grant validation and updated validation ordering; static package checks completed. |
| November 20, 2026 | SQL package, Power BI report, operational ERD/model, and five dashboard screenshots uploaded to GitHub, as confirmed by the project owner. Main README formatting and dashboard previews updated. Report consolidation and final publication review in progress. |

Public GitHub publication and a clean-environment reproduction check are not yet confirmed.

## Project Resources

- [Main project README](README.md)
- [SQL setup instructions](sql/README.md)
- [SQL packaging changes](sql/PACKAGING_CHANGES.md)
- [Operational database diagram](gym_membership_analytics_physical_model.png)
- [Dashboard screenshots](screenshots/)

The Power BI `.pbix` file and MySQL Workbench model are available in the repository's main file list.
