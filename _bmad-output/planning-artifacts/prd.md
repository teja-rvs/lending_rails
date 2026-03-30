---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
  - step-e-01-discovery
  - step-e-02-review
  - step-e-03-edit
inputDocuments:
  - /Users/rajanavenkatasuryateja/nearform/spike/lending_rails/_bmad-output/brainstorming/brainstorming-session-2026-03-29-222900.md
documentCounts:
  productBriefs: 0
  research: 0
  brainstorming: 1
  projectDocs: 0
workflowType: 'prd'
date: '2026-03-30 19:24:19 IST'
projectName: 'lending_rails'
author: 'RVS'
initializedAt: '2026-03-30 00:35:35 IST'
completedAt: '2026-03-30 13:35:47 IST'
workflowCompleted: true
classification:
  projectType: web_app
  domain: fintech
  complexity: high
  projectContext: greenfield
workflow: 'edit'
lastEdited: '2026-03-30 21:54:44 IST'
editHistory:
  - date: '2026-03-30 21:54:44 IST'
    changes: 'Removed NFR proof-method wording such as checks, tests, tracking, and verification exercises while preserving thresholds, scope, and launch conditions for the final validation rerun.'
  - date: '2026-03-30 21:34:22 IST'
    changes: 'Rewrote measurable NFRs with explicit criteria, tightened weak FR wording, added audit-review traceability, clarified web support and accessibility minimums, and expanded fintech security expectations for the final validation pass.'
  - date: '2026-03-30 20:15:11 IST'
    changes: 'Removed remaining proof-language and borderline implementation-shaped wording from FRs and NFRs to stop repeated validation churn.'
  - date: '2026-03-30 20:07:42 IST'
    changes: 'Removed the remaining strict implementation-leakage patterns from FR and NFR language and tightened adjacent wording to reduce repeated validation churn.'
  - date: '2026-03-30 19:59:27 IST'
    changes: 'Removed remaining implementation-leakage wording from performance, security, reliability, and scalability NFRs while preserving measurable outcome targets.'
  - date: '2026-03-30 19:24:19 IST'
    changes: 'Aligned late-fee scope and journeys, added traceability and UX guidance, strengthened fintech compliance framing, rewrote weak FRs, and replaced qualitative NFRs with measurable acceptance targets.'
  - date: '2026-03-30 19:30:00 IST'
    changes: 'Made upcoming and overdue dashboard triage requirements explicit, clarified desktop-only and best-effort usability scope, and tightened lifecycle-wide integrity rules.'
---

# Product Requirements Document - lending_rails

**Author:** RVS
**Date:** 2026-03-30 21:54:44 IST

## Executive Summary

This product is a greenfield internal web application for a lending business to manage the full operational lifecycle of lending in one controlled system. It is intended for internal staff, not borrowers, and covers borrower intake, application handling, loan setup, disbursement, repayment servicing, and related operational tracking. The primary problem it solves is not just fragmented tooling, but error-prone, people-dependent lending operations that rely too heavily on manual coordination, memory, and disconnected records.

The product vision is to give the business a structured end-to-end workflow that makes daily lending operations easier to run, easier to control, and less dependent on individual operators. In the MVP, the emphasis is on operational discipline rather than breadth: explicit workflow stages, enforceable business rules, visible state transitions, connected records, and clear boundaries around editable versus locked financial actions. The expected business outcome is more reliable execution with fewer operational mistakes, with efficiency gains and lower staffing pressure emerging as downstream benefits.

### What Makes This Special

What differentiates this product is its focus on operational control as the core value proposition. Rather than acting as a passive record system or generic management dashboard, it actively reduces operational errors by guiding staff through explicit process stages and enforcing the correct order of work. It keeps critical lending entities such as borrowers, applications, loans, disbursements, payments, and invoices linked and visible in one place, which improves traceability and reduces process breakdowns caused by fragmented information.

The core insight behind the product is that lending operations fail less often when the system carries more of the workflow discipline. The product is valuable because it replaces manual coordination with structured workflow control, making the business less vulnerable to missed steps, inconsistent handling, and operator-dependent execution. This makes it better than spreadsheets or loosely structured internal tools for a business that wants tighter control over lending operations.

## Project Classification

- **Project Type:** Web application
- **Domain:** Fintech, specifically internal lending operations
- **Complexity:** High, due to financial workflows, operational controls, and future reporting/compliance expectations
- **Project Context:** Greenfield product for a specific lending business
- **Primary MVP Surface:** Internal admin-facing application
- **Primary Product Promise:** Fewer operational errors in lending operations

## Success Criteria

### User Success

Internal staff can use the product as the primary daily operating system for borrower creation, application handling, upcoming-payment follow-up, overdue-payment follow-up, and borrower-history review before approval instead of relying on memory, manual coordination, or non-digital tracking. For MVP, user success means staff can complete borrower creation and application creation entirely within the product in every happy-path acceptance scenario and can identify upcoming and overdue repayments without separate tracking.

