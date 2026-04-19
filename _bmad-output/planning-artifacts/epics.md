---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
workflowCompleted: true
inputDocuments:
  - /Users/rajanavenkatasuryateja/nearform/spike/lending_rails/_bmad-output/planning-artifacts/prd.md
  - /Users/rajanavenkatasuryateja/nearform/spike/lending_rails/_bmad-output/planning-artifacts/architecture.md
  - /Users/rajanavenkatasuryateja/nearform/spike/lending_rails/_bmad-output/planning-artifacts/ux-design-specification.md
---

# lending_rails - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for lending_rails, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: Admin can authenticate with email and password to access the product.
FR2: Admin can start an authenticated session and access the internal lending operations workspace.
FR3: Admin can end their session by logging out of the product.
FR4: Admin can create a borrower record.
FR5: Admin can search for an existing borrower before creating a new one.
FR6: Admin can search borrowers by phone number as the primary method and by name as a secondary method.
FR7: System can enforce unique borrower identity by phone number.
FR8: Admin can view borrower details and prior borrowing history in one place.
FR9: Admin can browse lists of borrowers and borrower-linked records.
FR10: Admin can create a loan application under a borrower.
FR11: Admin can view all applications and loans associated with a borrower.
FR12: System can prevent creation of a new application when a borrower already has an active application.
FR13: System can prevent creation of a new application when a borrower has an active loan.
FR14: System can allow repeat borrowing after the borrower's active loan is closed.
FR15: Admin can create a loan application with the required pre-decision loan details.
FR16: System can create the required application review steps when a loan application is created.
FR17: System can keep application review steps fixed and system-defined for MVP.
FR18: System can maintain explicit application statuses of open, in progress, approved, rejected, and cancelled.
FR19: System can maintain explicit review-step statuses of initialized, approved, rejected, and waiting for details.
FR20: Admin can view the current application status and the active review step.
FR21: Admin can complete application review steps in the defined sequence.
FR22: Admin can review borrower history while assessing an application.
FR23: Admin can edit requested amount and tenure until the application reaches final approval or rejection.
FR24: Admin can keep an application in progress when more details are needed.
FR25: Admin can approve an application.
FR26: Admin can reject an application.
FR27: Admin can cancel an application before approval.
FR28: System can preserve rejected and cancelled applications as searchable historical records.
FR29: Admin can browse lists of applications based on workflow state and operational need.
FR30: System can create a loan record when an application is approved.
FR31: System can keep loan approval distinct from loan disbursement.
FR32: Admin can prepare and finalize loan details before disbursement.
FR33: Admin can complete loan documentation as a distinct stage after approval and before disbursement.
FR34: System can maintain explicit loan lifecycle states of created, documentation in progress, ready for disbursement, active, overdue, and closed.
FR35: System can transition a loan through its lifecycle states based on recorded business events.
FR36: Admin can view the current lifecycle state of a loan clearly.
FR37: Admin can browse lists of loans based on lifecycle state and operational need.
FR38: Admin can record loan disbursement as the event that activates the loan.
FR39: System can auto-generate a disbursement invoice when a loan is disbursed.
FR40: System can generate the repayment schedule when a loan is disbursed.
FR41: System can support weekly, bi-weekly, and monthly repayment frequencies.
FR42: Admin can define loan interest using either an interest rate or a total interest amount, but not both.
FR43: System can support full-payment repayment handling for MVP.
FR44: Admin can view upcoming payments as an action-driving repayment follow-up view.
FR45: Admin can view overdue payments as an action-driving repayment follow-up view.
FR46: Admin can view the current repayment state of a loan.
FR47: Admin can browse lists of payments based on repayment state and operational need.
FR48: Admin can mark a payment as completed when payment is received outside the system.
FR49: Admin can record payment date and payment mode when marking a payment as completed.
FR50: System can auto-generate a payment invoice when a payment is marked completed.
FR51: System can determine when a payment has become overdue based on due dates and recorded payment state.
FR52: System can apply a flat late fee when overdue conditions are met.
FR53: Admin can view the late-fee impact within the repayment context.
FR54: System can mark a loan as overdue when overdue repayment conditions are met.
FR55: System can close a loan when all generated payments are completed.
FR56: Admin can track the flow of money across disbursements and repayments within the product.
FR57: Admin can access a dashboard that surfaces operationally important lending information.
FR58: Admin can use dashboard entry points to navigate directly to repayment follow-up work.
FR59: Admin can view open loan applications requiring action.
FR60: Admin can view active loans.
FR61: Admin can view closed loans.
FR62: Admin can view total disbursed amount.
FR63: Admin can view total repayment amount.
FR64: Admin can open filtered record lists from dashboard metrics and operational views.
FR65: Admin can search borrowers, applications, loans, and payments using the primary identifiers defined for those record types.
FR66: Admin can investigate linked borrower, application, loan, disbursement, payment, and invoice records from within the product.
FR67: System can maintain linked records across borrowers, applications, loans, disbursements, payments, and invoices.
FR68: System can preserve an audit trail for key operational and financial actions.
FR69: System can record who performed each auditable action and when it occurred.
FR70: System can prevent hard deletion of operational and financial records.
FR71: System can prevent editing of loan records after disbursement.
FR72: System can prevent editing of payment records after payment completion.
FR73: System can keep financially significant lifecycle states derived from recorded facts rather than manual state toggles.
FR74: System can snapshot borrower data onto applications and loans for historical integrity.
FR75: Admin can upload generic documents to lending records.
FR76: System can preserve rejected document uploads and treat reuploads as the latest active version.
FR77: System can operate with seeded admin-only access and no in-app user management in MVP.

