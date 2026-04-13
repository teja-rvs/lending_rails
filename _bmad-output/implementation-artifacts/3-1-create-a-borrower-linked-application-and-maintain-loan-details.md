# Story 3.1: Create a Borrower-Linked Application and Maintain Loan Details

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want to create a borrower-linked application and edit its required pre-decision loan details,
so that I can prepare a complete request for review and decisioning.

## Acceptance Criteria

1. **Given** the admin is viewing a borrower who is eligible for a new application  
   **When** they start application creation from that borrower context  
   **Then** the system creates a borrower-linked application record  
   **And** opens the application form with an explicit workflow status suitable for continued review

2. **Given** a borrower-linked application exists  
   **When** the admin opens the application form  
   **Then** they can enter the required pre-decision loan details for MVP  
   **And** the application remains clearly linked to the borrower throughout review

3. **Given** the application is not yet finally approved or rejected  
   **When** the admin updates the requested amount or tenure  
   **Then** the changes are saved successfully  
   **And** the application remains editable within the allowed pre-decision boundary

4. **Given** the application has reached a final approve or reject outcome  
   **When** the admin attempts to edit decision-sensitive request details  
   **Then** the system blocks the edit  
   **And** explains that those fields are no longer editable after a final decision

## Tasks / Subtasks

- [x] Expand the `LoanApplication` domain model and persistence to support real pre-decision application data (AC: 1, 2, 3, 4)
  - [x] Add a migration for the minimum MVP pre-decision fields owned by this story: requested amount, requested tenure, requested repayment frequency, proposed interest mode, and any minimal note field needed to keep the request reviewable without pulling document management forward
  - [x] Persist borrower snapshot data on application creation so later borrower edits do not rewrite the original decision context
  - [x] Keep `LoanApplication::STATUSES` compatible with the current persisted vocabulary (`open`, `in progress`, `approved`, `rejected`, `cancelled`) instead of silently introducing a different enum format mid-epic
  - [x] Encapsulate application number generation in the model or service layer so new records keep the existing `APP-0001`-style identifier pattern without controller-level string building
  - [x] Add model validations for required fields, supported frequencies, and any mutually exclusive pre-decision interest inputs chosen for this story
  - [x] Add audit/version coverage for application create/update history using the repo's `paper_trail` setup if the new mutable fields would otherwise be unaudited

- [x] Add a borrower-initiated application creation flow that reuses the existing borrower eligibility guardrail (AC: 1)
  - [x] Extend the borrower detail experience introduced in Story `2.5` so an eligible borrower exposes a real "start application" action instead of placeholder copy
  - [x] Re-check borrower eligibility inside the server-side creation path before persisting the new application so stale UI cannot create conflicting work
  - [x] Create the application through a thin controller plus a dedicated domain service such as `LoanApplications::Create`; do not create the record directly inside the view or controller
  - [x] Initialize the application with an explicit status suitable for the next review slice; `open` is the safest default unless implementation reveals a product-level reason to transition later
  - [x] Redirect the admin into the canonical application workspace/form immediately after creation rather than leaving them on the borrower page with ambiguous next steps

- [x] Turn the current minimal loan-application read surface into the canonical pre-decision application workspace (AC: 1, 2, 3, 4)
  - [x] Extend `LoanApplicationsController` and the application view(s) so borrower identity, application identifier, current status, and editable pre-decision fields live in one server-rendered flow
  - [x] Prefer a conventional Rails form flow that keeps `show`/`update` or `edit`/`update` clear and thin; add routes only where they materially support the canonical application workspace
  - [x] Capture the MVP pre-decision details called out in planning artifacts: requested amount, requested tenure, requested repayment frequency, and proposed interest mode
  - [x] Do not pull full review-step rendering, approval/rejection actions, loan creation, disbursement preparation, repayment generation, or document-upload workflow into this story
  - [x] If a simple notes field is needed to preserve review context, keep it intentionally lightweight and explicitly defer full attachment/document handling to later stories

