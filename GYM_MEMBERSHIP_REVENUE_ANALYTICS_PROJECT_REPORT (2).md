# Gym Membership & Revenue Analytics

## Portfolio Project Report

| Field | Value |
|---|---|
| Project owner | Daniel Andari |
| Primary tools | MySQL 8.0, MySQL Workbench 8.0, Power BI |
| Current version | 1.1 — Power BI Review and Portfolio Preparation (2026-11-12) |
| Reporting currency | USD |
| Business scope | Beirut, Aley, and Jounieh |
| Analysis period | 2023-09-01 through 2026-08-31 |
| Current status | SQL phase accepted; five Power BI pages built and reviewed; publication preparation in progress |

## 1. Executive Summary

This portfolio project develops a controlled analytics solution for a fictional
Lebanese gym company operating in Beirut, Aley, and Jounieh. The solution
consolidates membership, branch, check-in, payment, obligation, refund, and
financial-exception data into a validated MySQL analytical source for Power BI.

The archived SQL acceptance records describe the SQL phase as complete. The implemented system contains a normalized
21-table operational model, protected historical workflows, a deterministic
36-month synthetic dataset, curated reporting views, ten analytical views, and
three indexed analytical marts. Functional, security, reconciliation, and
release-readiness controls passed. The canonical final release gate returned
eight controls passed, zero failed, and `READY`.

## 2. Business Problem

Membership, payment, and check-in records are fragmented across branches and
are not interpreted using consistent business definitions. Management lacks a
reliable view of membership growth, collected revenue, collection gaps,
outstanding balances, failed payments, refunds, plan performance, expirations,
and branch-level engagement.

The project addresses this problem by providing one governed analytical source
whose totals reconcile across company, branch, plan, and reporting-period
breakdowns.

## 3. Stakeholders and Decisions

| Stakeholder | Decisions supported |
|---|---|
| General Manager | Growth, branch performance, plan strategy, and investment priorities |
| Finance Manager | Collections, balances, failed payments, refunds, and reconciliation |
| Membership Manager | Acquisition, renewals, expirations, freezes, and cancellations |
| Branch Managers | Local performance, payment risk, and member engagement |

The approved baseline contains 15 business requirements, 29 business rules,
and 51 KPIs. Every requirement and KPI has an approved SQL source path.

## 4. Project Scope

The dataset represents 36 months of fictional operational history across three
Lebanese branches. It covers:

- members, membership plans, and effective-dated plan versions;
- contracts, renewals, reactivations, freezes, cancellations, and expirations;
- home-branch assignments and check-in activity;
- expected revenue, discounts, payment obligations, attempts, payments, and allocations;
- refunds, refund allocations, outstanding balances, and overdue ageing;
- financial exceptions, auditability, reporting eligibility, and release readiness.

The solution does not claim causal retention analysis, marketing attribution,
staff performance, predictive modelling, or real customer behavior.

## 5. Data Architecture

### 5.1 Operational layer

The normalized MySQL model contains:

| Component | Implemented total |
|---|---:|
| Tables | 21 |
| Active fields | 131 |
| Primary-key constraints | 21 |
| Unique constraints | 24 |
| Foreign-key constraints | 27 |
| Supporting indexes | 14 |
| History-protection triggers | 32 |
| Controlled procedures | 20 |
| Validation and reporting views | 25 |

All foreign keys use restrictive referential actions. Financial values use
exact `DECIMAL(12,2)` storage. Business dates use `DATE`, while event timestamps
use UTC `DATETIME(6)` with controlled Beirut reporting conversion.

### 5.2 Analytical layer

The approved Power BI source layer contains:

| Component | Implemented total |
|---|---:|
| `vw_analysis_*` views | 10 |
| Frozen analytical output columns | 178 |
| Indexed analytical marts | 3 |
| Analyst view Select grants | 19 |
| Analyst base-table grants | 0 |
| Audit Select grants | 59 |