### NonFunctional Requirements

NFR1: Core authenticated actions should complete within 2 seconds under expected MVP usage conditions.
NFR2: The 2-second target applies to login, dashboard load, borrower search, filtered list load, and borrower, application, loan, and payment detail views.
NFR3: The product should restrict access to authenticated users only.
NFR4: Admin credentials should never be stored in plain text and must use secure password handling.
NFR5: Sensitive operational and financial data should be protected in transit.
NFR6: The product should provide basic session security appropriate for an internal MVP handling financial records.
NFR7: The product should target 99% uptime for MVP operation.
NFR8: Each page load should reflect the latest committed system state.
NFR9: Money-state transitions should remain internally consistent across approval, documentation, disbursement, repayment, overdue, and closure stages.
NFR10: Post-money records should remain locked after commitment so financial history remains trustworthy.
NFR11: The MVP should be optimized for the current single-admin operating model.
NFR12: The first release does not need to support broader team scale, high concurrency, or rapid growth scenarios.
NFR13: The system should remain workable for the current internal usage pattern without premature optimization for future scale.
NFR14: Backup or recovery automation is out of scope for MVP and should be treated as an acknowledged operational risk.

### Additional Requirements

- Epic 1 Story 1 must initialize the project from the selected starter template: `rails new lending_rails --database=postgresql --css=tailwind`.
- Immediately after initialization, the baseline implementation must add `RSpec`, Rails built-in authentication, `Pundit`, `shadcn-rails`, `paper_trail`, `phonelib`, `money-rails`, `double_entry`, and `aasm`.
- The solution must be implemented as a Rails monolith with PostgreSQL, Tailwind, Docker readiness, HTML-first controllers, and Hotwire/Stimulus only where needed.
- Money-critical business logic must live in explicit domain services, not in controllers, views, components, or jobs.
- The system must use PostgreSQL constraints plus model and domain validations to enforce hard invariants and workflow rules.
- UUID primary keys and UUID foreign keys should be the default identity strategy across domain entities.
- Borrower lookup fields such as phone number require an explicit searchable-encryption or normalized indexed search strategy.
- The system must use query objects or scoped read services for dashboard widgets, filtered lists, borrower history, and investigation flows.
- Authorization must be implemented through Rails-native authentication, session cookies, and `Pundit`, even though MVP starts with a seeded admin user.
- Audit coverage must include business-critical actions and key auth or security events, with model history support through `paper_trail`.
- The architecture must preserve clear pre-money editable states and post-money locked states, especially after disbursement and payment completion.
- Background and operational infrastructure should use `Solid Queue`, `Solid Cache`, `Mission Control Jobs`, and `GitHub Actions`, with Docker-first deployment and Kamal readiness.
- Structured logs are required as the initial observability baseline, while vendor-specific APM remains deferred.
- No external business integrations are required for MVP; all operational events such as payments received outside the system must be recorded manually but remain traceable.
- The accounting boundary must separate operational workflow records from bookkeeping truth via `double_entry`, with posting rules defined before disbursement and repayment implementation.
- Safe migration practices are required for schema evolution, especially for risky changes or backfills.

### UX Design Requirements

UX-DR1: Implement the product as a desktop-first internal web app optimized for the latest Chrome, with dashboard-to-list-to-detail navigation as the primary interaction model.
UX-DR2: Provide a focused login experience with product name, email/password form, calm presentation, and clear recoverable invalid-credential feedback.
UX-DR3: Build the dashboard as an action-first triage surface that prioritizes overdue payments, upcoming payments, open applications, and active loans, with drill-in links to filtered operational lists.
UX-DR4: Standardize global and local navigation so movement between dashboard, filtered lists, detail views, and updated post-action state feels direct and predictable.
UX-DR5: Create a reusable filter bar pattern with search, filters, sort controls, visible active-filter state, and reset behavior for all operational list views.
UX-DR6: Create a shared data table wrapper with consistent sorting, status cells, metadata formatting, row-click behavior, empty states, loading states, filtered-empty states, and secondary row actions.
UX-DR7: Create reusable entity header or summary blocks for borrower, application, loan, payment, and invoice detail pages that show identity, status, key metadata, and top actions.
UX-DR8: Create a linked-record relationship panel or section that exposes borrower, application, loan, payment, and invoice lineage and supports cross-navigation without losing context.
UX-DR9: Create a lifecycle status badge system with explicit labels, semantic color treatment, optional icons, and variants for default, warning, danger, success, muted, and locked states.
UX-DR10: Create guarded confirmation dialogs for money-sensitive actions such as disbursement and payment completion, including consequence summary and locked-state explanation.
UX-DR11: Create blocked-state callouts that explain why an action cannot proceed, what prerequisite is missing, and what the safest next step is.
UX-DR12: Create an activity or timeline block on detail pages to show critical operational and financial events with event label, timestamp, actor, and optional note or link.
UX-DR13: Apply a strict button hierarchy with at most one clear primary action per context and explicit action labels such as `Mark payment complete` and `Confirm disbursement`.
UX-DR14: Implement hybrid form validation with inline feedback for obvious issues, full validation on submit, calm actionable messages, and stronger consequence cues on high-risk forms.
UX-DR15: Define a consistent visual system with restrained neutral surfaces, semantic status colors, readable typography, and repeatable spacing and density rules across dashboards, lists, forms, and details.
UX-DR16: Ensure semantic states such as overdue, blocked, locked, completed, and attention-needed are understandable without relying on color alone.
UX-DR17: Build core workflows to a minimum auditable WCAG 2.1 Level A accessibility target, including keyboard navigation, visible focus states, semantic labels, readable contrast, and correct focus handling in dialogs.
UX-DR18: Implement responsive behavior for supported desktop layouts only in MVP, preserving critical information and safe navigation across standard laptop and desktop widths.

