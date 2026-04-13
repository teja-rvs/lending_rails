# Story 3.3: Progress Review Steps in Sequence

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want to move application review steps forward in the correct order,
so that the review process stays controlled and understandable.

## Acceptance Criteria

1. **Given** an application has multiple review steps  
   **When** the admin acts on the current active step  
   **Then** the system allows completion of the valid step in sequence  
   **And** advances the workflow without skipping required earlier steps

2. **Given** more information is needed during review  
   **When** the admin marks the application as waiting for details or otherwise not ready to proceed  
   **Then** the system keeps the application in a valid in-progress path  
   **And** makes the blocked or pending state clear to the admin

3. **Given** the admin attempts an invalid progression  
   **When** they try to act on a non-current or invalid step  
   **Then** the system blocks the action  
   **And** explains why the review cannot proceed that way

## Tasks / Subtasks

- [x] Add canonical review-step progression services that enforce ordered transitions server-side (AC: 1, 2, 3)
  - [x] Introduce explicit service seams such as `ReviewSteps::Approve` and `ReviewSteps::RequestDetails`, or one equally clear domain-owned transition service that accepts the target step and action without pushing workflow rules into controllers or views
  - [x] Use application/service result objects consistent with current patterns so controllers can redirect or render with clear success and failure states
  - [x] Lock the relevant application or step records during mutation so double-submit or parallel requests cannot create skipped or conflicting workflow state
  - [x] Keep the fixed workflow definition in `ReviewStep::WORKFLOW_DEFINITION` as the single source of truth for step order, labels, and positions

- [x] Enforce valid active-step-only progression rules and block out-of-order actions (AC: 1, 3)
  - [x] Allow progression only when the targeted step is the current active step derived from ordered persisted data, not from params or client state
  - [x] Block actions on non-current, already-final, unknown, or out-of-sequence steps with a user-facing explanation that preserves the current workflow state
  - [x] Keep invalid-progression handling HTML-first and consistent with existing flash/render patterns used in `LoanApplicationsController#update`
  - [x] Ensure successful completion advances the next active step by persisted status changes rather than by duplicated "current step" state

- [x] Define and implement the "waiting for details" path without pulling final decisioning forward (AC: 2)
  - [x] Allow the current active step to move into `waiting for details` when the admin cannot proceed yet
  - [x] Keep `waiting for details` visible as a blocked or pending in-progress state on the application workspace
  - [x] Decide and document how an active step returns from `waiting for details` to a progressable state, but keep the behavior bounded to step progression rather than final application approval, rejection, or cancellation
  - [x] Do not auto-finalize the application, create a loan, or introduce Story `3.5` decision outcomes from a step-level waiting state

- [x] Keep application-level status semantics internally consistent with review-step progression (AC: 1, 2)
  - [x] Define one explicit rule for when the application should remain `open` versus transition to `in progress` during review-step activity
  - [x] Preserve the canonical application status vocabulary exactly as implemented today: `open`, `in progress`, `approved`, `rejected`, `cancelled`
  - [x] Keep `Borrowers::HistoryQuery::BLOCKING_APPLICATION_STATUSES` behavior truthful so borrower eligibility remains correct after step progression begins
  - [x] Reserve final application outcome transitions, loan creation, and closure semantics for Story `3.5` and later stories

- [x] Extend the application workspace with safe progression controls and blocked-state guidance (AC: 1, 2, 3)
  - [x] Reuse `app/views/loan_applications/show.html.erb` as the canonical review workspace instead of creating a parallel review page
  - [x] Show progression actions only for the current active step and keep non-current steps visibly non-actionable
  - [x] Surface clear pending or blocked messaging when a step is in `waiting for details`
  - [x] Show user-facing explanations when an attempted action is rejected because the step is not current or is otherwise invalid
  - [x] Reuse `Shared::StatusBadgeComponent` and current workspace structure so status language, layout rhythm, and orientation stay consistent

