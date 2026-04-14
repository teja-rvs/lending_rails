# Story 3.5: Approve, Reject, and Cancel Applications with Preserved History

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want to complete application decisions clearly and preserve the outcomes,
so that every lending decision remains traceable and operationally understandable.

## Acceptance Criteria

1. **Given** an application has satisfied the required review conditions
   **When** the admin approves the application
   **Then** the system records the approved outcome using the canonical status model
   **And** the application is ready for downstream loan creation

2. **Given** an application should not proceed
   **When** the admin rejects or cancels it
   **Then** the system records the correct final outcome
   **And** the reasoned workflow state remains visible in application history

3. **Given** an application has been rejected or cancelled
   **When** the admin searches or browses historical applications later
   **Then** the record remains searchable and reviewable
   **And** the system never treats that historical record as deleted or lost

## Tasks / Subtasks

- [x] Create `LoanApplications::Approve` domain service (AC: 1)
  - [x] Implement in `app/services/loan_applications/approve.rb` following the existing `ReviewSteps::Transition` Result-struct pattern
  - [x] Guard: only allow approval when the loan application status is `in progress` AND every review step has status `approved`
  - [x] Transition the application status from `in progress` to `approved` inside a `with_lock` transaction
  - [x] Return a consistent `Result` struct with `success?` and `blocked?` semantics, including a clear `error` message for blocked cases
  - [x] Do NOT create a loan record here — loan creation belongs to Epic 4, Story 4.1

- [x] Create `LoanApplications::Reject` domain service (AC: 2)
  - [x] Implement in `app/services/loan_applications/reject.rb`
  - [x] Guard: only allow rejection when the application is still in a pre-final-decision state (`open` or `in progress`)
  - [x] Transition the application status to `rejected` inside a `with_lock` transaction
  - [x] Accept an optional `reason` parameter and store it as `decision_notes` on the loan application (add the column if it does not exist)
  - [x] Return the same `Result` pattern

- [x] Create `LoanApplications::Cancel` domain service (AC: 2)
  - [x] Implement in `app/services/loan_applications/cancel.rb`
  - [x] Guard: only allow cancellation when the application is still in a pre-final-decision state (`open` or `in progress`)
  - [x] Transition the application status to `cancelled` inside a `with_lock` transaction
  - [x] Accept an optional `reason` parameter for `decision_notes`
  - [x] Return the same `Result` pattern

- [x] Add controller actions for approve, reject, and cancel (AC: 1, 2)
  - [x] Add `approve`, `reject`, and `cancel` member actions to `LoanApplicationsController`
  - [x] Each action delegates to the corresponding service, translates the result into redirect + flash, and preserves the `from` breadcrumb param
  - [x] On blocked result, redirect back with an `alert` flash containing the error message
  - [x] On success, redirect to the application show page with a `notice` flash

- [x] Add routes for the three new actions (AC: 1, 2)
  - [x] Add `patch :approve`, `patch :reject`, `patch :cancel` as member routes on `loan_applications`

- [x] Add a `decision_notes` column to `loan_applications` if it does not already exist (AC: 2)
  - [x] Create a migration: `add_column :loan_applications, :decision_notes, :text`
  - [x] Add normalization in the model: `normalizes :decision_notes, with: ->(value) { value.to_s.squish.presence }`

- [x] Update the application show page with decision controls (AC: 1, 2)
  - [x] Replace the "reserved for the later decision story" placeholder with actual decision buttons
  - [x] When `workflow_complete` is true AND application is still `in progress`:
    - Show an "Approve application" primary button (maps to `approve_loan_application_path`)
    - Show a "Reject application" danger-styled secondary button (maps to `reject_loan_application_path`)
    - Show a "Cancel application" muted secondary button (maps to `cancel_loan_application_path`)
  - [x] When application is `open` or `in progress` but review is NOT complete:
    - Show "Reject application" and "Cancel application" buttons (approval is blocked until all steps are approved)
    - Do NOT show the "Approve application" button — the review workflow must be completed first
  - [x] When application is already in a final decision state (`approved`, `rejected`, `cancelled`):
    - Show a read-only outcome banner explaining the final decision and the locked state
    - Display `decision_notes` if present
    - Do NOT show any decision buttons
  - [x] Use the established Tailwind card/section styling (`rounded-3xl border border-slate-200 bg-white p-8 shadow-sm`)
  - [x] For reject and cancel, use a simple confirmation pattern (e.g., `data-turbo-confirm`) before submission — these are not money-sensitive so a full guarded dialog is not required, but they are irreversible and should have user confirmation