### FR Coverage Map

FR1: Epic 1 - Admin authentication
FR2: Epic 1 - Authenticated session and workspace access
FR3: Epic 1 - Logout and session exit
FR4: Epic 2 - Borrower creation
FR5: Epic 2 - Borrower search before creation
FR6: Epic 2 - Borrower lookup by phone and name
FR7: Epic 2 - Unique borrower identity by phone
FR8: Epic 2 - Borrower detail and borrowing history view
FR9: Epic 2 - Borrower list browsing
FR10: Epic 3 - Borrower-linked loan application creation
FR11: Epic 2 - Borrower-linked applications and loans view
FR12: Epic 2 - Prevent new application when active application exists
FR13: Epic 2 - Prevent new application when active loan exists
FR14: Epic 2 - Allow repeat borrowing after loan closure
FR15: Epic 3 - Application creation with pre-decision details
FR16: Epic 3 - Review-step creation on application creation
FR17: Epic 3 - Fixed MVP review workflow
FR18: Epic 3 - Explicit application statuses
FR19: Epic 3 - Explicit review-step statuses
FR20: Epic 3 - Application status and active review-step visibility
FR21: Epic 3 - Sequential review-step completion
FR22: Epic 3 - Borrower history during review
FR23: Epic 3 - Editable requested amount and tenure before final decision
FR24: Epic 3 - In-progress state when more details are needed
FR25: Epic 3 - Application approval
FR26: Epic 3 - Application rejection
FR27: Epic 3 - Application cancellation
FR28: Epic 3 - Historical rejected and cancelled applications
FR29: Epic 3 - Application list browsing by workflow state
FR30: Epic 4 - Loan creation from approved application
FR31: Epic 4 - Separate approval and disbursement
FR32: Epic 4 - Pre-disbursement loan preparation
FR33: Epic 4 - Documentation as a distinct stage
FR34: Epic 4 - Explicit loan lifecycle states
FR35: Epic 4 - Loan lifecycle transitions from business events
FR36: Epic 4 - Loan lifecycle visibility
FR37: Epic 4 - Loan list browsing by lifecycle state
FR38: Epic 4 - Controlled loan disbursement
FR39: Epic 4 - Disbursement invoice generation
FR40: Epic 5 - Repayment schedule generation
FR41: Epic 5 - Weekly, bi-weekly, and monthly frequencies
FR42: Epic 5 - Interest input by rate or total amount, but not both
FR43: Epic 5 - Full-payment repayment handling
FR44: Epic 5 - Upcoming payments view
FR45: Epic 5 - Overdue payments view
FR46: Epic 5 - Loan repayment-state visibility
FR47: Epic 5 - Payment list browsing by repayment state
FR48: Epic 5 - Mark payment completed
FR49: Epic 5 - Record payment date and mode
FR50: Epic 5 - Payment invoice generation
FR51: Epic 5 - Overdue payment derivation
FR52: Epic 5 - Flat late-fee application
FR53: Epic 5 - Late-fee visibility
FR54: Epic 5 - Loan overdue derivation
FR55: Epic 5 - Loan closure after all payments complete
FR56: Epic 5 - Money-flow tracking across disbursements and repayments
FR57: Epic 6 - Operational dashboard access
FR58: Epic 6 - Dashboard drill-ins to repayment follow-up work
FR59: Epic 6 - Open applications visibility
FR60: Epic 6 - Active loans visibility
FR61: Epic 6 - Closed loans visibility
FR62: Epic 6 - Total disbursed amount visibility
FR63: Epic 6 - Total repayment amount visibility
FR64: Epic 6 - Filtered list access from dashboard and operational views
FR65: Epic 6 - Search across borrowers, applications, loans, and payments
FR66: Epic 6 - Linked record investigation
FR67: Epic 6 - Linked records across lending entities
FR68: Epic 6 - Audit trail for key actions
FR69: Epic 6 - Audit actor and timestamp visibility
FR70: Epic 6 - No hard deletion of operational or financial records
FR71: Epic 4 - Lock loan edits after disbursement
FR72: Epic 5 - Lock payment edits after completion
FR73: Epic 6 - Derived lifecycle states from recorded facts
FR74: Epic 6 - Borrower snapshotting onto applications and loans
FR75: Epic 4 - Generic document upload
FR76: Epic 4 - Historical document reupload handling
FR77: Epic 1 - Seeded admin-only MVP access

## Epic List

### Epic 1: Secure Admin Access and Operational Workspace
Enable the admin to securely sign in, enter the lending operations workspace, and use the product as the system's controlled entry point.
**FRs covered:** FR1, FR2, FR3, FR77

### Epic 2: Borrower Intake and Borrower History
Enable the admin to create, find, review, and manage borrower records with enough context to safely start new lending work.
**FRs covered:** FR4, FR5, FR6, FR7, FR8, FR9, FR11, FR12, FR13, FR14

### Epic 3: Loan Application Review and Decisioning
Enable the admin to create applications, move them through the fixed review workflow, assess borrower context, and reach clear approval, rejection, or cancellation outcomes.
**FRs covered:** FR10, FR15, FR16, FR17, FR18, FR19, FR20, FR21, FR22, FR23, FR24, FR25, FR26, FR27, FR28, FR29