- [x] Preserve the pre-decision editing boundary and communicate lock states clearly (AC: 3, 4)
  - [x] Allow updates while the application remains inside the editable pre-decision boundary and keep the save path server-driven and deterministic
  - [x] Block edits once the application reaches a final decision outcome owned by later stories; at minimum `approved` and `rejected` must lock these fields, and any future `cancelled` handling should not conflict with that rule
  - [x] Surface blocked-state messaging in calm operational language that explains why the fields are locked and what lifecycle boundary was crossed
  - [x] Do not hide the borrower link or application status when the record becomes non-editable; the page should still preserve orientation and historical clarity

- [x] Keep architecture boundaries intact while laying the seam for later Epic 3 stories (AC: 1, 2, 3, 4)
  - [x] Put business mutations in `app/services/loan_applications/`, not in components, Stimulus, or controller branches
  - [x] Keep read composition in queries/components where helpful, and keep mutation orchestration thin in the controller
  - [x] Add or extend a `LoanApplicationPolicy` if authorization is introduced for the new create/update/show paths so the repo moves closer to its stated Pundit architecture instead of relying only on the global admin gate
  - [x] Leave a clean seam for Story `3.2` to create fixed review steps automatically instead of hard-coding temporary step records or fake workflow progress here
  - [x] Leave a clean seam for Story `3.5` to own approval, rejection, and cancellation actions instead of adding final-decision mutations in this story

- [x] Add focused automated coverage for creation, update, blocking, and UX clarity (AC: 1, 2, 3, 4)
  - [x] Extend request specs for authenticated creation and update flows, including success, validation failure, blocked-create, and locked-after-final-decision cases
  - [x] Add model or service specs for application number generation, borrower snapshotting, eligibility re-checking, supported frequency validation, and edit-lock rules
  - [x] Extend system coverage from the borrower detail page through application creation so the admin can move from an eligible borrower into the application workspace without losing context
  - [x] Add focused assertions that the application remains clearly linked to the borrower and that the status/blocked-state messaging is visible in the rendered UI
  - [x] Reuse current factories, admin sign-in helpers, and request/system patterns instead of introducing parallel setup

## Dev Notes

### Story Intent

This story turns the "eligible for a new application" signal from Story `2.5` into a real borrower-to-application workflow. The main goal is to create the application record honestly, capture the minimum pre-decision details needed for review, and establish the application page as the canonical operational surface for later Epic 3 decisioning work.

### Epic Context and Sequencing Risk

- Epic 3 moves from application creation into fixed review-step generation, sequential progression, borrower-history-assisted decisioning, and final outcomes.
- Story `2.5` intentionally stopped at borrower eligibility and truthful next-step messaging; Story `3.1` is the first story allowed to replace that placeholder with a real mutation path.
- The largest sequencing risk is pulling Story `3.2`, `3.3`, or `3.5` forward by inventing review-step data, workflow progression rules, or decision actions too early.
- A second major risk is mixing pre-decision application capture with later pre-disbursement loan preparation from Epic 4. This story should collect request-level details, not disbursement-ready loan setup.
- Application creation is also the first point where the PRD's borrower snapshotting rule becomes operationally mandatory; deferring it would create historical-integrity debt immediately.

### Current Codebase Signals

- `app/controllers/borrowers_controller.rb` already uses `Borrowers::HistoryQuery` as the borrower detail read seam and keeps `show` thin.
- `app/queries/borrowers/history_query.rb` already encodes the borrower-level rule that new application creation is blocked by loan applications in `open`, `in progress`, or `approved`, and by loans in `active` or `overdue`.
- Story `2.5` already changed the borrower detail header to communicate readiness for a new application, and it explicitly says application creation arrives in the next story. Reuse that exact seam instead of building a second borrower decision page.
- `app/models/loan_application.rb` and `db/schema.rb` currently provide only `application_number`, `borrower_id`, and `status`, so Story `3.1` must supply the real request-data columns and validations.
- `app/controllers/loan_applications_controller.rb` plus `app/views/loan_applications/show.html.erb` currently provide a minimal read-only application surface. That surface is the best existing anchor to evolve into the canonical application workspace.
- `config/routes.rb` currently exposes only `loan_applications#show`; create/update routing does not exist yet.
- `spec/factories/loan_applications.rb` already establishes the visible identifier pattern `APP-0001`, which the implementation should preserve.
- The repo currently has only `ApplicationPolicy`; if resource-level authorization is introduced for application mutations, Story `3.1` likely becomes the first meaningful place to add `LoanApplicationPolicy`.