The key user relief moment is that admins no longer need to manually calculate repayment obligations, remember follow-ups, or reconstruct borrower history from informal records. The "aha" moment is that the system surfaces applications needing action, loans with upcoming payments, overdue repayments, and borrower history clearly enough for same-day operational follow-up.

### Business Success

The business succeeds if it replaces undocumented manual handling with a controlled digital workflow for the core lending loop. In the first 90 days after launch, the key success signal is that the business can create applications, disburse loans, and manage upcoming, overdue, and late-fee-adjusted repayment states entirely within the product for 30 consecutive operating days without reverting to external shadow tracking for core lending state.

A broader business success outcome is that the full flow of money becomes trackable in one system of record with zero reconciliation mismatches across approved amount, charges, net disbursement, scheduled repayment, completed payments, late fees, and outstanding balance for the MVP validation dataset. Since there are no immediate expansion goals until the invested amount is returned, early business success should be judged by operational control and reliable execution rather than scale.

### Technical Success

The MVP is technically successful if financial data is accurate enough for the product to serve as the authoritative operational record. Payment calculations must be correct for supported cases, upcoming and overdue payments must be surfaced automatically, late fees must be applied once per overdue installment according to the approved MVP rule, and borrower, application, loan, disbursement, and payment records must remain linked and internally consistent with zero reconciliation mismatches in the MVP validation dataset.

The next most important technical outcome is auditability. The system must preserve enough history and traceability for staff to review approvals, disbursements, payment completions, overdue changes, and late-fee application without external shadow tracking during the prior 30 consecutive operating days of MVP operation.

### Measurable Outcomes

- Internal staff can complete borrower creation and application creation entirely within the product in 100% of user acceptance test scenarios for the MVP happy path.
- Loan disbursement can be completed and recorded within the product with zero reconciliation mismatches between approved amount, charges, net disbursement, and generated repayment schedule in user acceptance testing.
- Upcoming payments due within the next 7 calendar days are surfaced automatically by the system and exposed through dashboard triage with 100% agreement to the underlying due-date data in pre-release reconciliation checks.
- Overdue payments are identified automatically when an installment passes its due date unpaid and are exposed through dashboard triage with 100% agreement to the underlying due-date data in pre-release reconciliation checks.
- Late fees, when applicable, are applied once per overdue installment according to the approved MVP late-fee amount and shown as separate repayment charges in 100% of overdue-payment acceptance test scenarios.
- Borrower history is available in-system before approval decisions in 100% of application review acceptance test scenarios.
- The business can track disbursed amount, total scheduled repayment, total paid, total late fees, and outstanding balance for every active loan inside the product with zero reconciliation mismatches in the MVP test dataset.
- Core lending operations can be run for 30 consecutive operating days after launch without separate non-digital tracking for application state, loan state, payment state, or overdue follow-up.

## Product Scope

### MVP - Minimum Viable Product

The MVP must be complete enough to support the core lending loop end to end in a maintained digital system of record. That includes borrower-first intake, application creation, application processing, borrower history visibility for approval decisions, loan setup, disbursement handling, automatic payment schedule generation, payment tracking, automatic overdue identification, one flat late-fee rule per overdue installment, dashboard-driven visibility into upcoming and overdue payments, and money tracking across the system.

This is intentionally a workflow-complete MVP rather than a narrow feature slice, because the business currently has no maintained digital records. The MVP is successful only if it can carry the real operational flow, not just parts of it.

### Explicit MVP Exclusions

- No notifications
- No exports
- No borrower portal
- No settings UI
- No in-app user management beyond the single administrator access model

### Growth Features (Post-MVP)

There are intentionally no major expansion features planned immediately after launch. The post-MVP priority is to operate the system successfully until the invested amount is returned. Any near-term work after launch should focus on stabilization, validation of financial accuracy, and confidence in the digital operating model before new functional expansion is introduced.

### Vision (Future)

The longer-term vision is to begin by lending within very close circles and then expand to a broader set of users once the operating model has proven reliable. That future state would require more checks, stronger controls, and potentially additional review or compliance-oriented mechanisms to support broader lending safely.

## User Journeys

### Persona: Admin Operator

For MVP, the system has one internal admin user who performs all lending operations. This admin logs in with email and password, manages borrowers, creates and reviews loan applications, completes loan documentation, records disbursement, monitors repayments, and updates payment completion. The admin's pain today is the lack of a maintained digital record, which creates stress around decision-making, payment follow-up, and understanding the true state of money in the system.

### Journey 1: Primary User Success Path - From Login to Disbursed Loan