### Epic 4: Loan Setup, Documentation, and Disbursement Control
Enable the admin to turn approved applications into controlled loans, complete pre-disbursement preparation, manage required documents, and safely disburse funds.
**FRs covered:** FR30, FR31, FR32, FR33, FR34, FR35, FR36, FR37, FR38, FR39, FR71, FR75, FR76

### Epic 5: Repayment Servicing, Overdue Control, and Loan Closure
Enable the admin to manage repayment schedules, record completed payments, track overdue states, apply late-fee logic, and close loans correctly.
**FRs covered:** FR40, FR41, FR42, FR43, FR44, FR45, FR46, FR47, FR48, FR49, FR50, FR51, FR52, FR53, FR54, FR55, FR56, FR72

### Epic 6: Portfolio Visibility, Search, and Trusted Record History
Enable the admin to access an action-first dashboard, investigate the full lending portfolio through dashboard drill-ins, and rely on searchable, linked, and trustworthy record history.
**FRs covered:** FR57, FR58, FR59, FR60, FR61, FR62, FR63, FR64, FR65, FR66, FR67, FR68, FR69, FR70, FR73, FR74

## Canonical Review-Step Vocabulary

The PRD describes the fixed MVP review workflow using prose names ("history checking", "phone screening", "verification"). The implementation defines these as machine-readable step keys in `ReviewStep::WORKFLOW_DEFINITION`. This table is the canonical mapping between planning language and code:

| Position | PRD Prose Name | Code `step_key` | Code Display `label` |
|----------|----------------|-----------------|----------------------|
| 1 | History checking | `history_check` | History check |
| 2 | Phone screening | `phone_screening` | Phone screening |
| 3 | Verification | `verification` | Verification |

**Review-step statuses** (FR19): `initialized`, `approved`, `rejected`, `waiting for details` — identical in PRD and code.

**Application statuses** (FR18): `open`, `in progress`, `approved`, `rejected`, `cancelled` — identical in PRD and code.

The PRD's "other required steps" clause allows future expansion. Adding a step requires only a new entry in `WORKFLOW_DEFINITION` and a migration to seed it on existing applications if needed.

## Epic 1: Secure Admin Access and Operational Workspace

Enable the admin to securely sign in, enter the lending operations workspace, and use the product as the system's controlled entry point.

### Story 1.1: Initialize the Rails Operational Foundation

As an admin operator,
I want the lending system initialized with the approved secure application foundation,
So that I can use a stable, production-shaped internal workspace for lending operations.

**Acceptance Criteria:**

**Given** the project is starting from an empty implementation state
**When** the application is initialized
**Then** it uses `rails new lending_rails --database=postgresql --css=tailwind`
**And** the baseline project includes the approved foundational libraries and developer setup needed for authentication, authorization, UI, testing, auditability, and money-safe implementation

**Given** the application foundation is created
**When** a developer inspects the project baseline
**Then** the app is configured as a Rails monolith with PostgreSQL, Tailwind, Docker readiness, and HTML-first navigation
**And** UUID-based entity identity, RSpec, and the agreed architectural baseline are ready for future stories

**Given** the baseline foundation is prepared for team development
**When** a developer reviews the delivery setup
**Then** the project includes a repeatable CI path that runs the core test and quality checks
**And** the generated Docker and deployment-ready artifacts remain usable without extra bootstrap rework

**Given** the baseline app is running
**When** a user visits the root application shell
**Then** they see a working internal application frame rather than a broken or placeholder-only setup
**And** the foundation supports future authentication and dashboard stories without rework

### Story 1.2: Seed the Admin Account and Secure Access Rules

As an admin operator,
I want a secure seeded admin account and protected access rules,
So that only authorized internal users can enter the lending workspace.

**Acceptance Criteria:**

**Given** the application has been initialized
**When** the system is set up for MVP access
**Then** it provides a seeded admin account for internal use
**And** there is no in-app user-management workflow exposed in MVP

**Given** the seeded admin account exists
**When** account credentials are stored and verified
**Then** passwords are handled securely and never stored in plain text
**And** the authentication design uses secure server-managed sessions

**Given** an unauthenticated visitor accesses a protected page
**When** they attempt to open the lending workspace
**Then** the system blocks access
**And** redirects them to the login flow

### Story 1.3: Admin Login with Clear Feedback

As an admin operator,
I want to sign in with email and password through a focused login flow,
So that I can quickly and confidently access the lending system.

**Acceptance Criteria:**

**Given** the admin is not signed in
**When** they open the login page
**Then** they see a focused email-and-password form with the product identity clearly presented
**And** the page feels calm, legible, and appropriate for an internal financial operations tool

**Given** valid admin credentials
**When** the admin submits the login form
**Then** the system creates an authenticated session
**And** redirects the admin into the operational workspace

**Given** invalid credentials
**When** the admin submits the login form
**Then** the system does not create a session
**And** shows a clear recoverable error message without losing orientation

### Story 1.4: Authenticated Workspace Entry and Logout

As an admin operator,
I want to land on a protected workspace after login and be able to log out safely,
So that I can enter the system cleanly and end my session without retaining protected access.

**Acceptance Criteria:**

**Given** the admin has authenticated successfully
**When** they enter the product
**Then** they land on the protected authenticated workspace entry point
**And** the page is protected from unauthenticated access

**Given** the admin is in the authenticated workspace
**When** the page loads
**Then** it shows the operational workspace shell with clear orientation and sign-out access
**And** the experience reflects the latest committed system state

**Given** the admin has an active session
**When** they choose to log out
**Then** the session is ended securely
**And** they are returned to the login flow without retaining protected access

## Epic 2: Borrower Intake and Borrower History