The analytical layer supports membership, contract, snapshot, payment-attempt,
obligation-activity, refund, branch, plan, and date analysis without granting
Power BI access to operational base tables.

## 6. Data Quality and Business Controls

The design protects historical and financial accuracy through named
constraints, controlled procedures, append-only triggers, reconciliation
views, and release gates. Important controls include:

- preservation of historical plan prices and branch assignments;
- prevention of overlapping effective-dated records;
- controlled membership and payment status transitions;
- duplicate check-in identification without destroying raw evidence;
- one eligible successful attempt per funded payment path;
- allocation ceilings and exact payment reconciliation;
- refund ceilings, allocation reversal, and obligation reopening;
- exclusion of unresolved critical financial sources from approved reporting;
- separate gross revenue, discounts, refunds, and net collected revenue;
- explicit financial release-readiness disclosure.

## 7. Synthetic Dataset

The deterministic dataset covers 2023-09-01 through 2026-08-31, with an
opening anchor on 2023-08-31 and a 60-day planning horizon through 2026-10-30.
It is denominated in USD and includes all three approved branches. The
independent dataset validator passed its integrity, completeness, time-period,
and financial-reconciliation controls.

## 8. Testing and Validation — Archived SQL Acceptance

### 8.1 Functional testing

| Test batch | Automated checks | Result |
|---|---:|---|
| Membership, obligations, and valid check-in | 8 | PASS |
| Payment failure, retry, collection, and allocation | 9 | PASS |
| Refund and obligation reopening | 10 | PASS |
| Financial-exception workflow and release gate | 11 | PASS |
| Negative and history-protection controls | 11 | PASS |
| **Total** | **49** | **PASS** |

### 8.2 Final SQL acceptance

| Acceptance control | Result |
|---|---|
| Physical schema and metadata | PASS |
| Trigger and procedure behavior | PASS |
| Reporting and analytical views | PASS |
| Synthetic dataset validation | PASS |
| Financial reconciliation | PASS |
| Role and grant boundary | PASS |
| Analytical marts populated and keyed | PASS |
| Final release gate | 8/8 PASS; `READY` |

The original full and deep analytical validators exposed a MySQL 8.0 for
Windows internal `#sql` temporary-table failure during repeated expansion of
the largest views. Completed controls proved that this was an engine execution
path issue rather than a data, security, reconciliation, or business-rule
failure. The approved lightweight `99c_validate_final_release_gate.sql` is the
canonical final validator.

## 9. Security Model

The design separates schema ownership, application writes, analyst/Power BI
reads, and audit review. The `gym_analyst_powerbi` role receives read-only
access to approved views and no base-table access, operational DML,
write-procedure execution, Grant Option, or embedded credential. The audit role
has the broader read-only coverage required to verify controlled evidence.

## 10. SQL Deliverables

The controlled SQL package includes:

- schema, table, key, index, trigger, view, procedure, and role creation scripts;
- disposable functional-test environment and five workflow test batches;
- deterministic synthetic-data generation;
- ten analytical views and three analytical marts;
- structural, behavioral, security, dataset, and analytical validators;
- the canonical final release gate;
- business requirements, KPI rules, data models, traceability records, and review reports.

## 11. SQL Phase Outcome

Phases 1–8 produced a trusted and documented MySQL source for business
intelligence. The solution preserves all approved business definitions,
supports all 15 requirements and 51 KPIs, reconciles financial values, and
enforces a least-privilege Power BI boundary. The September acceptance record reported no unresolved SQL implementation,
integrity, reconciliation, or release issue. The later source-package setup
review identified the execution-order documentation issue recorded in Section 16.

## 12. Power BI Implementation and Review

Five report pages have been built: Executive Overview, Membership Analysis,
Revenue & Collections, Attendance & Branches, and Financial Controls. The
report uses MySQL views through Power Query, dimension/fact relationships,
DAX measures, branch/date slicers, and financial control summaries.