The admin logs into the system with email and password and lands on the dashboard. From there, the admin finds or creates a borrower using phone number as the primary lookup method and name as a secondary lookup method. The system enforces one borrower per phone number. The admin can only create a new application when the borrower does not already have an active application or active loan. Once the application is created, the system automatically creates the fixed review steps defined for MVP, such as history checking if available, phone screening, verification, and other required steps. The admin executes these steps but does not configure or edit the workflow itself.

As the admin completes the review steps, the system makes the current stage and next valid action clear. At the decision point, the admin approves or rejects the loan application. If approved, the system automatically creates the loan with the approved details. This does not mean the loan is disbursed yet. The admin must then complete loan documentation, which is a distinct operational stage. Only after documentation is complete does the admin disburse the amount, at which point the repayment schedule is automatically generated and the loan becomes active.

This journey succeeds when the admin can move from login to borrower creation, application review, approval, loan creation, documentation, and disbursement through one controlled workflow with clear stage boundaries and no ambiguity about what happens next.

### Journey 2: Primary User High-Stress Path - Payment Follow-Up and Overdue Control

The admin starts the day by opening the dashboard and checking what needs action now. The most stressful operational need is repayment follow-up: knowing which payments are upcoming, which are overdue, and which loans require immediate attention. This is where the current manual way of working is most risky.

In the product, action-driving dashboard widgets help the admin triage work immediately. Widgets for upcoming payments, overdue payments, open loan applications, and active loans lead directly into filtered operational lists. From there, the admin can open the relevant loan or payment record and understand what needs follow-up. If a payment has been made outside the system, the admin marks that payment as complete. If a payment is not made by its due date, the system automatically marks the payment as overdue and also marks the loan as overdue.

When an installment first becomes overdue, the system applies the single MVP flat late fee exactly once to that installment and shows the late fee as a separate charge in the overdue payment detail view and the related loan repayment summary. The admin does not calculate or enter this penalty manually.

The emotional shift in this journey is from anxiety about missing something important to confidence that the system is surfacing the right repayment work at the right time. The journey succeeds when the admin can identify due and overdue payments quickly and act without relying on memory or separate tracking.

### Journey 3: Primary User Edge Case - Application Review and Decision Control

Not every application progresses cleanly. A borrower may have earlier lending history, a review step may raise concerns, or the application may need to be rejected. Because the review workflow is fixed for MVP, the system must make it very clear what step is active, what has already been completed, and what decision paths remain valid. Applications move through explicit statuses of `open`, `in progress`, `approved`, `rejected`, and `cancelled`. Review steps move through explicit statuses of `initialized`, `approved`, `rejected`, and `waiting for details`. Requested amount and tenure remain editable until the application reaches final approval or rejection.

The admin opens the application and sees the system-defined review stages in sequence. A history-checking step may surface previous borrower context. A phone screening or verification step may reveal concerns that prevent approval. If the application cannot proceed, the admin should still have total clarity about why it is blocked, what remains pending, or whether it should be rejected. If the application is rejected, that outcome is recorded clearly and remains part of the searchable history.

This journey succeeds when the admin never loses clarity about current review state, prior borrower context, and final application outcome.

### Journey 4: Operations and Investigation Journey - Dashboard Monitoring and Searchable Records

Throughout the day, the admin needs a fast way to understand both urgent work and overall portfolio position. The dashboard serves as the operational control surface immediately after login. It contains both action-driving widgets and summary widgets.

Action-driving widgets include upcoming payments, overdue payments, open loan applications, and active loans because they drive immediate workflow action. Summary widgets include closed loans, total disbursed amount, and total repayment because they help the admin understand business status at a glance. Clicking any widget opens the corresponding filtered list.

All lists must be searchable using the record number shown for each application, loan, and payment, while borrowers remain searchable by phone number or name. This allows the admin to move quickly from a high-level dashboard signal into a precise investigation path. The admin may click overdue payments, land on the filtered list, search for a record, and inspect the linked borrower, application, loan, and payment history needed to understand the situation.

In the same investigation flow, the admin can review the audit trail for approvals, disbursements, payment completions, overdue changes, and late-fee actions to confirm who performed each action and when it occurred.

This journey succeeds when the dashboard, searchable lists, and audit history make the system feel like a live operational control panel rather than a passive database.

### Journey 5: Loan Completion Journey - From Active Loan to Closed Loan

Once a loan is disbursed, the system enters repayment tracking mode. Payments are automatically generated based on the approved loan setup and disbursement details. Supported repayment frequencies are `weekly`, `bi-weekly`, and `monthly`. Interest is defined using either an interest rate or a total interest amount, but not both. Full payments only are supported in MVP. Over time, the admin records completed payments when they are made outside the system, and the system continuously evaluates due dates to determine whether any payment has become overdue.

As payments are completed, the loan state updates accordingly. When all generated payments are paid, the loan is automatically closed for MVP. There is no separate manual closure workflow unless introduced in a later phase.