Enable the admin to create, find, review, and manage borrower records with enough context to safely start new lending work.

### Story 2.1: Establish Borrower Identity and Searchable Records

As an admin operator,
I want borrower records to use a unique, searchable phone-based identity,
So that I can trust that each borrower exists once and can be found reliably.

**Acceptance Criteria:**

**Given** the system is ready for borrower data
**When** borrower persistence is introduced
**Then** the borrower entity uses UUID-based identity and stores the core borrower fields needed for MVP intake
**And** the borrower model supports a normalized phone-based lookup strategy consistent with the architecture

**Given** a borrower phone number is recorded
**When** the system stores or compares borrower identity
**Then** the phone number is normalized consistently
**And** the database and application rules prevent duplicate borrower records for the same phone number

**Given** a developer or operator inspects the borrower foundation
**When** they review the implementation
**Then** it supports future borrower search, detail pages, and lending record linkage
**And** it does not require unrelated lending entities to be created ahead of need

### Story 2.2: Create Borrower Intake Flow

As an admin operator,
I want to create a borrower from a clear intake form,
So that I can bring a new borrower into the lending workflow without ambiguity.

**Acceptance Criteria:**

**Given** the admin is authenticated
**When** they open the borrower creation flow
**Then** they see a clear borrower intake form with explicit labels and calm validation feedback
**And** the form matches the product's desktop-first and accessibility-oriented UX direction

**Given** the admin enters valid borrower information
**When** they submit the borrower form
**Then** the system creates the borrower record successfully
**And** the admin is taken to an appropriate post-create borrower context

**Given** the admin enters a duplicate or invalid phone number
**When** they submit the borrower form
**Then** the system blocks creation with a specific, actionable error
**And** the admin can correct the issue without losing orientation

### Story 2.3: Search and Browse Borrowers

As an admin operator,
I want to search and browse borrowers by the identifiers that matter operationally,
So that I can find the right person before creating or reviewing lending work.

**Acceptance Criteria:**

**Given** borrower records exist
**When** the admin opens the borrower list
**Then** they see a consistent operational list with search and filtering controls
**And** the table behavior follows the shared filter-bar and data-table UX patterns

**Given** the admin searches by phone number
**When** they run the search
**Then** matching borrowers are returned using phone number as the primary lookup path
**And** name-based search remains available as a secondary lookup method

**Given** no borrower matches the search or filters
**When** the results are empty
**Then** the system shows a useful empty or filtered-empty state
**And** the admin understands whether to refine the search or create a new borrower

### Story 2.4: View Borrower Details and Lending History

As an admin operator,
I want a borrower detail page with prior lending context,
So that I can understand the borrower's history before taking the next action.

**Acceptance Criteria:**

**Given** the admin opens a borrower record
**When** the borrower detail page loads
**Then** it presents a clear entity header with borrower identity and current lending context
**And** the page follows the shared detail-page UX patterns for orientation and top actions

**Given** the borrower has related applications or loans
**When** the admin views the borrower detail
**Then** they can see linked lending records and prior borrowing history in one place
**And** they can navigate from the borrower into the relevant linked records without losing context

**Given** the borrower has no prior lending history
**When** the admin views the borrower detail
**Then** the system communicates that state clearly
**And** still makes the next relevant action obvious

### Story 2.5: Evaluate Borrower Eligibility for a New Application

As an admin operator,
I want the borrower record to tell me whether a new application is allowed,
So that I do not begin conflicting lending work for the same borrower.

**Acceptance Criteria:**

**Given** the admin is viewing a borrower record
**When** the system evaluates that borrower's current lending context
**Then** it shows whether the borrower is eligible for a new application
**And** the reason for the eligibility or ineligibility is clear from the borrower context

**Given** the borrower already has an active application
**When** the admin reviews the borrower record
**Then** the system shows that a new application is not allowed
**And** explains that a new application cannot be started while an active application exists

**Given** the borrower has an active loan
**When** the admin reviews the borrower record
**Then** the system shows that repeat borrowing is currently blocked
**And** explains that a new application becomes available only after the active loan is closed

**Given** the borrower's active loan has been closed and there is no active application
**When** the admin reviews the borrower record
**Then** the system shows that the borrower is eligible for a new application
**And** the borrower history remains available to support the next lending decision

## Epic 3: Loan Application Review and Decisioning

Enable the admin to create applications, move them through the fixed review workflow, assess borrower context, and reach clear approval, rejection, or cancellation outcomes.

### Story 3.1: Create a Borrower-Linked Application and Maintain Loan Details

As an admin operator,
I want to create a borrower-linked application and edit its required pre-decision loan details,
So that I can prepare a complete request for review and decisioning.

**Acceptance Criteria:**

**Given** the admin is viewing a borrower who is eligible for a new application
**When** they start application creation from that borrower context
**Then** the system creates a borrower-linked application record
**And** opens the application form with an explicit workflow status suitable for continued review

**Given** a borrower-linked application exists
**When** the admin opens the application form
**Then** they can enter the required pre-decision loan details for MVP
**And** the application remains clearly linked to the borrower throughout review

**Given** the application is not yet finally approved or rejected
**When** the admin updates the requested amount or tenure
**Then** the changes are saved successfully
**And** the application remains editable within the allowed pre-decision boundary

**Given** the application has reached a final approve or reject outcome
**When** the admin attempts to edit decision-sensitive request details
**Then** the system blocks the edit
**And** explains that those fields are no longer editable after a final decision

### Story 3.2: Generate the Fixed Review Workflow

As an admin operator,
I want each new application to receive the system-defined review steps automatically,
So that every application follows the same controlled MVP decision path.