During the November review, selected KPI outputs were compared with SQL.
Monthly charts were changed to use `Dim_Date[month_start_date]` directly,
removing the categorical scrolling that hid later months. Saved report settings
confirmed historical date slicers on Overview and Attendance, visual-level
obligation due-date and payment-attempt filters, exact attendance labels,
and the Financial Exception Status History title. All five page definitions
were present in the supplied PBIX. The user reported completion of the final
axis-label adjustment and visual/export review.

The file inspection did not render the PDF or execute the embedded model.
It does not establish that every measure or relationship is independently
correct. The newer PBIX upload was also checked for the five-page inventory.

## 13. Selected SQL-to-Power BI Comparisons

Unless otherwise noted, historical dates cover 2023-09-01 inclusive through
2026-09-01 exclusive. These figures come from comparisons supplied and
confirmed during the review, not a new database execution performed for this
report.

| Metric | Confirmed result | Definition / context |
|---|---:|---|
| Total membership contracts | 3,500 | Distinct membership contract IDs |
| Closing active members | 246 | Closing snapshot, 2026-08-31 |
| Closing active membership contracts | 246 | Closing snapshot, 2026-08-31 |
| Expiring contracts, 1–30 days | 42 | Distinct flagged contracts at selected latest snapshot |
| Expiring contracts, 31–60 days | 47 | Distinct flagged contracts at selected latest snapshot |
| Gross collected revenue | $425,637.73 | Eligible collections in historical transaction period |
| Total refunds | $2,074.61 | Historical transaction period |
| Net collected revenue | $423,563.12 | Gross collections less refunds |
| Net applied amount | $424,922.30 | Obligation collection-rate numerator |
| Collectible obligation amount | $535,497.19 | Obligation collection-rate denominator |
| Collection rate | 79.35% | Net applied / collectible amount |
| Outstanding balance, historical due-date scope | $110,574.89 | Current balances on obligations due in reporting period |
| Outstanding balance, all dates | $129,334.60 | Includes obligations outside historical due-date scope |
| Total check-ins | 60,000 | Historical attendance period |
| Distinct checked-in members | 1,000 | Company-wide distinct count |
| Total financial exceptions | 20 | Overall control summary |
| Unresolved financial exceptions | 0 | Current control summary |
| Financially affected amount | $0.00 | Current control summary |
| Revenue reconciliation difference | $0.00 | Rounded gross less refunds less net |
| Financial release status | READY | At the validated evaluation |

Contract cards were confirmed at their displayed whole-dollar precision:
gross contract value $578,009; discount amount $14,452; expected contract
revenue $563,557. Their SQL reconciliation was confirmed as zero. Those
rounded card values are not a substitute for source amounts with cents.

### Branch and plan detail

| Branch | Check-ins | Distinct visitors | Outstanding balance in historical due-date scope | Closing active members |
|---|---:|---:|---:|---:|
| Aley Heights | 19,980 | 690 | $36,546.29 | 83 |
| Beirut Central | 20,070 | 689 | $36,398.44 | 81 |
| Jounieh Coast | 19,950 | 687 | $37,630.16 | 82 |

Distinct visitors overlap across visited branches. Their sum is not the
company-wide distinct count. Closing active members by plan were Annual 184,
Semiannual 41, Quarterly 21, and Monthly 0.

| Payment method | Failed attempts | Finalized attempts | Failure rate |
|---|---:|---:|---:|
| Bank transfer | 195 | 1,975 | 9.9% |
| Card | 216 | 2,641 | 8.2% |
| Cash | 187 | 1,970 | 9.5% |

Failure rates use finalized attempts as the denominator and
`attempt_date_beirut` for historical filtering. These values do not explain
why failures occurred.

## 14. Interpretation Rules

- Contract list value, expected contract revenue, collected cash, and amounts
  applied to obligations are different measures. Collection rate must not use
  net collected revenue in place of the net applied amount.