### Scope Boundaries

- In scope: borrower-linked application creation from an eligible borrower context.
- In scope: storing and editing the minimum MVP pre-decision application details.
- In scope: borrower snapshotting onto the application at creation time.
- In scope: clear application status visibility and borrower linkage on the application page.
- In scope: edit locking for final decision outcomes and clear blocked-state messaging.
- In scope: focused schema, model, service, controller, view, and test changes for the borrower-to-application slice.
- Out of scope: fixed review-step generation and active-step UI beyond the light seam needed for Story `3.2`.
- Out of scope: review-step progression rules, waiting-for-details workflow mechanics, or decision actions from Stories `3.3` and `3.5`.
- Out of scope: loan creation, documentation readiness, disbursement, repayment schedule generation, overdue logic, or ledger postings.
- Out of scope: full attachment/document upload workflow from later stories, even though planning docs mention supporting notes or document attachments in the broader requirement set.

### Developer Guardrails

- Reuse the borrower eligibility gate from Story `2.5`; do not add a second, divergent eligibility rule in the application controller or form.
- Re-check blocking application and loan states inside the application creation mutation itself. The borrower detail page is informative, but the service must remain authoritative.
- Keep controllers thin. Creation and update rules belong in dedicated `LoanApplications::*` services or equivalent domain seams, not in controller branches or Stimulus code.
- Do not introduce client-side business logic for editable-vs-locked state. The server must remain the source of truth for whether application details can be changed.
- Preserve the current persisted status vocabulary exactly as it exists in `LoanApplication::STATUSES`. The architecture document prefers `snake_case`, but the runtime source of truth today is space-separated values such as `in progress`; do not create a silent compatibility break midstream.
- Use `money-rails`-friendly amount storage for requested money values. Do not use floats, formatted strings, or client-only parsing as the persistence boundary for requested amount.
- Use one explicit tenure representation and document it clearly in code and tests. Do not store ambiguous free-text tenure.
- Treat repayment frequency as constrained input now (`weekly`, `bi-weekly`, `monthly`) without pulling repayment-schedule generation forward.
- Treat proposed interest mode as request metadata only in this story. Do not introduce interest calculations, repayment math, or bookkeeping side effects here.
- Snapshot borrower identity fields onto the application at creation time so later borrower edits do not rewrite historical decision context.
- If full attachment support is not yet justified, do not drag in Active Storage or document-management complexity just to satisfy a broad wording of FR15. Prefer a clear deferment note plus a lightweight notes field if necessary.
- Add `paper_trail` coverage or equivalent audit-ready history for application create/update changes if mutable application details would otherwise be invisible in history.
- Keep the borrower link, breadcrumb context, and visible status cues on every application screen so the admin never loses orientation.

### Technical Requirements

- Preferred mutation seams:
  - `LoanApplications::Create`
  - `LoanApplications::UpdateDetails`
- Preferred controller ownership:
  - `BorrowersController` remains read-oriented for borrower detail
  - `LoanApplicationsController` owns application workspace entry and mutation endpoints
- Preferred route shape:
  - add a borrower-scoped create entry point or another clearly borrower-bound REST path for starting a new application
  - add only the minimum member update/edit routes needed for the canonical application workspace
- Application creation requirements:
  - create a borrower-linked `LoanApplication`
  - assign a stable visible application number
  - set an explicit starting status
  - snapshot borrower identity onto the application
  - redirect into the application workspace/form
- Application detail requirements:
  - requested amount must use safe server-side numeric handling aligned with `money-rails`
  - requested tenure must use one canonical unit with clear validation
  - requested repayment frequency must support only `weekly`, `bi-weekly`, and `monthly`
  - proposed interest mode must stay compatible with later FR42 work and must not force both rate and total-interest inputs prematurely
  - optional notes/context field is acceptable if it helps keep the request reviewable without pulling document uploads forward