- [x] Add minimal routing and controller orchestration for review-step mutations (AC: 1, 2, 3)
  - [x] Add only the routes needed for meaningful workflow actions, following architecture guidance for resource-oriented Rails routes
  - [x] Keep controllers thin, delegating mutation rules to services and preserving HTML-first redirects/renders
  - [x] Keep authentication and any authorization enforcement around the domain action, not just at the button level

- [x] Add focused automated coverage for sequential progression, blocked states, and invalid attempts (AC: 1, 2, 3)
  - [x] Extend service specs to prove ordered progression, out-of-order blocking, waiting-for-details handling, and concurrency-safe behavior
  - [x] Extend request specs to prove authenticated admins can progress the active step, cannot mutate non-current steps, and see clear feedback on blocked actions
  - [x] Extend model specs only where new predicates or transition helpers add real business meaning
  - [x] Extend system coverage so the admin can progress the current step from the application workspace and clearly understand the next state
  - [x] Keep the existing show-page backfill path covered so adding progression does not regress idempotent workflow initialization

### Review Findings

- [x] [Review][Patch] Block review-step mutations after a final application decision [`app/services/review_steps/transition.rb:18`]

## Dev Notes

### Story Intent

This story turns the read-only review workflow from Story `3.2` into a controlled progression path. The core requirement is not merely changing a status field; it is enforcing a canonical sequence for step actions, preserving application-level truth, and making blocked or invalid states obvious in the application workspace.

### Epic Context and Sequencing Risk

- Epic 3 flows from borrower-linked application creation into fixed workflow generation, then into step progression, borrower-history-assisted review, and final application outcomes.
- Story `3.2` intentionally stopped at truthful workflow initialization and visibility. Story `3.3` should add progression without reworking the fixed-step foundation that now exists in the repo.
- The biggest risk is overreaching into Story `3.5` by treating step progression as final application approval, rejection, cancellation, or loan creation.
- A second risk is allowing invalid out-of-order mutations that leave multiple non-final steps in misleading states and break the "one active step" mental model.
- A third risk is changing application statuses in a way that silently breaks borrower eligibility rules or later open-application dashboard filtering.

### Current Codebase Signals

- `app/models/review_step.rb` already defines the fixed canonical workflow, allowed step statuses, active-step derivation, status labels, and badge tones.
- `ReviewStep.active_for(review_steps)` currently returns the first non-final step in position order; this is the existing source of active-step truth and should stay canonical.
- `app/models/loan_application.rb` exposes the current application status vocabulary and delegates active-step lookup through `active_review_step`.
- `app/services/loan_applications/initialize_review_workflow.rb` already backfills and initializes steps idempotently under `loan_application.with_lock`; progression services should follow the same concurrency-aware style.
- `app/controllers/loan_applications_controller.rb` currently owns `show` and `update` only. Review-step progression should not overload `update` with unrelated step-mutation business rules unless the resulting interface stays clear and maintainable.
- `app/views/loan_applications/show.html.erb` is the canonical application workspace and already renders the ordered step list, active step, and current application status.
- `config/routes.rb` currently exposes no `review_steps` routes. Any new route should be minimal and reflect a meaningful domain action rather than a generic CRUD endpoint.
- `app/queries/borrowers/history_query.rb` treats `open`, `in progress`, and `approved` applications as blocking for new application creation. Status changes here have downstream effects outside this story.
- Existing request and system coverage already prove authenticated access, read-only workflow visibility, and idempotent show-page backfill. Story `3.3` should extend those seams instead of building parallel test setups.

### Scope Boundaries

- In scope: ordered review-step progression for the current active step.
- In scope: invalid-progression blocking with user-facing explanations.
- In scope: visible waiting-for-details or pending behavior for the active step.
- In scope: application-status alignment needed to keep review progression truthful.
- In scope: route, controller, service, view, and test changes required for safe HTML-first progression.
- Out of scope: borrower-history display enhancements from Story `3.4`.
- Out of scope: final application approval, rejection, or cancellation from Story `3.5`.
- Out of scope: loan creation, documentation, disbursement, repayment generation, overdue handling, or dashboard-level filtering features outside truthful status continuity.
- Out of scope: admin-configurable workflow editing, step creation, deletion, or reordering.