This journey succeeds when the admin can trust that active, overdue, and closed loan states accurately reflect repayment reality and that the product manages the final lifecycle transition automatically.

### Journey Requirements Summary

These journeys reveal the need for the following capability areas:

- Email-and-password admin login
- Dashboard as the primary post-login landing page
- Borrower creation and lookup
- Loan application creation under a borrower
- Automatic creation of fixed, system-defined application review steps
- Controlled application progression with approve and reject outcomes
- Borrower history visibility during review
- Automatic loan creation after application approval
- Distinct loan documentation stage before disbursement
- Disbursement as the financial event that activates repayment tracking
- Automatic repayment generation after disbursement
- Action-driving dashboard widgets for upcoming payments and overdue payments
- Manual payment completion updates for payments made outside the system
- Payment completion with payment date and payment mode
- Automatic overdue marking for payments past due date
- Single flat late-fee application for overdue installments, shown as a separate repayment charge
- Automatic loan overdue status when repayment is overdue
- Automatic loan closure when all payments are completed
- Action-driving dashboard widgets for open loan applications and active loans
- Summary widgets for closed loans, total disbursed amount, and total repayment
- Filtered, searchable lists for all key record types
- Search by borrower phone number or name and by the visible record number for each application, loan, and payment
- Linked record visibility across borrower, application, loan, payments, and invoices
- Audit-trail review for critical decision and money-state events
- Generic document upload and reupload handling

### Traceability Overview

| Objective or Journey | Primary FR Coverage | Key Supporting NFR Focus |
| --- | --- | --- |
| Daily digital lending loop from login to disbursement | `FR1-FR39` | Performance, Reliability |
| Repayment follow-up, overdue control, and late-fee handling | `FR40-FR58` | Performance, Reliability |
| Application review clarity and borrower decision support | `FR15-FR29`, `FR8`, `FR22` | Reliability, UX/UI Requirements |
| Dashboard-led operational investigation, search, and audit review | `FR57-FR69` | Performance, Accessibility, Security |
| System-of-record integrity and post-money control | `FR67-FR77` | Security, Reliability, Data Management and Recovery |

## Domain-Specific Requirements

### Compliance & Regulatory

For MVP, the product should prioritize internal financial controls and audit readiness rather than external compliance integrations or regulatory automation. The system must preserve an audit trail for critical operational and financial actions so that important decisions and money movements can be reviewed later.

Records are never deleted. Historical lending data must remain searchable and available for review, including applications, loans, disbursements, repayments, overdue states, and closure outcomes. The audit trail should capture who performed each key action and when it occurred, even if MVP begins with a single admin user.

### Compliance Matrix

The MVP should make its fintech compliance boundaries explicit so downstream design and implementation do not assume broader regulated coverage than the product actually provides.

- **Internal financial controls and auditability:** In scope for MVP. The product must preserve traceable records, audit history, immutable post-money records, and clear accountability for operational actions.
- **PCI-DSS card-data handling:** Out of scope for MVP because the product does not accept, process, or store card payments.
- **AML/KYC automation:** Out of scope for MVP. Manual identity, risk, and approval checks may still be required by the business, and any decision taken through that process must be captured through the application review workflow and audit trail.
- **Consumer privacy-rights automation:** Out of scope for MVP. Borrower data access must still be restricted to authenticated admin access, protected in transit, and visible through audit history when materially changed.
- **Formal certification programs such as SOC 2:** Not a release gate for MVP. However, access control, audit logging, backup verification, and record integrity requirements should be written in a way that supports future control maturity.

### Security Architecture Expectations

The MVP security model shall assume authenticated internal use only, encrypted transport for all credentials and lending data, encrypted-at-rest storage for production lending data where supported by the chosen hosting environment, daily recoverable backups, and auditable change history for critical operational and financial events. Administrative credentials, backup access, and production-data access shall remain restricted to authorized operators only.

Audit and lending history needed to review approvals, disbursements, payment completions, overdue transitions, late-fee applications, and closure events shall remain available inside the product for at least the prior 30 consecutive operating days of MVP operation. Export tooling for audit data is out of scope for MVP, but the retained in-product history shall be sufficient for operational review.

### Technical Constraints

Anything related to money must be correct. This is the most important technical domain rule for MVP. Loan setup values, disbursed amounts, repayment schedules, payment completion, overdue marking, total repayment, and loan closure logic must be internally consistent and derived reliably from recorded data.

The system must distinguish clearly between pre-money stages and post-money stages. Before disbursement, loan data can still be prepared and finalized. Once a loan is disbursed, the relevant financial record becomes non-editable in MVP. Likewise, once a payment is marked complete, that payment record becomes non-editable. This reduces finance risk by preventing silent mutation of committed financial history.

Derived lifecycle states should be system-controlled wherever possible. Upcoming payments, overdue payments, overdue loan state, and loan closure should result from recorded facts and due dates, not manual toggles by the admin. Supported repayment frequencies are weekly, bi-weekly, and monthly. The system should support interest input by rate or total interest amount, but not both for the same loan. Full payments only are supported in MVP.