- [x] Ensure historical records remain searchable and browsable (AC: 3)
  - [x] Verify the existing `LoanApplications::FilteredListQuery` and the application list view already support filtering by `approved`, `rejected`, and `cancelled` statuses — no changes expected here
  - [x] Verify that `paper_trail` captures the status transition (already enabled on `LoanApplication`)
  - [x] Verify that `Borrowers::HistoryQuery` correctly reflects the new terminal statuses in linked records — `approved` is already in `BLOCKING_APPLICATION_STATUSES`; `rejected` and `cancelled` are NOT blocking, which is correct

- [x] Add focused automated coverage (AC: 1, 2, 3)
  - [x] Add service specs for `LoanApplications::Approve` covering: successful approval when all steps approved, blocked when not all steps approved, blocked when application is already in a final state, blocked when application is `open` (not yet progressed)
  - [x] Add service specs for `LoanApplications::Reject` covering: successful rejection from `open`, successful rejection from `in progress`, blocked when already final
  - [x] Add service specs for `LoanApplications::Cancel` covering: successful cancellation from `open`, successful cancellation from `in progress`, blocked when already final
  - [x] Add request specs for the three new controller actions covering: authenticated access, unauthenticated redirect, success path, blocked path
  - [x] Add system specs for the full decision workflow: approve after completing all review steps, reject during review, cancel during review, verify final state is shown correctly, verify decision buttons disappear after a final decision, verify `decision_notes` display

### Review Findings

- [x] [Review][Patch] Replace stale later-story guidance in the completed workflow state [`app/views/loan_applications/show.html.erb:117`]

## Dev Notes

### Story Intent

This is the final story in Epic 3 and delivers the application-level decision outcomes that the review workflow has been building toward. Stories 3.1–3.4 established application creation, the fixed review workflow, step progression, borrower context visibility, and the application list. Story 3.5 adds the three terminal transitions — approve, reject, cancel — that close the application workflow and prepare the system for downstream loan creation (Epic 4).

The critical design decision is that approval requires ALL review steps to be in `approved` status, while rejection and cancellation are available at any point before a final decision. This reflects the business rule that the review process must be fully satisfied before approval, but the admin can abandon or reject an application at any stage.

### Epic Context and Sequencing

- Epic 3 flow: application creation (3.1) → fixed review workflow (3.2) → step progression (3.3) → borrower history in review (3.4) → **final decision outcomes (3.5)**
- This story completes Epic 3. After this, Epic 4 (Story 4.1) picks up with "Create a Loan from an Approved Application."
- The `approved` status on the application becomes the trigger for loan creation in Epic 4. Story 3.5 must NOT create a loan — it only records the approved outcome.
- `Borrowers::HistoryQuery` already treats `approved` applications as blocking (in `BLOCKING_APPLICATION_STATUSES`), so approving an application correctly blocks new applications for the same borrower until the downstream loan lifecycle resolves.

### Current Codebase Signals

- **LoanApplication model:** Already defines `STATUSES` (`open`, `in progress`, `approved`, `rejected`, `cancelled`), `FINAL_DECISION_STATUSES` (`approved`, `rejected`, `cancelled`), and `editable_pre_decision_details?`. `has_paper_trail` is enabled. `status_tone` maps `approved` → `:success`, `rejected`/`cancelled` → `:danger`.
- **ReviewStep model:** `FINAL_STATUSES` = `approved`, `rejected`. `active_candidate?` returns false for final steps. `ReviewStep.active_for(steps)` returns `nil` when all steps are final — this is the `workflow_complete` signal on the show page.
- **LoanApplicationsController:** Has `index`, `create`, `show`, `update`. No approve/reject/cancel actions. `show` already loads `@borrower_history` and sets `workflow_complete` and `editable` view flags.
- **Show page placeholder:** Line reads "Every review step is already complete. Final application outcome handling is reserved for the later decision story." — this is the exact insertion point for decision controls.
- **Routes:** `loan_applications` has `only: %i[index show update]` with nested `review_steps`. Need to add member actions.
- **Service pattern:** All services inherit from `ApplicationService` which provides `self.call(...)` class method delegation. Each service defines an inline `Result = Struct.new(...)` with `success?` and often `blocked?` semantics.
- **No existing approve/reject/cancel services:** Architecture doc lists `LoanApplications::Approve`, `LoanApplications::Reject`, `LoanApplications::Cancel` as planned services. None exist yet.
- **Factory:** Default `status: "open"`. Trait `:with_details` adds loan detail fields. No traits for `in progress`, `approved`, etc. — consider adding these for test readability.