**Acceptance Criteria:**

**Given** an application is ready for review
**When** the review workflow is initialized
**Then** the system creates the fixed MVP review steps automatically
**And** the workflow is system-defined rather than user-configurable

**Given** review steps have been created
**When** the admin opens the application
**Then** they can see the active step and the current application status clearly
**And** review-step statuses use the agreed canonical vocabulary

**Given** the application review is underway
**When** the admin inspects the workflow state
**Then** the application and review-step status values remain internally consistent
**And** the UI makes it obvious what stage is active now

### Story 3.3: Progress Review Steps in Sequence

As an admin operator,
I want to move application review steps forward in the correct order,
So that the review process stays controlled and understandable.

**Acceptance Criteria:**

**Given** an application has multiple review steps
**When** the admin acts on the current active step
**Then** the system allows completion of the valid step in sequence
**And** advances the workflow without skipping required earlier steps

**Given** more information is needed during review
**When** the admin marks the application as waiting for details or otherwise not ready to proceed
**Then** the system keeps the application in a valid in-progress path
**And** makes the blocked or pending state clear to the admin

**Given** the admin attempts an invalid progression
**When** they try to act on a non-current or invalid step
**Then** the system blocks the action
**And** explains why the review cannot proceed that way

### Story 3.4: Review Borrower History During Decisioning

As an admin operator,
I want borrower history visible within application review,
So that I can make approval or rejection decisions with the right context.

**Acceptance Criteria:**

**Given** the admin is reviewing an application
**When** they open the application detail
**Then** borrower history is visible within the review experience
**And** linked borrower context can be accessed without losing the application workflow state

**Given** the borrower has prior applications, loans, or outcomes
**When** the admin views the review context
**Then** those historical signals are presented clearly enough to support decision-making
**And** the experience preserves orientation between the borrower and the application

**Given** the admin needs to work across multiple applications
**When** they browse the application list
**Then** they can view applications by operational state
**And** list and detail behavior follows the shared UX patterns for filters, statuses, and navigation

### Story 3.5: Approve, Reject, and Cancel Applications with Preserved History

As an admin operator,
I want to complete application decisions clearly and preserve the outcomes,
So that every lending decision remains traceable and operationally understandable.

**Acceptance Criteria:**

**Given** an application has satisfied the required review conditions
**When** the admin approves the application
**Then** the system records the approved outcome using the canonical status model
**And** the application is ready for downstream loan creation

**Given** an application should not proceed
**When** the admin rejects or cancels it
**Then** the system records the correct final outcome
**And** the reasoned workflow state remains visible in application history

**Given** an application has been rejected or cancelled
**When** the admin searches or browses historical applications later
**Then** the record remains searchable and reviewable
**And** the system never treats that historical record as deleted or lost

## Epic 4: Loan Setup, Documentation, and Disbursement Control

Enable the admin to turn approved applications into controlled loans, complete pre-disbursement preparation, manage required documents, and safely disburse funds.

### Story 4.1: Create a Loan from an Approved Application

As an admin operator,
I want an approved application to become a loan record with explicit lifecycle states,
So that lending work can progress from decisioning into controlled execution.

**Acceptance Criteria:**

**Given** an application has been approved
**When** the system performs the approval-to-loan transition
**Then** it creates a linked loan record from the approved application
**And** loan approval remains distinct from actual disbursement

**Given** the loan is newly created
**When** the admin views it
**Then** the loan uses the agreed lifecycle vocabulary for pre-disbursement states
**And** the current state is shown clearly in the loan UI

**Given** the loan exists
**When** the system records lifecycle movement
**Then** transitions are driven by valid business events rather than ad hoc manual state toggles
**And** the loan remains linked to its source application

### Story 4.2: Prepare and Review Loan Details Before Disbursement

As an admin operator,
I want to prepare and review loan details before money is released,
So that the loan is complete and accurate before entering the money-sensitive stage.

**Acceptance Criteria:**

**Given** a pre-disbursement loan exists
**When** the admin opens the loan detail and edit flow
**Then** they can prepare and finalize the loan details allowed before disbursement
**And** the interface clearly distinguishes editable pre-money information from later locked states

**Given** the admin is working across multiple loans
**When** they open the loan list
**Then** they can browse loans by lifecycle state and operational need
**And** the loan list follows the shared table, filter, and status UX patterns

**Given** the admin is reviewing a specific loan
**When** the detail page loads
**Then** it shows the current lifecycle state clearly
**And** the next valid action is visible without ambiguity

### Story 4.3: Complete Loan Documentation and Manage Supporting Documents

As an admin operator,
I want to complete documentation and manage supporting files before disbursement,
So that I can satisfy the required readiness stage without losing document history.

**Acceptance Criteria:**

**Given** a loan is approved but not ready for disbursement
**When** the admin enters the documentation stage
**Then** the system treats documentation as a distinct operational stage
**And** the loan cannot bypass it silently

**Given** the admin needs to attach supporting documents
**When** they upload a document to the lending record
**Then** the system stores the upload against the appropriate record
**And** the document becomes part of the operational history

**Given** a document must be replaced or reuploaded
**When** the admin uploads a new version
**Then** the system preserves the historical document context
**And** treats the new upload as the latest active version rather than overwriting history

### Story 4.4: Validate Disbursement Readiness

As an admin operator,
I want the system to verify that a loan is fully ready before disbursement is allowed,
So that funds cannot be released while required preconditions are incomplete.

**Acceptance Criteria:**