### Developer Guardrails

- Keep all workflow truth on the server. Do not put sequence enforcement, status derivation, or invalid-action protection in Stimulus or view conditionals alone.
- Reuse `ReviewStep::WORKFLOW_DEFINITION`, `ReviewStep.active_for`, and the persisted `position`/`status` data rather than introducing duplicate step-order constants or client-only current-step tracking.
- Only the current active step should be progressable. Non-current steps must stay non-actionable even if the UI is manipulated.
- Treat `waiting for details` as an explicit business state, not a generic placeholder for every future step.
- If application status changes to `in progress`, make that rule explicit, tested, and consistent across services, queries, and UI copy.
- Do not auto-transition the application into `approved`, `rejected`, or `cancelled` in this story.
- Preserve idempotent workflow initialization and show-page backfill behavior; progression logic must not create duplicate steps or reorder existing steps.
- Keep controllers thin and HTML-first, returning clear flash or render feedback instead of leaking domain exceptions into the UI.
- Reuse existing authentication flow and current status badge patterns so the workspace remains one coherent surface.

### Technical Requirements

- Preferred new service seams:
  - `app/services/review_steps/approve.rb`
  - `app/services/review_steps/request_details.rb`
  - optionally a small shared transition helper if it reduces duplication without hiding domain rules
- Preferred mutation rules:
  - require the target step to belong to the current application
  - require the target step to be the current active step
  - use row locking or equivalent transaction safety
  - return a structured result object with actionable failure messages for blocked attempts
- Preferred application-status rule:
  - define exactly when a review action moves the application from `open` to `in progress`, if at all
  - keep incomplete workflows on a non-final application state
  - leave final-decision status ownership to Story `3.5`
- Preferred waiting-details rule:
  - the active step can enter `waiting for details`
  - the application remains on a valid non-final path
  - the workspace must clearly communicate that progression is paused and why
- Preferred UI behavior:
  - keep progression controls in the existing application show page
  - use standard Rails form/button submissions and redirects or renders
  - keep non-current steps visibly fixed and non-interactive
  - do not rely on color alone to communicate active, blocked, or completed state

### Architecture Compliance

- `app/models/review_step.rb`: canonical workflow definition, step-state vocabulary, labels, active-step derivation, and any lightweight step predicates
- `app/models/loan_application.rb`: canonical application statuses and active-step entry point
- `app/services/review_steps/*`: ordered step progression and blocked-state domain actions
- `app/services/loan_applications/initialize_review_workflow.rb`: unchanged source for fixed step creation and legacy backfill
- `app/controllers/loan_applications_controller.rb` or a small dedicated review-step controller: HTTP orchestration only
- `app/views/loan_applications/show.html.erb`: canonical progression UI and blocked-state messaging
- `app/components/shared/status_badge_component.*`: shared status presentation
- `app/queries/borrowers/history_query.rb`: downstream eligibility truth if application-status semantics change
- `spec/models`, `spec/services`, `spec/requests`, and `spec/system`: mirror runtime responsibilities

### File Structure Requirements

Likely implementation touchpoints:

- `app/models/review_step.rb`
- `app/models/loan_application.rb`
- `app/services/review_steps/approve.rb`
- `app/services/review_steps/request_details.rb`
- optionally `app/services/review_steps/*.rb` for a shared transition base only if it improves clarity
- `app/controllers/loan_applications_controller.rb` or a dedicated `app/controllers/review_steps_controller.rb`
- `app/views/loan_applications/show.html.erb`
- optionally `app/components/loan_applications/*.rb` if progression controls or blocked-state callouts become complex enough to justify extraction
- `config/routes.rb`
- `app/queries/borrowers/history_query.rb` if application-status semantics require aligned eligibility behavior
- `spec/models/review_step_spec.rb`
- `spec/models/loan_application_spec.rb`
- `spec/requests/loan_applications_spec.rb`
- `spec/services/review_steps/*_spec.rb`
- `spec/system/loan_application_workflow_spec.rb`