### Scope Boundaries

- **In scope:** Application-level approve, reject, and cancel services, controller actions, routes, show page decision UI, decision_notes column, and focused test coverage.
- **In scope:** Confirmation prompts for reject and cancel (simple `data-turbo-confirm`).
- **In scope:** Read-only outcome banner for final-decision applications.
- **Out of scope:** Loan creation from approved applications (Epic 4, Story 4.1).
- **Out of scope:** Dashboard integration or dashboard-driven application filtering (Epic 6).
- **Out of scope:** Notification or external communication of decision outcomes.
- **Out of scope:** Full guarded confirmation dialogs (UX-DR10) — those are reserved for money-sensitive actions like disbursement. Application decisions are important but not financially irreversible in the same way.
- **Out of scope:** Reject or cancel reason input forms — for MVP, `decision_notes` can be set via a simple hidden or optional text field in the confirmation flow, or left nil. Keep the UI minimal.

### Developer Guardrails

- **Do NOT create a loan record on approval.** The approved status is the handoff point. Loan creation is Story 4.1.
- **Do NOT add a `reject` action to ReviewStepsController.** Review step rejection is architecturally possible but not part of the current MVP workflow — only step approval and request-details are wired. Application-level rejection is a different concept.
- **Approval guard must be strict:** Check that `loan_application.status == "in progress"` AND `loan_application.review_steps.all?(&:final?)` AND `loan_application.review_steps.all? { |s| s.status == "approved" }`. If any step is `rejected`, the application cannot be approved — the admin should reject or cancel the application instead.
- **Use `with_lock` for status transitions** to prevent race conditions, following the pattern established in `ReviewSteps::Transition`.
- **Keep controllers thin.** Each action should be ~5–8 lines: find record, call service, translate result to redirect+flash.
- **Do not modify `Borrowers::HistoryQuery`** — it already handles all five application statuses correctly.
- **Do not modify `LoanApplications::FilteredListQuery`** — it already supports all status values.
- **Do not modify `ReviewSteps::Transition`** — it already checks `editable_pre_decision_details?` to block step changes after final decisions.
- **Preserve the show page layout rhythm:** application header → review workflow → borrower lending context → decision controls / outcome banner → pre-decision details → request summary. The decision section should sit between the borrower lending context and the pre-decision details sections.
- **Use `paper_trail` as-is.** It's already enabled on `LoanApplication`. The status transition will be versioned automatically. Do not add custom audit logging for this story.

### Technical Requirements

- **New migration:** `add_decision_notes_to_loan_applications`
  - `add_column :loan_applications, :decision_notes, :text`

- **Model changes:** `app/models/loan_application.rb`
  - Add `normalizes :decision_notes, with: ->(value) { value.to_s.squish.presence }`
  - Add `def decision_notes_display; decision_notes.presence || "No decision notes recorded"; end`
  - Add `def all_review_steps_approved?; review_steps.loaded? ? review_steps.all? { |s| s.status == "approved" } : review_steps.where.not(status: "approved").none?; end`
  - Add `def approvable?; status == "in progress" && all_review_steps_approved?; end`
  - Add `def rejectable?; !FINAL_DECISION_STATUSES.include?(status); end`
  - Add `def cancellable?; !FINAL_DECISION_STATUSES.include?(status); end`

- **New service:** `app/services/loan_applications/approve.rb`
  - Define `Result = Struct.new(:loan_application, :error, keyword_init: true)` with `success?` and `blocked?`
  - Accept `loan_application:` as sole argument
  - Inside `with_lock`: verify `approvable?`, update status to `approved`
  - Return blocked result with clear message if guard fails