- Edit-lock requirements:
  - allowed while status is still pre-decision
  - blocked once final decision outcomes exist on the record
  - blocked attempts must return a clear user-facing explanation without silently dropping changes
- Rendering requirements:
  - keep HTML-first Rails responses
  - use standard form errors for validation failures
  - use redirects or re-rendered forms consistent with the current borrower workflow
  - use ViewComponent/shared UI primitives where reuse is meaningful, not ad hoc duplicated markup

### Architecture Compliance

- `app/models/loan_application.rb`: persistence, validations, canonical status vocabulary, snapshot associations, and any `paper_trail` declaration
- `app/services/loan_applications/*.rb`: create/update business mutations and edit-lock enforcement
- `app/controllers/loan_applications_controller.rb`: HTTP orchestration only
- `app/views/loan_applications/*.erb`: server-rendered application workspace and form surfaces
- `app/components/loan_applications/*.rb` or `app/components/shared/*.rb`: reusable workflow-significant UI such as status blocks, field groups, or blocked-state callouts
- `app/queries/borrowers/history_query.rb`: existing borrower eligibility/read seam that should continue to determine whether creation can begin
- `app/policies/loan_application_policy.rb`: likely home if this story formalizes resource-level authorization
- `config/routes.rb`: minimal RESTful route expansion for create/update flow
- `db/migrate/*`: schema changes for pre-decision detail fields and borrower snapshot fields
- `spec/requests`, `spec/services` or `spec/models`, `spec/system`, and optionally `spec/policies`: test layers mirroring runtime structure

### File Structure Requirements

Likely implementation touchpoints:

- `config/routes.rb`
- `app/controllers/loan_applications_controller.rb`
- `app/models/loan_application.rb`
- `app/services/loan_applications/create.rb`
- `app/services/loan_applications/update_details.rb`
- `app/views/loan_applications/show.html.erb`
- optionally `app/views/loan_applications/_form.html.erb`
- optionally `app/views/loan_applications/edit.html.erb`
- optionally `app/components/loan_applications/*.rb`
- optionally `app/components/shared/*.rb`
- `app/queries/borrowers/history_query.rb`
- `app/views/borrowers/show.html.erb`
- `app/components/borrowers/detail_header_component.*`
- `app/policies/loan_application_policy.rb`
- `db/migrate/*_add_pre_decision_fields_to_loan_applications.rb`
- `spec/requests/loan_applications_spec.rb`
- `spec/system/*application*`
- `spec/services/loan_applications/*` or `spec/models/loan_application_spec.rb`
- optionally `spec/policies/loan_application_policy_spec.rb`

Avoid touching these unless a concrete need emerges:

- `app/services/loans/*` for downstream approval/disbursement logic
- repayment, overdue, and ledger services
- dashboard/list queries outside the borrower-to-application slice
- borrower search/intake flows unrelated to exposing the application CTA
- attachment/document workflows from later stories

### UX and Interaction Requirements

- Starting a new application should feel like the natural next step from the borrower detail page, not like a disconnected jump to a different mini-product.
- The borrower detail experience should keep its clear eligibility signal, but eligible states should now expose a concrete action instead of only future-facing copy.
- After creation, the admin should land on an application page that preserves breadcrumb context back to the borrower and makes the current status immediately visible.
- The application page should answer two questions at a glance: "Which borrower is this for?" and "What can I safely edit right now?"
- Validation errors should remain on the form and read in calm operational language, consistent with the borrower intake flow.
- Locked/final states should be obvious through status treatment and explanatory copy, not by silently disabling fields with no context.
- Continue the existing desktop-first detail-page grammar: strong headings, clear section boundaries, semantic badges/callouts, and visible next-step guidance.
- Do not rely on color alone to communicate editable, blocked, or final states.

### Previous Story Intelligence