Avoid touching these unless a concrete need emerges:

- final application decision services from Story `3.5`
- loan creation, disbursement, repayment, overdue, or ledger services
- borrower search or intake flows unrelated to truthful progression semantics
- dashboard or reporting queries outside direct application-status continuity

### UX and Interaction Requirements

- The application workspace must continue answering: what is the current application state, what step is active now, and what can happen next.
- Current-step actions should feel explicit and safe, while non-current steps should feel clearly unavailable rather than mysteriously inert.
- A waiting-for-details state should read as blocked or pending, not as silent failure or hidden inactivity.
- Invalid progression attempts must explain why the action is blocked so the admin does not have to infer the rule from missing UI affordances alone.
- Preserve the calm, dependable workspace rhythm already established in the show page: context first, workflow second, request details third.
- Keep status language consistent across application badges, review-step badges, flash messaging, and tests.

### Previous Story Intelligence

- Story `3.2` established `ReviewStep` persistence, the fixed `history_check` -> `phone_screening` -> `verification` sequence, and an idempotent workflow initialization seam.
- Story `3.2` also chose the application show page as the canonical workspace, so Story `3.3` should extend that page instead of creating a detached review surface.
- The strongest carry-forward lesson is that workflow truth should come from persisted ordered records plus service logic, not duplicated browser state or temporary placeholders.
- Story `3.2` also left a clean seam for future progression services and explicitly reserved sequential progression, waiting-for-details behavior, and invalid-step blocking for this story.

### Git Intelligence Summary

- Recent commits show a clean vertical progression through Epic 3:
  - `Add borrower-linked application workflow.`
  - `Add fixed application review workflow.`
- The working tree is currently clean, so this story can assume repo context without needing to route around unrelated local edits.
- Current implementation style favors extending the existing workflow surface and keeping services explicit rather than introducing generic abstractions too early.

### Latest Technical Information

- `Gemfile.lock` pins the current runtime stack used by this repo:
  - `rails 8.1.3`
  - `turbo-rails 2.0.23`
  - `view_component 4.6.0`
  - `pundit 2.5.2`
  - `paper_trail 17.0.0`