**Given** a loan is still in a pre-disbursement state
**When** the admin opens the disbursement readiness view
**Then** the system evaluates the required readiness conditions for disbursement
**And** shows whether the loan is blocked or ready for the next step

**Given** one or more readiness conditions are missing
**When** the admin attempts to proceed toward disbursement
**Then** the system blocks the action
**And** displays a blocked-state explanation describing the missing prerequisite and safest next step

**Given** the readiness evaluation is implemented
**When** the application behavior is reviewed
**Then** the readiness rules are enforced by server-side domain logic rather than UI-only checks
**And** the same readiness outcome can be tested independently of the browser flow

### Story 4.5: Execute Guarded Disbursement, Create Financial Records, and Lock the Loan

As an admin operator,
I want loan disbursement to be explicit, auditable, and financially final,
So that the system activates servicing only when funds have truly been released.

**Acceptance Criteria:**

**Given** a loan has passed all disbursement readiness checks
**When** the admin initiates disbursement
**Then** the UI presents a guarded confirmation describing the consequence of the action
**And** the admin must explicitly confirm before the money event is recorded

**Given** the admin confirms a valid disbursement
**When** the domain service executes the disbursement
**Then** the system records disbursement as the event that activates the loan
**And** creates the disbursement invoice and any required accounting or audit records as part of the same business action

**Given** a loan has been disbursed
**When** the admin returns to the loan
**Then** the loan shows the correct active post-disbursement state
**And** disbursement-locked loan fields are no longer editable

**Given** a disbursement has already been committed
**When** an operator attempts to repeat or mutate that committed financial event through normal editing flows
**Then** the system blocks the action
**And** preserves the original committed financial history

## Epic 5: Repayment Servicing, Overdue Control, and Loan Closure

Enable the admin to manage repayment schedules, record completed payments, track overdue states, apply late-fee logic, and close loans correctly.

### Story 5.1: Generate the Repayment Schedule from Disbursement

As an admin operator,
I want repayment schedules generated automatically when a loan is disbursed,
So that servicing begins from system-calculated facts instead of manual tracking.

**Acceptance Criteria:**

**Given** a loan has just been disbursed
**When** the system activates repayment servicing
**Then** it generates the repayment schedule automatically
**And** the generated payment records are linked to the loan

**Given** the admin defines repayment rules
**When** the schedule is generated
**Then** the system supports weekly, bi-weekly, and monthly frequencies
**And** it allows interest input by rate or total interest amount, but not both together

**Given** the MVP repayment rules are enforced
**When** the schedule is created
**Then** the system supports full-payment-only handling for MVP
**And** the repayment output remains internally consistent with the loan terms

### Story 5.2: View Upcoming and Overdue Repayment Work

As an admin operator,
I want clear upcoming and overdue repayment views,
So that I can focus daily servicing work on the loans that need attention now.

**Acceptance Criteria:**

**Given** repayment records exist
**When** the admin opens repayment-focused views
**Then** they can see upcoming payments and overdue payments as distinct operational views
**And** those views follow the shared filter, table, and status UX patterns

**Given** the admin is reviewing a loan or payment
**When** the relevant detail pages load
**Then** the current repayment state is shown clearly
**And** the admin can understand whether the item is upcoming, completed, overdue, or otherwise action-relevant

**Given** the admin needs to work across many payments
**When** they browse the payments list
**Then** they can filter or browse payments by repayment state and operational need
**And** the list supports efficient operational scanning

### Story 5.3: Mark Payments Completed with Locked Financial History

As an admin operator,
I want to record externally received payments with the right completion details,
So that the system stays the source of truth for repayment progress.

**Acceptance Criteria:**

**Given** a payment has been received outside the system
**When** the admin marks the payment as completed
**Then** the system records the completion successfully
**And** requires the payment date and payment mode as part of the action

**Given** the payment completion is a money-sensitive action
**When** the admin initiates it
**Then** the UI uses a guarded confirmation pattern with consequence-aware messaging
**And** the updated state is shown clearly after completion

**Given** a payment has been marked completed
**When** the admin attempts to edit the completed payment record
**Then** the system blocks the edit
**And** explains that completed financial records are non-editable

### Story 5.4: Generate Payment Financial Records and Preserve the Accounting Boundary

As an admin operator,
I want completed repayments to produce the required financial records without mixing operational and accounting responsibilities,
So that repayment tracking remains trustworthy and financially traceable.

**Acceptance Criteria:**

**Given** a payment has been marked completed successfully
**When** the system finalizes that payment event
**Then** it creates the corresponding payment invoice automatically
**And** links the invoice to the relevant lending records

**Given** the product tracks money movement across disbursements and repayments
**When** repayment financial records are created
**Then** operational workflow records and accounting-posting responsibilities remain clearly separated
**And** any accounting-side posting rules are executed only through approved money-moving domain services

**Given** a financial event has been completed
**When** the admin investigates the related records later
**Then** the system preserves a clear relationship between borrower, loan, payment, invoice, and audit context
**And** the product remains the operational source of truth

### Story 5.5: Derive Overdue Payment and Loan States

As an admin operator,
I want overdue repayment and overdue loan states derived automatically from recorded facts,
So that servicing status stays accurate without manual intervention.

**Acceptance Criteria:**

**Given** a payment passes its due date without completion
**When** the system evaluates repayment state
**Then** it marks the payment overdue automatically
**And** the overdue state is derived from due dates and recorded payment facts rather than manual toggles

**Given** one or more loan payments are overdue
**When** the system refreshes the related loan state
**Then** the loan is marked overdue automatically
**And** the loan status remains consistent with the underlying payment facts