- Outstanding balances filtered by due date are current obligation balances
  within that due-date scope, not reconstructed historical as-of balances.
- Membership measures use an appropriate latest snapshot on or before the
  selected date. Expiration counts represent contracts, not necessarily unique
  people.
- Home, financial ownership, visited, and processing branches represent
  different business roles and must be documented per visual/measure.
- Financial summary cards show overall control results. The severity slicer
  applies to the exception chart and status-history table.
- Historical OPEN and UNDER_REVIEW events can remain visible when the current
  unresolved count is zero. Event history must not be mistaken for current
  exception status.
- READY describes the defined financial controls at evaluation time; it does
  not certify every dashboard metric or all aspects of production readiness.

## 15. Business Findings and Suggested Follow-up

The closing expiration windows identify 42 contracts in 1–30 days and 47 in
31–60 days for potential renewal outreach. The $110,574.89 outstanding balance
provides a collection-follow-up population; an ageing breakdown would be
needed to distinguish overdue amounts and prioritize action. Card attempts
have the lowest displayed failure rate of the three methods, but reason-code
analysis is required before attributing causes or recommending a process change.

Branch check-in volumes are similar. This demonstrates branch comparison and
filtering, but the data is synthetic and should not be used to infer real gym
capacity, profitability, or customer behavior. No intervention or business
improvement has been measured.

## 16. Evidence and Remaining Publication Work

| Evidence | What it establishes | Limitation |
|---|---|---|
| September SQL acceptance documents | Prior user-approved workflow, dataset, grants, and release-gate results | Historical acceptance, not a fresh run |
| November SQL screenshots and user confirmations | Selected source-to-report numerical agreement | Does not cover every catalogue KPI |
| PBIX layout inspection | Saved pages, visual fields, selected filters and formatting | No DAX recalculation or full relationship audit |
| User visual/export review | User-confirmed presentation review | PDF was not independently rendered here |
| Source ZIP comparison | Two identical archives; integrity check passed; 36 SQL and 35 Markdown files | Presence is not execution success |
| Workbench model inspection | 21 operational tables, 25 views, 20 procedures, 32 triggers | Model predates ten analytical views and three marts |

Before public release:

1. Assemble repository folders, five clean dashboard previews, the PBIX, and
   the ERD/model. Preserve historical design reviews separately from current
   documentation.
2. Reconcile setup instructions with the actual script dependencies. The
   structural master `99_build_all.sql` invokes `97_validate_roles_grants.sql`,
   whose audit count expects 59 objects after the analytical extension; that
   expectation is not appropriate at the structural-only stage. The same
   validator must be reviewed for stage-specific analyst grant expectations.
   No SQL behavior was changed in this documentation update.
3. Document MySQL named time-zone availability for Asia/Beirut, account/role
   assignment, the local connection settings, and Power BI refresh requirements.
   Perform a clean-environment reproduction check before claiming turnkey setup.
4. Finish a measure/relationship inventory and identify which of the 51
   catalogue KPIs are displayed and independently checked. Branch transfer
   measures are displayed but a separate SQL reconciliation is not recorded
   in the November comparisons summarized here.
5. Review the final publication package and publish the GitHub repository.

Existing loaded data does not need to be rebuilt for documentation preparation.
The archived SQL package remains unchanged. This update revises the project
status and adds Power BI evidence; it does not retroactively alter the SQL
acceptance record.

## 17. Status History

The SQL phase was approved on 2026-09-23. Phase 7 physical implementation is
closed under PDM-026 and Phase 8 SQL Analysis under SQLA-004 according to the
supplied acceptance records. By 2026-11-12, five Power BI report pages had been
built and reviewed, selected SQL-to-Power BI comparisons confirmed, and the
source archive recovered. Portfolio documentation and publication preparation
are in progress. Public GitHub publication is not yet confirmed.