- **New service:** `app/services/loan_applications/reject.rb`
  - Same Result pattern
  - Accept `loan_application:` and optional `decision_notes:`
  - Inside `with_lock`: verify `rejectable?`, update status to `rejected`, set `decision_notes`
  - Return blocked result if guard fails

- **New service:** `app/services/loan_applications/cancel.rb`
  - Same Result pattern
  - Accept `loan_application:` and optional `decision_notes:`
  - Inside `with_lock`: verify `cancellable?`, update status to `cancelled`, set `decision_notes`
  - Return blocked result if guard fails

- **Controller changes:** `app/controllers/loan_applications_controller.rb`
  - Add `before_action :set_loan_application, only: %i[show update approve reject cancel]`
  - Add `approve` action: call `LoanApplications::Approve.call(loan_application:)`, redirect with flash
  - Add `reject` action: call `LoanApplications::Reject.call(loan_application:, decision_notes: params[:decision_notes])`, redirect with flash
  - Add `cancel` action: call `LoanApplications::Cancel.call(loan_application:, decision_notes: params[:decision_notes])`, redirect with flash

- **Route changes:** `config/routes.rb`
  - Add member actions inside the `loan_applications` resource block:
    ```ruby
    member do
      patch :approve
      patch :reject
      patch :cancel
    end
    ```

- **View: decision section** in `app/views/loan_applications/show.html.erb`:
  - New section between borrower lending context and pre-decision details
  - When `FINAL_DECISION_STATUSES.include?(@loan_application.status)`: outcome banner showing the final status, timestamp, and decision notes
  - When `workflow_complete && editable`: approve, reject, cancel buttons
  - When `editable && !workflow_complete`: reject and cancel buttons only (approval blocked — show a note explaining that all review steps must be approved first)
  - Approve button: primary style, `button_to` with `method: :patch`
  - Reject/Cancel buttons: secondary/danger style, `button_to` with `method: :patch` and `data: { turbo_confirm: "Are you sure you want to [reject/cancel] this application? This action cannot be undone." }`

### Architecture Compliance

- `app/services/loan_applications/approve.rb`: new domain service following established pattern
- `app/services/loan_applications/reject.rb`: new domain service following established pattern
- `app/services/loan_applications/cancel.rb`: new domain service following established pattern
- `app/models/loan_application.rb`: model-level predicate helpers (no business logic — just state checks)
- `app/controllers/loan_applications_controller.rb`: thin orchestration, delegates to services
- `app/views/loan_applications/show.html.erb`: extended with decision section
- `config/routes.rb`: route additions only
- `db/migrate/*_add_decision_notes_to_loan_applications.rb`: safe additive migration
- `spec/services/loan_applications/approve_spec.rb`: new service specs
- `spec/services/loan_applications/reject_spec.rb`: new service specs
- `spec/services/loan_applications/cancel_spec.rb`: new service specs
- `spec/requests/loan_applications_spec.rb`: extended with new action specs
- `spec/system/loan_application_workflow_spec.rb`: extended with decision workflow specs

### File Structure Requirements

Likely implementation touchpoints:

- `db/migrate/*_add_decision_notes_to_loan_applications.rb` (new)
- `app/models/loan_application.rb` (extend with predicates and normalization)
- `app/services/loan_applications/approve.rb` (new)
- `app/services/loan_applications/reject.rb` (new)
- `app/services/loan_applications/cancel.rb` (new)
- `app/controllers/loan_applications_controller.rb` (extend with approve, reject, cancel)
- `app/views/loan_applications/show.html.erb` (extend with decision section)
- `config/routes.rb` (add member routes)
- `spec/services/loan_applications/approve_spec.rb` (new)
- `spec/services/loan_applications/reject_spec.rb` (new)
- `spec/services/loan_applications/cancel_spec.rb` (new)
- `spec/requests/loan_applications_spec.rb` (extend)
- `spec/system/loan_application_workflow_spec.rb` (extend)
- `spec/factories/loan_applications.rb` (extend with status traits)

Avoid touching these unless a concrete need emerges:

- `app/services/review_steps/*` — no changes needed
- `app/queries/borrowers/history_query.rb` — already handles all statuses correctly
- `app/queries/loan_applications/filtered_list_query.rb` — already supports all statuses
- `app/views/loan_applications/index.html.erb` — list already shows all statuses
- `app/components/shared/status_badge_component.*` — reuse as-is
- `app/models/review_step.rb` — no changes
- Loan-related models, services, or views (Epic 4+)

### UX and Interaction Requirements

- **Approve button:** Primary action style (dark background, white text). Only visible when all review steps are approved and application is still `in progress`. Uses `button_to` with PATCH method.
- **Reject button:** Danger-secondary style (rose/red border or text, not filled). Available whenever the application is in a pre-decision state. Uses `button_to` with `data-turbo-confirm` for simple browser confirmation.
- **Cancel button:** Muted secondary style (slate border). Available whenever the application is in a pre-decision state. Uses `button_to` with `data-turbo-confirm`.
- **Outcome banner:** When the application is in a final state, show a prominent read-only section with:
  - The final status as a large badge
  - The decision timestamp (use `updated_at` as a proxy since `paper_trail` tracks the transition time)
  - Decision notes if present
  - A clear statement that the application is now locked
- **Button hierarchy:** At most one primary button per context (approve). Reject and cancel are secondary.
- **No decision notes input form for MVP.** If the team wants to capture notes, add a simple optional text field later. For now, decision_notes defaults to nil and can be populated programmatically or in a future enhancement.

### Previous Story Intelligence

- Story 3.4 added the application list view and the borrower lending context section on the show page. The show page layout is now: header → review workflow → borrower lending context → pre-decision details → request summary. Story 3.5 inserts the decision section between borrower lending context and pre-decision details.
- Story 3.4 established `LoanApplications::FilteredListQuery` with full status filtering. All five statuses are already filterable — no changes needed.
- Story 3.3 established the `ReviewSteps::Transition` pattern with `with_lock`, Result structs, and blocked-state messaging. Story 3.5 services should follow the same pattern.
- Story 3.3 confirmed that `paper_trail` tracks review step status changes. Story 3.5 can rely on `paper_trail` to track application status changes automatically.
- The strongest carry-forward lesson: keep the show page as the canonical workspace. All decision controls should live on the show page, not on a separate decision page.

### Git Intelligence Summary

- Recent commits follow clean vertical progression through Epic 3:
  - `Add borrower-linked application workflow.` (Story 3.1)
  - `Add fixed application review workflow.` (Story 3.2)
  - `Add review step progression controls.` (Story 3.3)
  - `Add borrower context in application review and applications list.` (Story 3.4)
- Working tree is clean. Codebase is consistent with established patterns.
- The most recent commit (Story 3.4) added 862 lines across 13 files, primarily the application list view and borrower history section.

### Latest Technical Information

- `Gemfile.lock` pins:
  - `rails 8.1.3`
  - `turbo-rails 2.0.23`
  - `view_component 4.6.0`
  - `pundit 2.5.2`
  - `paper_trail 17.0.0`
  - `aasm 5.5.2` (available but not currently used for LoanApplication — statuses are string-based with manual transitions via services)
  - `shadcn-rails 0.2.1`
  - `pagy` for pagination
- These are the current stable versions already installed. Do not introduce dependency changes for this story.
- Continue using HTML-first Rails flows with Turbo-compatible redirects/renders and server-owned transition logic.
- `data-turbo-confirm` is the standard Turbo way to show browser confirmation dialogs before form submissions.

### Project Structure Notes

- The codebase uses `ApplicationService` as a base class providing `self.call(...)` delegation. All new services should inherit from it.
- The codebase uses `ApplicationQuery` as a base class for query objects. No new queries are needed.
- Result structs are defined inline within each service (not a shared lib class). Follow this pattern.
- Factory traits for loan application statuses do not exist yet. Add `:in_progress`, `:approved`, `:rejected`, `:cancelled` traits to `spec/factories/loan_applications.rb` for test clarity.
- The `Shared::StatusBadgeComponent` maps tones: `success` (emerald), `danger` (rose), `warning` (amber), `neutral` (slate). The existing `status_tone` method on `LoanApplication` already maps `approved` → `:success` and `rejected`/`cancelled` → `:danger`.