Borrower information should be snapshotted onto applications and loans so later borrower edits do not rewrite historical decision context. Generic document handling should preserve rejected uploads and treat reuploads as the latest active version rather than overwriting historical context.

These integrity rules apply from the first workflow that creates or transitions the relevant records, not as a later-stage portfolio concern. Snapshotting must take effect when applications and loans are created, and derived-state controls must govern repayment, overdue, and closure behavior as soon as those states exist in the system.

### Integration Requirements

There are no external integrations in MVP. The product should operate as a self-contained internal system, with admins manually recording operational events that happen outside the product. This includes marking payments complete after they are received outside the system.

Because there are no bank, payment gateway, or accounting integrations in MVP, the manual entry flows must still preserve correctness, traceability, and accountability. Manual recording is acceptable only if the product remains the trusted source of truth for the business.

### Fraud Prevention & Abuse Controls

The MVP does not require automated fraud scoring, sanctions screening, or identity-network analysis. It should still include clear product-level controls that reduce avoidable fraud and abuse risk in an internal lending workflow.

- Duplicate borrower creation must be blocked through unique phone-number enforcement.
- Application approval must remain gated by explicit review workflow completion and recorded decision history.
- Borrower history, prior application outcomes, and current loan exposure must be visible before approval decisions.
- Disbursement, repayment completion, overdue status, and late-fee application must remain auditable and non-silent so suspicious changes can be investigated later.

### Risk Mitigations

The core fintech risk for MVP is that anything related to money could be wrong. The product should mitigate this by enforcing clear workflow stages, preserving record history, locking committed financial records, and making state transitions explicit.

Specific mitigations should include:
- clear boundaries between approved, documented, disbursed, active, overdue, and closed states
- automatic repayment schedule generation from approved loan and disbursement details
- non-editable loan records after disbursement
- non-editable payment records after payment completion
- automatic overdue marking based on due dates
- automatic overdue loan state based on overdue repayments
- automatic loan closure only when all generated payments are completed
- audit trail visibility for who did what and when
- no hard deletion of records

This should reduce the risk of incorrect disbursement state, incorrect repayment state, missing historical context, and inconsistent money tracking across the lending lifecycle.

## Web Application Specific Requirements

### Project-Type Overview

This product will be delivered as a desktop-first multi-page internal web application for a single admin user. It is optimized for operational control rather than public reach, which means SEO, broad browser compatibility, and consumer-style discovery are not part of MVP scope. The application is intended to support structured lending operations through authenticated internal use in a controlled browser environment.

### Technical Architecture Considerations

The MVP should use a page-based internal web experience that takes the admin from dashboard to filtered list to record detail to action confirmation without depending on real-time updates. The first release only needs freshness on page load after navigation or refresh, not live streaming updates, and it may optimize for one authenticated administrator session at a time.

### Browser Support

| Browser | Operating Systems | MVP Support |
| --- | --- | --- |
| Google Chrome, current stable release | macOS and Windows versions used by internal staff | Supported |
| All other browsers | Any | Out of scope |

### Responsive Design

The product is desktop-only for MVP and optimized for standard laptop and desktop screen sizes used by the admin. It should support table-heavy and form-heavy operational workflows efficiently. Tablet and mobile experiences are out of scope for MVP.

### Performance Targets

The application should follow the explicit performance targets defined in the Non-Functional Requirements section. Within the web experience, the design should prioritize predictable, low-friction movement across login, dashboard, filtered lists, and detail views so the admin can complete time-sensitive lending work without hesitation.

### SEO Strategy

SEO is not required for this product because it is an authenticated internal system rather than a public-facing website or discoverable application.

### Accessibility Level

The minimum auditable accessibility target for MVP is WCAG 2.1 Level A for the core admin workflows of login, dashboard navigation, filtered lists, record detail views, application review, disbursement, and payment completion. Full WCAG 2.1 AA conformance is not a release gate for MVP, but keyboard access, visible focus state, form labels, error messaging, and status indicators for those core flows shall be verified before launch.

### UX / UI Requirements

The MVP should present a consistent operational UI pattern so the admin does not need to relearn navigation between lending tasks.

- The dashboard should be the default post-login control surface and should expose the operational widgets defined in the Functional Requirements.
- Every dashboard widget and summary metric intended for action should open the relevant filtered list without forcing the admin to rebuild the same filter manually.
- Borrower, application, loan, and payment views should follow a stable list-to-detail pattern with linked navigation between related records.
- Application, loan, payment, and overdue states should be visible as labeled statuses on both list rows and detail views.
- High-risk forms such as application review, loan setup, disbursement, and payment completion should make required fields, validation failures, and irreversible actions explicit before submission.
- Empty states, blocked states, and rejection states should tell the admin what happened, what remains pending, and what action is still valid.