- Live web checks confirm `rails 8.1.3` as the current stable Rails 8.1 bugfix release as of 2026-04-13.
- Treat the versions already installed in this repo as the implementation source of truth for Story `3.3`; do not introduce dependency churn just to add review-step progression.
- Keep using HTML-first Rails flows with Turbo-compatible redirects/renders and server-owned business logic rather than moving workflow state into richer client-side behavior.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` - Epic 3, Story `3.3`, FR19, FR20, FR21
- `/_bmad-output/planning-artifacts/prd.md` - Journey 1, Journey 3, application/review status vocabulary and blocked-review expectations
- `/_bmad-output/planning-artifacts/architecture.md` - workflow-centric domain rules, service boundaries, HTML-first routing, ViewComponent/Turbo constraints, naming and structure patterns
- `/_bmad-output/planning-artifacts/ux-design-specification.md` - workflow clarity, blocked-state explanations, status legibility, calm and predictable operational detail pages
- `/_bmad-output/planning-artifacts/implementation-readiness-report-2026-03-30.md` - FR19, FR20, FR21 coverage alignment
- `/_bmad-output/planning-artifacts/prd-validation-report-2026-03-30.md` - canonical review-step naming confirmation carried forward from Story `3.2`
- `/_bmad-output/implementation-artifacts/3-2-generate-the-fixed-review-workflow.md`
- `app/models/review_step.rb`
- `app/models/loan_application.rb`
- `app/services/loan_applications/create.rb`
- `app/services/loan_applications/update_details.rb`
- `app/services/loan_applications/initialize_review_workflow.rb`
- `app/controllers/loan_applications_controller.rb`
- `app/views/loan_applications/show.html.erb`
- `app/queries/borrowers/history_query.rb`
- `config/routes.rb`
- `spec/models/review_step_spec.rb`
- `spec/services/loan_applications/initialize_review_workflow_spec.rb`
- `spec/requests/loan_applications_spec.rb`
- `spec/system/loan_application_workflow_spec.rb`
- `Gemfile.lock`

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-04-13T20:46:44+0530
- BMad config loaded from `_bmad/bmm/config.yaml`
- Sprint auto-discovery selected `3-3-progress-review-steps-in-sequence` as the first backlog story
- Planning context gathered from Epic 3, the PRD, the architecture document, the UX specification, the implementation-readiness and PRD-validation reports, the previous story artifact, the current review-step runtime seams, recent git history, and a focused read-only codebase review
- No `project-context.md` file was found in the workspace during story preparation
- Live checks confirmed current Rails 8.1 and Turbo context; repo dependency pins were used as the runtime source of truth for the rest of the stack
- Story reviewed against the create-story checklist concerns before finalizing, with added guardrails for sequence enforcement, waiting-for-details clarity, and borrower-eligibility-safe application status handling
- Sprint tracking moved the story from `ready-for-dev` to `in-progress` before implementation began
- Added explicit `ReviewSteps::Approve` and `ReviewSteps::RequestDetails` services on top of a shared transition service that locks the application and derives the active step from persisted ordered workflow records
- Added a dedicated `ReviewStepsController` and minimal nested member routes so review-step mutations stay HTML-first and controller-thin
- Extended `app/views/loan_applications/show.html.erb` with current-step-only actions and waiting-for-details guidance while preserving the existing workspace structure
- Added focused service, request, and system coverage for sequential progression, blocked mutations, waiting-for-details behavior, and workspace interaction
- Ran `bundle exec rspec` successfully: 137 examples, 0 failures
- Ran targeted `bundle exec rubocop` on edited Ruby files successfully: 9 files, 0 offenses

### Implementation Plan

- Use a shared transition service to validate the target review step under `loan_application.with_lock`, keeping workflow order and active-step derivation server-owned.
- Allow `Approve` from `initialized` and `waiting for details`, while `RequestDetails` moves only the current `initialized` step into a blocked in-progress state.
- Keep the application show page as the canonical review surface with current-step-only actions, clear blocked guidance, and focused regression coverage.

### Completion Notes List

- Implemented ordered review-step mutations through explicit `ReviewSteps::Approve` and `ReviewSteps::RequestDetails` services backed by a shared locking/result seam.
- Kept application status semantics truthful by promoting applications from `open` to `in progress` on the first review action without introducing any Story `3.5` final outcomes.
- Reused the application workspace as the canonical review surface, adding current-step-only controls, waiting-for-details guidance, and clear feedback for blocked attempts.
- Added focused service, request, and system coverage for approval, waiting-for-details, out-of-order blocking, authentication, and workspace progression behavior.
- Verified the story with `bundle exec rspec` and targeted `bundle exec rubocop` on the edited Ruby files.

### File List

- `_bmad-output/implementation-artifacts/3-3-progress-review-steps-in-sequence.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/controllers/review_steps_controller.rb`
- `app/services/review_steps/transition.rb`
- `app/services/review_steps/approve.rb`
- `app/services/review_steps/request_details.rb`
- `app/views/loan_applications/show.html.erb`
- `config/routes.rb`
- `spec/requests/loan_applications_spec.rb`
- `spec/services/review_steps/approve_spec.rb`
- `spec/services/review_steps/request_details_spec.rb`
- `spec/system/loan_application_workflow_spec.rb`

### Change Log

- 2026-04-13: Created the Story `3.3` implementation guide and prepared sprint tracking to move the story to `ready-for-dev`.
- 2026-04-13: Implemented sequential review-step progression, waiting-for-details handling, workspace controls, and focused regression coverage; moved the story to `review`.