### References

- `/_bmad-output/planning-artifacts/epics.md` — Epic 3, Story 3.5, FR25, FR26, FR27, FR28, FR29
- `/_bmad-output/planning-artifacts/prd.md` — Application approval, rejection, cancellation, historical preservation
- `/_bmad-output/planning-artifacts/architecture.md` — Service patterns, controller boundaries, Result-struct pattern, `paper_trail` for auditing
- `/_bmad-output/planning-artifacts/ux-design-specification.md` — Button hierarchy (UX-DR13), blocked-state callouts (UX-DR11), status badge system (UX-DR9)
- `/_bmad-output/implementation-artifacts/3-4-review-borrower-history-during-decisioning.md` — Previous story with show page layout and list view
- `/_bmad-output/implementation-artifacts/3-3-progress-review-steps-in-sequence.md` — Review step transition pattern
- `app/models/loan_application.rb` — Status vocabulary, `FINAL_DECISION_STATUSES`, `editable_pre_decision_details?`
- `app/models/review_step.rb` — Step statuses, `FINAL_STATUSES`, `active_candidate?`
- `app/services/review_steps/transition.rb` — `with_lock`, Result-struct, blocked-state pattern reference
- `app/services/loan_applications/create.rb` — Service and Result-struct pattern reference
- `app/controllers/loan_applications_controller.rb` — Controller to extend
- `app/views/loan_applications/show.html.erb` — Canonical application workspace to extend
- `app/queries/borrowers/history_query.rb` — `BLOCKING_APPLICATION_STATUSES` includes `approved`
- `app/queries/loan_applications/filtered_list_query.rb` — Already supports all status values
- `config/routes.rb` — Route definitions to update
- `spec/factories/loan_applications.rb` — Factory to extend with status traits
- `Gemfile.lock` — Pinned dependency versions

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- 2026-04-14: Focused RSpec execution is currently blocked because PostgreSQL is unreachable on `localhost:5432` in test.
- 2026-04-14: `docker compose up -d postgres` failed because the Docker daemon socket is not available on this machine.
- 2026-04-14: Static verification passed for touched files via `ruby -c`, ERB syntax check, `bundle exec rubocop`, and `ReadLints`.
- 2026-04-14: Started the repo `postgres` service with Docker Compose and prepared the test database after the daemon became available.
- 2026-04-14: Focused Story 3.5 specs passed (`50 examples, 0 failures`).
- 2026-04-14: Full regression suite passed (`176 examples, 0 failures`).

### Completion Notes List

- Implemented `LoanApplications::Approve`, `LoanApplications::Reject`, and `LoanApplications::Cancel` with `with_lock` transactions and consistent `Result` structs.
- Added `decision_notes` persistence support through a new migration, schema update, model normalization, and model-level decision helpers.
- Extended `LoanApplicationsController`, routes, and the application show page to support approve/reject/cancel outcomes while preserving the `from` breadcrumb context.
- Added focused service, request, and system specs plus factory traits for terminal application statuses.
- Verified the story with focused specs, the full RSpec suite, ERB/Ruby syntax checks, RuboCop, and linter diagnostics before moving the story to review.

### File List

- `_bmad-output/implementation-artifacts/3-5-approve-reject-and-cancel-applications-with-preserved-history.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/controllers/loan_applications_controller.rb`
- `app/models/loan_application.rb`
- `app/services/loan_applications/approve.rb`
- `app/services/loan_applications/cancel.rb`
- `app/services/loan_applications/reject.rb`
- `app/views/loan_applications/show.html.erb`
- `config/routes.rb`
- `db/migrate/20260414111000_add_decision_notes_to_loan_applications.rb`
- `db/schema.rb`
- `spec/factories/loan_applications.rb`
- `spec/requests/loan_applications_spec.rb`
- `spec/services/loan_applications/approve_spec.rb`
- `spec/services/loan_applications/cancel_spec.rb`
- `spec/services/loan_applications/reject_spec.rb`
- `spec/system/loan_application_workflow_spec.rb`

### Change Log

- 2026-04-14: Implemented the Story 3.5 application decision flow, added focused automated coverage, and completed validation before moving the story to review.