### Implementation Considerations

The web application should prioritize predictable page transitions, reliable state refresh on each page load, and efficient movement between dashboard, filtered lists, and detail views. Because the system is workflow-driven and list-driven, the product should support quick operational movement across borrowers, applications, loans, and payments without requiring the admin to reconstruct context manually.

The absence of real-time behavior, broad browser support, and SEO requirements should be treated as deliberate scope boundaries that simplify MVP delivery. The design and engineering focus should stay on reliability of workflows, clarity of states, freshness of displayed operational data on each load, and correctness of financial records.

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Problem-solving MVP with workflow-complete operational coverage

The MVP is intended to prove that the business can run the core lending loop digitally and reliably instead of through informal, non-digital processes. This is not a narrow feature-validation MVP or a platform-foundation MVP. It is a fit-for-purpose operational MVP whose value comes from replacing manual lending management with a controlled system of record.

The MVP also has an experience component, especially around dashboard-driven daily operations and repayment follow-up, but that is secondary to the main goal of making the business workflow operationally viable in software.

**Resource Requirements:** A small team can build this if it protects the money-critical path first. The most important implementation and validation focus is repayment tracking accuracy, followed by disbursement correctness, lifecycle-state control, audit trail integrity, and locked post-money records.

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**
- Login to dashboard
- Borrower creation and lookup
- Loan application creation and fixed-step review flow
- Approval and rejection handling
- Automatic loan creation after approval
- Loan documentation before disbursement
- Disbursement recording
- Automatic repayment generation
- Upcoming and overdue payment monitoring
- Single flat late-fee application to overdue installments
- Manual marking of payments completed outside the system
- Automatic overdue state handling
- Automatic loan closure when payments are complete
- Dashboard-driven investigation and searchable operational lists
- Generic document handling within the lending workflow

**Must-Have Capabilities:**
- End-to-end lending workflow support from borrower creation through loan closure
- Disbursement handling as a controlled financial event
- Accurate repayment schedule generation
- Accurate repayment tracking and overdue identification
- Single flat late-fee handling that is applied consistently and shown separately from scheduled repayment
- Dashboard widgets for upcoming payments and overdue payments with filtered-list drill-in behavior
- Borrower-history visibility before approval decisions
- Action-driving dashboard views for operational awareness, especially repayment follow-up
- Searchable lists and linked records across the lending lifecycle
- Audit trail for key actions
- Non-editable records after disbursement and payment completion
- No hard deletion of records
- Explicit status models for applications, review steps, and loan lifecycle states

**Priority Stack Within MVP:**
1. Repayment calculation and repayment tracking correctness
2. Overdue derivation correctness and money-state clarity
3. Disbursement correctness and lifecycle-state locking
4. Audit trail integrity and immutable post-money records
5. Application workflow completeness
6. Dashboard visibility and operational convenience

Within dashboard scope, `upcoming payments` and `overdue payments` are the non-negotiable launch widgets and filtered-list drill-in entry points because they support the core repayment follow-up loop. Summary-only widgets such as aggregate totals are more deferrable if implementation pressure appears. The MVP can tolerate thinner management-summary visibility, but it should not launch with weak repayment follow-up visibility or uncertainty around money state.

This creates an explicit distinction between what must exist by launch and what must be correct before launch. The full workflow should exist in MVP, but money-critical behaviors carry the highest correctness burden. The MVP explicitly prioritizes clear operational state over management insight depth. If there is a trade-off, the product should favor reliable state clarity, repayment follow-up visibility, and money-state correctness over richer summary reporting.

### Post-MVP Features

**Phase 2 (Post-MVP): Stabilization and Trust-Building**
There are intentionally no major expansion bets immediately after launch. The priority after MVP is to stabilize the system, validate repayment accuracy, confirm operational trust, and use the product until the invested amount is returned. Near-term post-MVP work should focus on hardening, bug reduction, operational polish, and confidence-building rather than broad new features.

**Phase 3 (Expansion):**
Once the operating model is proven, the product can expand to support lending beyond close circles, with stronger checks and broader controls. Later phases may introduce stricter review mechanisms, broader user coverage, richer reporting, and other enhancements needed for a more mature lending operation.

### Risk Mitigation Strategy

**Technical Risks:** The biggest technical risk is payment calculation accuracy. The product must correctly generate repayment schedules, reflect current payment state, identify overdue repayments from dates and recorded facts, and maintain correct loan-state transitions across the lifecycle. This area requires the highest validation burden before release.

**Market Risks:** The main market risk is not external competition but failure to produce a system the business trusts enough to use daily. The MVP addresses this by focusing on complete workflow coverage, operational visibility, and a reliable system of record.