- Story `2.5` already established the borrower page as the trusted place to decide whether new application work may begin.
- Story `2.5` also established an honesty-first pattern: it reused existing seams, refused to fake unfinished workflows, and kept the controller thin. Story `3.1` should keep that discipline while finally introducing the real mutation.
- The current borrower detail slice already links to minimal loan-application and loan read surfaces. Story `3.1` should extend those surfaces rather than replacing them with a parallel workflow.
- The borrower eligibility rules already account for blocking applications and blocking loans. Reuse that vocabulary and do not reinterpret active states ad hoc in a second place.
- The biggest lesson from Epic 2 is reuse-first vertical slicing: add the smallest real workflow that satisfies the user-visible need and leaves the next story with a clean seam.

### Testing Requirements

- Add request coverage for:
  - authenticated application creation from an eligible borrower context
  - blocked creation when the borrower has a blocking application
  - blocked creation when the borrower has a blocking loan
  - successful update while the application is still editable
  - rejected validation on invalid pre-decision fields
  - blocked update once the application is in a final decision state
- Add service/model coverage for:
  - application number generation
  - borrower snapshot persistence at create time
  - allowed repayment-frequency values
  - any interest-mode validation introduced here
  - edit-lock enforcement for final decision states
- Add system coverage proving the admin can:
  - open an eligible borrower
  - start a new application from that borrower context
  - land on the application workspace with borrower linkage intact
  - save editable pre-decision fields and see the updated result
  - understand why edits are blocked when the record is no longer editable
- If a `LoanApplicationPolicy` is introduced, add focused policy specs rather than leaving authorization behavior implicit.
- Reuse current request/system authentication helpers, borrower/application factories, and APP-number patterns.

### Git Intelligence Summary

- Recent commits show a deliberate vertical slice through borrower identity, borrower intake, borrower search, borrower detail/history, borrower eligibility, and then borrower-linked application detail browsing.
- `Add borrower eligibility workflow.` is the clearest immediate predecessor: Story `3.1` should directly replace its placeholder "next story" messaging with a real create-and-edit application flow.
- `Add loan detail browser coverage.` confirms the project is already comfortable adding thin read surfaces before richer write workflows. Story `3.1` should evolve the existing application surface instead of discarding it.
- The current working tree is clean, so there is no need to design around unrelated in-progress code changes.

### Latest Technical Information

- `Gemfile.lock` currently pins:
  - `rails 8.1.3`
  - `turbo-rails 2.0.23`
  - `view_component 4.6.0`
  - `pundit 2.5.2`
  - `paper_trail 17.0.0`
  - `money-rails 3.0.0`
  - `double_entry 2.0.2`
  - `aasm 5.5.2`
- Live version checks confirm Rails `8.1.3` and `turbo-rails 2.0.23` are current stable references as of 2026-04-13.
- Follow the versions already installed in this repo. Do not introduce dependency churn just to implement Story `3.1`.
- The architecture document references `ViewComponent` and HTML-first Rails patterns; the repo's installed `ViewComponent 4.6.0` should be treated as the runtime source of truth over older artifact text.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` - Epic 3, Story `3.1`, FR10, FR15, FR16, FR18, FR23
- `/_bmad-output/planning-artifacts/prd.md` - borrower-to-application journey, explicit application statuses, editable pre-decision boundary, borrower snapshotting requirement
- `/_bmad-output/planning-artifacts/architecture.md` - service/query/controller boundaries, ViewComponent/Turbo/Pundit patterns, testing organization, audit and amount-handling expectations
- `/_bmad-output/planning-artifacts/ux-design-specification.md` - operational clarity, next-valid-action visibility, linked record context, blocked-state communication
- `/_bmad-output/planning-artifacts/implementation-readiness-report-2026-03-30.md` - explicit FR15 wording for required pre-decision application details
- `/_bmad-output/implementation-artifacts/2-5-evaluate-borrower-eligibility-for-a-new-application.md`
- `app/controllers/borrowers_controller.rb`
- `app/queries/borrowers/history_query.rb`
- `app/controllers/loan_applications_controller.rb`
- `app/views/loan_applications/show.html.erb`
- `app/models/loan_application.rb`
- `app/models/loan.rb`
- `app/controllers/application_controller.rb`
- `app/policies/application_policy.rb`
- `config/routes.rb`
- `db/schema.rb`
- `spec/factories/loan_applications.rb`
- `spec/requests/borrowers_spec.rb`
- `spec/requests/loan_applications_spec.rb`
- `Gemfile`
- `Gemfile.lock`

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-04-13T19:29:42+0530
- BMad config loaded from `_bmad/bmm/config.yaml`
- Sprint auto-discovery selected `3-1-create-a-borrower-linked-application-and-maintain-loan-details` as the first backlog story
- Planning context gathered from Epic 3, the PRD, the architecture document, the UX specification, the implementation-readiness report, the previous story artifact, the current borrower/application runtime seams, and recent git history
- No `project-context.md` file was found in the workspace during story preparation
- Live checks confirmed current Rails and `turbo-rails` context; repo dependency pins were used as the runtime source of truth for the rest of the stack
- Story reviewed against the create-story checklist before finalizing
- Implemented the borrower-started application workflow, canonical application workspace, locked-state handling, and pre-decision persistence updates for Story `3.1`
- Added model, service, request, query, and system coverage; full RSpec suite passed with 110 examples and no failures