**Given** overdue logic is implemented
**When** the behavior is tested
**Then** the derivation can be validated at the service level with deterministic date-based scenarios
**And** dashboard or list visibility depends on that same canonical derived state

### Story 5.6: Apply Late Fees and Close Loans from Completed Repayment Facts

As an admin operator,
I want late-fee impact and final loan closure handled from servicing facts,
So that repayment outcomes remain financially correct and operationally clear.

**Acceptance Criteria:**

**Given** an overdue condition meets MVP late-fee rules
**When** the system applies overdue consequences
**Then** it applies the flat late fee according to policy
**And** the admin can see the late-fee impact within the repayment context

**Given** all generated loan payments have been completed
**When** the system refreshes the loan lifecycle state
**Then** the loan closes automatically
**And** closure is derived from completed repayment facts rather than manual toggles

**Given** a loan has closed automatically
**When** the admin inspects the final loan state
**Then** the closed status is visible and historically consistent
**And** the record remains available for later operational review

## Epic 6: Portfolio Visibility, Search, and Trusted Record History

Enable the admin to access an action-first dashboard, investigate the full lending portfolio through dashboard drill-ins, and rely on searchable, linked, and trustworthy record history.

### Story 6.1: Build the Action-First Operational Dashboard

As an admin operator,
I want a dashboard that surfaces the work that matters most,
So that I can begin each day with immediate operational clarity.

**Acceptance Criteria:**

**Given** the admin lands on the dashboard
**When** the page loads
**Then** it presents the dashboard as an action-first operational workspace
**And** it prioritizes overdue payments, upcoming payments, open applications, and active loans as the primary triage signals for lending operations

**Given** operational data exists
**When** the dashboard renders
**Then** it shows widgets for overdue payments, upcoming payments, open applications, active loans, closed loans, total disbursed amount, and total repayment amount
**And** the information follows the shared dashboard widget and visual hierarchy patterns

**Given** the dashboard is the primary workspace entry point
**When** the admin uses it repeatedly
**Then** the experience remains clear, desktop-first, and fast to scan
**And** the data reflects the latest committed system state on each load

### Story 6.2: Drill from Dashboard into Filtered Operational Views

As an admin operator,
I want dashboard widgets to open the right filtered operational lists,
So that I can move directly from signal to action without losing context.

**Acceptance Criteria:**

**Given** the admin is on the dashboard
**When** they click the overdue payments, upcoming payments, open applications, active loans, closed loans, total disbursed amount, or total repayment amount widget
**Then** the system opens the corresponding filtered list
**And** the resulting list makes the filter context explicit

**Given** the admin drills into upcoming, overdue, active, open, or summary-driven work
**When** the list page loads
**Then** it uses the shared filter-bar and data-table patterns
**And** the admin can continue investigating from that operational context without confusion

**Given** the admin drills in from overdue payments or upcoming payments
**When** the filtered repayment list loads
**Then** the matching repayment-state or due-window filter is already applied
**And** the admin does not need to rebuild the same triage filter manually

**Given** no records match a drilled-in view
**When** the filtered list is empty
**Then** the system shows a clear empty-state explanation
**And** the admin understands whether the result means healthy operations or active filter constraints

### Story 6.3: Search and Investigate Across Linked Lending Records

As an admin operator,
I want to search and investigate borrowers, applications, loans, and payments through linked records,
So that I can reconstruct the right operational context quickly.

**Acceptance Criteria:**

**Given** the admin needs to find a specific record
**When** they search across borrowers, applications, loans, or payments
**Then** the system supports lookup by the primary identifiers for those entities
**And** search behavior remains consistent across operational list views

**Given** the admin opens a record from search or a filtered list
**When** the detail page loads
**Then** linked borrower, application, loan, payment, disbursement, and invoice relationships are visible where relevant
**And** navigation across those relationships preserves orientation

**Given** the product uses shared detail patterns
**When** the admin investigates linked records
**Then** entity headers, relationship context, and status indicators stay consistent across entities
**And** the UI makes record lineage understandable without relying on memory

### Story 6.4: Record Audit History and Protect Operational Records

As an admin operator,
I want key operational actions recorded and protected from destructive loss,
So that I can trust the system as a historical source of truth.

**Acceptance Criteria:**

**Given** the admin performs a key operational or financial action
**When** the system records that event
**Then** it creates an audit trail entry or version history as appropriate
**And** the trail includes who performed the action and when it occurred

**Given** the admin is reviewing a record with meaningful history
**When** they inspect the available audit context
**Then** they can see the relevant historical events in a readable way
**And** the activity or timeline presentation supports operational review

**Given** an operator attempts to remove critical historical data
**When** they try to hard-delete an operational or financial record
**Then** the system prevents hard deletion
**And** the record remains available as part of the searchable system history

### Story 6.5: Preserve Derived State Integrity and Historical Snapshots

As an admin operator,
I want derived lifecycle states and borrower snapshots to remain historically trustworthy,
So that record history keeps the context that existed when past decisions were made.

**Acceptance Criteria:**

**Given** applications and loans depend on borrower context
**When** the system records those lending records
**Then** it snapshots the relevant borrower data onto the application and loan
**And** later borrower edits do not rewrite historical decision context

**Given** lifecycle states such as overdue and closed are shown in the UI
**When** the system determines those states
**Then** they are derived from recorded facts and workflow rules rather than manual toggles
**And** the displayed status remains consistent with the underlying record history

**Given** the admin investigates a historical lending path
**When** they move through borrower, application, loan, payment, and invoice context
**Then** the system preserves a trustworthy narrative of what happened
**And** linked records, statuses, and historical snapshots reinforce that trust