**Resource Risks:** The main resource risk is that the MVP surface is broad. This is mitigated by protecting the money-critical path first: disbursement, repayment generation, repayment tracking, overdue handling, auditability, and locked post-money records. If trade-offs are required, summary dashboard metrics and other secondary convenience or polish items should be sacrificed before repayment accuracy or core lifecycle control.

## Functional Requirements

### Access & Session Control

- FR1: Admin can authenticate with email and password to access the product.
- FR2: Admin can start an authenticated session and access the internal lending operations workspace.
- FR3: Admin can end their session by logging out of the product.

### Borrower Management

- FR4: Admin can create a borrower record.
- FR5: Admin can search for an existing borrower before creating a new one.
- FR6: Admin can search borrowers by phone number as the primary method and by name as a secondary method.
- FR7: System can enforce unique borrower identity by phone number.
- FR8: Admin can view borrower details and prior borrowing history in one place.
- FR9: Admin can browse borrower lists and linked application and loan lists that show the borrower name, visible record number, current status, and most recent relevant date for each row.
- FR10: Admin can create a loan application under a borrower.
- FR11: Admin can view all applications and loans associated with a borrower.
- FR12: System can prevent creation of a new application when a borrower already has an active application.
- FR13: System can prevent creation of a new application when a borrower has an active loan.
- FR14: System can allow repeat borrowing after the borrower’s active loan is closed.

### Application Management & Review

- FR15: Admin can create a loan application with the required pre-decision details: requested amount, requested tenure, requested repayment frequency, proposed interest mode, and the supporting notes or document attachments required for the active review step.
- FR16: System can create the required application review steps when a loan application is created.
- FR17: System can keep the MVP application review workflow fixed for all administrators throughout MVP operation.
- FR18: System can maintain explicit application statuses of open, in progress, approved, rejected, and cancelled.
- FR19: System can maintain explicit review-step statuses of initialized, approved, rejected, and waiting for details.
- FR20: Admin can view the current application status and the active review step.
- FR21: Admin can complete application review steps in the defined sequence.
- FR22: Admin can review borrower history while assessing an application.
- FR23: Admin can edit requested amount and tenure until the application reaches final approval or rejection.
- FR24: Admin can keep an application in progress when more details are needed.
- FR25: Admin can approve an application.
- FR26: Admin can reject an application.
- FR27: Admin can cancel an application before approval.
- FR28: System can preserve rejected and cancelled applications as searchable historical records.
- FR29: Admin can filter application lists by application status, active review-step status, and whether more details are required.

### Loan Setup, Documentation & Disbursement

- FR30: System can create a loan record when an application is approved.
- FR31: System can keep loan approval distinct from loan disbursement.
- FR32: Admin can prepare and finalize loan details before disbursement, including principal, tenure, repayment frequency, interest mode, bank details, charges, and disbursement details.
- FR33: Admin can complete loan documentation as a distinct stage after approval and before disbursement.
- FR34: System can maintain explicit loan lifecycle states of created, documentation in progress, ready for disbursement, active, overdue, and closed.
- FR35: System can transition a loan between created, documentation in progress, ready for disbursement, active, overdue, and closed based on recorded approval, documentation completion, disbursement, overdue repayment, and repayment-completion events.
- FR36: Admin can view the current lifecycle state of a loan whenever selecting or reviewing a loan record.
- FR37: Admin can filter loan lists by lifecycle state, disbursement readiness, and whether repayment follow-up is currently required.
- FR38: Admin can record loan disbursement as the event that activates the loan.
- FR39: System can create and associate a disbursement invoice record with a loan when that loan is disbursed.

### Repayment Tracking & Portfolio Control

- FR40: System can generate the repayment schedule when a loan is disbursed.
- FR41: System can support weekly, bi-weekly, and monthly repayment frequencies.
- FR42: Admin can define loan interest using either an interest rate or a total interest amount, but not both.
- FR43: System can support full-payment repayment handling for MVP.
- FR44: Admin can view a dashboard widget and filtered list of payments due in the next 7 calendar days.
- FR45: Admin can view a dashboard widget and filtered list of payments that are past due and not marked completed.
- FR46: Admin can view the current repayment state of a loan.
- FR47: Admin can filter payment lists by pending, paid, and overdue repayment states.
- FR48: Admin can mark a payment as completed when payment is received outside the system.
- FR49: Admin can record payment date and payment mode when marking a payment as completed.
- FR50: System can create and associate a payment invoice record when a payment is marked completed.
- FR51: System can determine when a payment has become overdue based on due dates and recorded payment state.
- FR52: System can apply the single business-approved MVP flat late fee exactly once to an installment when it first becomes overdue.
- FR53: Admin can distinguish the late fee from scheduled repayment amounts when reviewing an overdue installment or the affected loan balance.
- FR54: System can mark a loan as overdue when at least one generated payment for that loan is overdue.
- FR55: System can close a loan when all generated payments are completed.
- FR56: Admin can view, for each loan, the disbursed amount, total scheduled repayment, total paid to date, total late fees assessed, and outstanding balance within the product.