### Implementation Plan

- Extend the existing borrower eligibility seam with a borrower-scoped create endpoint that delegates to `LoanApplications::Create` and redirects immediately into the application workspace.
- Add audited pre-decision application persistence and edit-lock behavior in `LoanApplication` plus `LoanApplications::UpdateDetails`, while preserving the current status vocabulary and leaving later review-step/final-decision stories untouched.
- Evolve the existing application show page into the canonical HTML-first workspace with borrower linkage, status visibility, validation feedback, lock-state messaging, and focused regression coverage across request, service/model, query, and system layers.

### Completion Notes List

- Added the MVP pre-decision application fields, borrower snapshot persistence, APP-number generation, and `paper_trail` coverage for application create/update history.
- Replaced the borrower detail placeholder with a real `Start application` action that re-checks eligibility server-side before creating a new `open` application.
- Turned the existing loan application page into the canonical pre-decision workspace with editable details, validation feedback, summary rendering, and lock messaging after final decisions.
- Added focused model, service, request, query, and system coverage; `bundle exec rspec` passed with 110 examples and 95.29% line coverage / 86.07% branch coverage.

### File List

- `_bmad-output/implementation-artifacts/3-1-create-a-borrower-linked-application-and-maintain-loan-details.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/components/borrowers/detail_header_component.rb`
- `app/components/borrowers/detail_header_component.html.erb`
- `app/components/borrowers/linked_records_panel_component.html.erb`
- `app/controllers/loan_applications_controller.rb`
- `app/models/loan_application.rb`
- `app/queries/borrowers/history_query.rb`
- `app/services/loan_applications/create.rb`
- `app/services/loan_applications/update_details.rb`
- `app/views/borrowers/show.html.erb`
- `app/views/loan_applications/_form.html.erb`
- `app/views/loan_applications/show.html.erb`
- `config/initializers/money.rb`
- `config/routes.rb`
- `db/migrate/20260413150000_add_pre_decision_fields_to_loan_applications.rb`
- `db/schema.rb`
- `spec/factories/loan_applications.rb`
- `spec/models/loan_application_spec.rb`
- `spec/queries/borrowers/history_query_spec.rb`
- `spec/requests/borrower_loan_applications_spec.rb`
- `spec/requests/borrowers_spec.rb`
- `spec/requests/loan_applications_spec.rb`
- `spec/services/loan_applications/create_spec.rb`
- `spec/services/loan_applications/update_details_spec.rb`
- `spec/system/borrower_detail_flow_spec.rb`
- `spec/system/loan_application_workflow_spec.rb`

### Change Log

- 2026-04-13: Created the Story `3.1` implementation guide and prepared sprint tracking to move the story to `ready-for-dev`.
- 2026-04-13: Implemented the borrower-linked application creation and pre-decision details workspace, including audit history, locked-state handling, and focused automated coverage.

### Review Findings

- [x] [Review][Patch] Requested amount accepts zero or negative values [app/models/loan_application.rb:42]
- [x] [Review][Patch] Application number allocation is not concurrency-safe and can raise on duplicate `APP-` numbers [app/models/loan_application.rb:54]