### Dashboard, Search & Operational Investigation

- FR57: Admin can access a dashboard that displays widgets for upcoming payments, overdue payments, open loan applications, and active loans, plus summary metrics for closed loans, total disbursed amount, and total repayment amount.
- FR58: Admin can use dashboard entry points for upcoming payments and overdue payments to navigate directly to repayment follow-up work.
- FR59: Admin can view open or in-progress loan applications that still have an incomplete active review step.
- FR60: Admin can view active loans.
- FR61: Admin can view closed loans.
- FR62: Admin can view total disbursed amount.
- FR63: Admin can view total repayment amount.
- FR64: Admin can open the relevant filtered record list directly from each dashboard widget or summary metric intended for operational investigation.
- FR65: Admin can search borrowers by phone number or name, and can search applications, loans, and payments by the record number shown for each item.
- FR66: Admin can investigate linked borrower, application, loan, disbursement, payment, and invoice records from within the product.

### Record Integrity, Auditability & Control

- FR67: System can maintain linked records across borrowers, applications, loans, disbursements, payments, and invoices.
- FR68: System can preserve an audit trail for borrower creation, application updates, approval and rejection decisions, disbursement, payment completion, overdue marking, late-fee application, and loan closure.
- FR69: System can record who performed each auditable action and when it occurred.
- FR70: System can prevent permanent removal of operational and financial records.
- FR71: System can prevent editing of loan records after disbursement.
- FR72: System can prevent editing of payment records after payment completion.
- FR73: System can derive active, overdue, and closed loan lifecycle states from recorded disbursement, due-date, and payment-completion facts.
- FR74: System can preserve the borrower details associated with each application and loan for historical integrity, even if the borrower profile changes later.
- FR75: Admin can upload generic documents to lending records.
- FR76: System can preserve rejected document uploads and treat reuploads as the latest active version.
- FR77: System can limit MVP access to one administrator account.

## Non-Functional Requirements

### Performance

- The product shall complete login, dashboard load, borrower search, filtered list load, and opening borrower, application, loan, and payment records within 2 seconds in at least 95 of 100 observed interactions under MVP launch conditions with one active administrator session and the supported launch dataset.
- Searches for borrowers, applications, loans, and payments shall surface matching results within 1 second in at least 95 of 100 observed interactions under MVP launch conditions with one active administrator session and the supported launch dataset.
- After any successful update, the related operational data shall appear in its correct current state within 2 seconds across borrower, application, loan, payment, invoice, and late-fee workflows under the supported MVP launch conditions.

### Security

- The product shall restrict lending data and protected operational screens to authenticated sessions only across login, dashboard, filtered-list, detail-view, and action workflows in every MVP environment that handles representative lending data.
- Administrator passwords shall never be stored or retrievable in plain text before launch or during MVP operation, including after any material authentication change.
- All traffic carrying credentials or lending data shall use encrypted transport meeting current industry-accepted standards in every MVP environment that handles live or representative lending data.
- Idle authenticated sessions shall expire after 30 minutes of inactivity and require re-authentication before further protected actions across the core admin workflows in every MVP environment that handles representative lending data.
- Create, update, approval, rejection, disbursement, payment-completion, overdue, late-fee, and loan-closure events shall each create an audit entry with actor and timestamp within 5 seconds of the event across the supported MVP workflows.

### Reliability

- The product shall maintain 99% uptime per calendar month during business hours from 08:00 to 20:00 local time, excluding announced maintenance windows, in the production MVP environment.
- Borrower, application, loan, payment, invoice, and late-fee records shall match the authoritative stored state within 2 seconds of a successful update across the supported MVP workflows.
- Principal, charges, late fees, scheduled repayment, completed payments, overdue status, and closure status shall remain internally consistent with zero unreconciled mismatches throughout supported MVP operation on the supported MVP dataset.
- Disbursed loans and completed payments shall remain non-editable throughout the supported MVP workflows after those records reach their locked state.
- The product shall preserve authoritative application, loan, payment, overdue, and late-fee history for at least the prior 30 consecutive operating days so staff can reconstruct current lending state without external shadow tracking.

### Scalability

- The MVP shall maintain the stated performance targets with one active administrator session and a supported launch dataset of at least 5,000 borrowers, 5,000 applications, 2,000 active loans, and 25,000 payments.
- The MVP shall support exactly one authenticated administrator session at a time during launch operations in the production-ready launch configuration.
- Overdue status shall reflect the correct state within 5 minutes of an installment becoming overdue under the supported MVP launch dataset and one active administrator session.

### Data Management and Recovery

- At least one recoverable production-data backup shall be completed for each business day of MVP operation.
- The most recent verified backup shall be restorable within 4 business hours throughout MVP operation.
