# Story 3.2: Generate the Fixed Review Workflow

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want each new application to receive the system-defined review steps automatically,
so that every application follows the same controlled MVP decision path.

## Acceptance Criteria

1. **Given** an application is ready for review  
   **When** the review workflow is initialized  
   **Then** the system creates the fixed MVP review steps automatically  
   **And** the workflow is system-defined rather than user-configurable

2. **Given** review steps have been created  
   **When** the admin opens the application  
   **Then** they can see the active step and the current application status clearly  
   **And** review-step statuses use the agreed canonical vocabulary

3. **Given** the application review is underway  
   **When** the admin inspects the workflow state  
   **Then** the application and review-step status values remain internally consistent  
   **And** the UI makes it obvious what stage is active now

## Tasks / Subtasks

- [x] Introduce canonical review-step persistence and vocabulary for loan applications (AC: 1, 2, 3)
  - [x] Add a `ReviewStep` model plus migration(s) for a borrower-linked application workflow, using UUID foreign keys and Rails-standard timestamps
  - [x] Persist the minimum workflow fields needed for this story: `loan_application_id`, stable step key, display/order position, and canonical step status
  - [x] Enforce one fixed step per application position and per step key with database constraints/indexes so retries cannot create duplicates
  - [x] Centralize the fixed MVP review-step definition in one domain-owned place instead of scattering the step list across models, controllers, views, and specs
  - [x] Use the canonical review-step status vocabulary from planning artifacts: `initialized`, `approved`, `rejected`, and `waiting for details`
  - [x] Treat the PRD-named steps as the default fixed MVP sequence for this story unless a stricter business-approved list already exists in repo context: `history_check`, `phone_screening`, `verification`

- [x] Initialize the fixed workflow through the application service layer and keep it idempotent (AC: 1, 3)
  - [x] Add a dedicated mutation seam such as `LoanApplications::InitializeReviewWorkflow` or `LoanApplications::InitializeReviewSteps`
  - [x] Invoke workflow initialization from the authoritative create path in `LoanApplications::Create` rather than from controllers, views, callbacks, or ad hoc console-only scripts
  - [x] Wrap application creation and review-step creation in one transaction so a failed workflow insert cannot leave a half-created application state
  - [x] Ensure blocked borrower-eligibility paths do not create any review-step records
  - [x] Make initialization idempotent so retries, repeated calls, or backfill logic do not duplicate the workflow for the same application
  - [x] Define how pre-existing `LoanApplication` rows created before Story `3.2` receive review steps, either through an explicit backfill task/path or a clearly bounded idempotent bootstrap on access

- [x] Keep application-status and review-step-state semantics internally consistent without pulling Story `3.3` forward (AC: 2, 3)
  - [x] Preserve the existing application status vocabulary exactly as implemented today: `open`, `in progress`, `approved`, `rejected`, `cancelled`
  - [x] Define one explicit initialization rule for how application status relates to newly created review steps and document it in code and tests
  - [x] Prefer keeping the application in its existing safe initial state unless there is a product-backed reason to transition status during workflow initialization
  - [x] Do not invent a second inactive-step vocabulary outside the canonical statuses; if future steps need to remain not-yet-completed, keep that meaning derivable from ordering and the existing status model
  - [x] Reserve sequential progression, invalid-step blocking, waiting-for-details actions, and final approval/rejection mechanics for Stories `3.3` and `3.5`

- [x] Extend the application workspace so the admin can see the active review step clearly (AC: 2, 3)
  - [x] Evolve the canonical application workspace in `app/views/loan_applications/show.html.erb` to include a review-workflow section instead of creating a parallel review page
  - [x] Show the current application status and the active review step together so the admin can understand both the overall application state and the immediate workflow stage at a glance
  - [x] Render the fixed ordered step list in a clear server-rendered form, reusing existing shared UI primitives such as `Shared::StatusBadgeComponent` where practical
  - [x] Derive the active step from the canonical ordered review-step data rather than hard-coded view logic or JavaScript-only state
  - [x] Keep borrower linkage, breadcrumbs, and current request details visible so workflow visibility adds context instead of replacing it
  - [x] Do not add progression buttons, decision actions, or editable step outcomes in this story beyond truthful visibility of the initialized workflow

- [x] Add audit-ready and future-safe review-step support (AC: 1, 2, 3)
  - [x] If review-step records will become mutable in later stories, add `has_paper_trail` or equivalent history support now so step-state changes do not become unaudited later
  - [x] Keep step-state mutations and later progression hooks in domain services, not in controllers, components, or Stimulus behavior
  - [x] Leave a clean seam for later story-owned services such as `ReviewSteps::Approve`, `ReviewSteps::Reject`, and `ReviewSteps::RequestDetails`

- [x] Add focused automated coverage for initialization, visibility, and non-duplication (AC: 1, 2, 3)
  - [x] Add model coverage for canonical status validation, ordering, associations, and uniqueness expectations on `ReviewStep`
  - [x] Add service coverage proving application creation initializes the fixed workflow exactly once and remains transactional
  - [x] Add request coverage proving the application show page exposes the active step and ordered review workflow to authenticated admins
  - [x] Add coverage for any backfill/idempotent initialization path so previously created applications receive the workflow without duplicate rows
  - [x] Extend system coverage from borrower-started application creation into the application workspace so the admin can see the initialized review workflow immediately after creation

### Review Findings

- [x] [Review][Patch] Completed workflows are still shown as having an active step [`app/models/review_step.rb:44`]
- [x] [Review][Patch] The default `review_step` factory creates invalid records outside the canonical workflow [`spec/factories/review_steps.rb:2`]

## Dev Notes

### Story Intent

This story turns the application workspace created in Story `3.1` into the true starting point of the review lifecycle. The goal is to create the system-owned review-step records automatically, make the active stage visible on the application page, and establish a canonical workflow foundation that later stories can progress without reworking application creation.

### Epic Context and Sequencing Risk

- Epic 3 moves from borrower-linked application capture into fixed workflow generation, then into step progression, borrower-history-assisted review, and final outcomes.
- Story `3.1` explicitly left a seam for fixed review-step generation and warned against inventing placeholder workflow data there.
- The biggest risk in Story `3.2` is overreaching into Story `3.3` by implementing progression mechanics, waiting-for-details actions, or invalid-step blocking too early.
- A second risk is silently changing application status semantics in a way that breaks borrower eligibility rules from Story `2.5`, because `Borrowers::HistoryQuery` treats `open`, `in progress`, and `approved` applications as blocking.
- A third risk is leaving older `LoanApplication` records without review steps, creating split behavior between new and existing applications.

### Current Codebase Signals

- `app/models/loan_application.rb` already defines the application status vocabulary, lock rules, labels, tones, and `paper_trail` coverage for the application record itself.
- `app/services/loan_applications/create.rb` is the authoritative creation seam and is the correct place to add review-workflow initialization.
- `app/services/loan_applications/update_details.rb` already owns pre-decision mutation rules and should remain separate from review-step initialization.
- `app/controllers/loan_applications_controller.rb` is intentionally thin and currently exposes only `show` and `update`.
- `app/views/loan_applications/show.html.erb` is now the canonical application workspace and should gain review-workflow visibility rather than being replaced.
- `config/routes.rb` does not expose any `review_steps` routes yet, and the repo currently has no `ReviewStep` model, no `review_steps` table, and no workflow-specific factories/specs.
- `_bmad-output/planning-artifacts/architecture.md` describes aspirational paths such as `app/models/review_step.rb`, `app/services/review_steps/*`, and `app/controllers/review_steps_controller.rb`, but those runtime files do not exist yet.
- `_bmad-output/planning-artifacts/prd.md` names example fixed-step types including history checking, phone screening, and verification, but it does not provide a stronger single canonical step list elsewhere in the repo.
- `_bmad-output/planning-artifacts/prd-validation-report-2026-03-30.md` flags FR17 as underspecified and explicitly recommends naming the MVP review steps or pointing to one canonical step list.

### Scope Boundaries

- In scope: fixed review-step persistence for loan applications.
- In scope: automatic workflow generation for newly created applications.
- In scope: idempotent handling for pre-existing applications that do not yet have steps.
- In scope: visible active-step and ordered workflow rendering on the application workspace.
- In scope: canonical review-step status vocabulary and the rules needed to keep it compatible with application statuses.
- In scope: schema, model, service, view/component, and test changes required for truthful workflow initialization.
- Out of scope: step progression actions, waiting-for-details transitions, rejection/approval actions, or invalid-order blocking.
- Out of scope: borrower-history panels within the application review experience beyond what already exists from borrower/application context today.
- Out of scope: loan creation, documentation, disbursement, repayment generation, overdue handling, audit dashboards, or document-upload workflow expansion.

### Developer Guardrails

- Keep the review workflow system-defined. Do not add UI or params that let admins create, delete, reorder, or rename steps.
- Put workflow initialization in a dedicated service and call it from the create path. Do not hide business-critical step creation in model callbacks, view code, or Stimulus.
- Make workflow initialization idempotent and protected by database constraints so retries cannot duplicate steps.
- Treat application creation plus workflow generation as one atomic unit. A loan application should not persist successfully without its fixed workflow unless the code explicitly handles a bounded backfill path.
- Preserve the current application status vocabulary exactly as implemented in `LoanApplication::STATUSES`.
- Do not auto-transition the application from `open` to another status during initialization unless the product rule is deliberate, documented, and covered by tests.
- Do not assign misleading placeholder states to future steps. If `waiting for details` implies an actual business condition, reserve it for later progression logic rather than using it as a generic not-yet-active marker.
- Keep active-step derivation server-side from ordered canonical data; do not encode business truth only in the browser.
- Reuse the current application workspace and shared status-badge pattern so the admin sees one coherent application surface.
- If review steps will change state in later stories, add history support now so step-level lifecycle changes are auditable from the start.

### Technical Requirements

- Preferred new domain seams:
  - `app/models/review_step.rb`
  - `app/services/loan_applications/initialize_review_workflow.rb`
  - optionally `app/services/review_steps/*` as empty future seams only if they clarify structure without pulling scope forward
- Preferred `ReviewStep` data requirements:
  - belongs to `LoanApplication`
  - stable `step_key` or equivalent canonical identifier
  - ordered `position`
  - status constrained to `initialized`, `approved`, `rejected`, `waiting for details`
  - uniqueness at least on `[loan_application_id, step_key]` and on `[loan_application_id, position]`
- Preferred fixed-step definition:
  - central constant or service-owned template list
  - default sequence: `history_check`, `phone_screening`, `verification`
  - one human-readable label source so views/specs do not drift from service/model vocabulary
- Preferred active-step rule:
  - derive from ordered review-step records
  - avoid separate duplicated "current_step" state unless a concrete need emerges
  - if all steps are still freshly initialized, the first ordered step should be the visible active step
- Initialization requirements:
  - create steps automatically from `LoanApplications::Create`
  - remain safe on retry
  - avoid creating steps for blocked borrower-eligibility results
  - provide one clear strategy for existing applications created before this story
- Rendering requirements:
  - keep HTML-first Rails responses
  - extend the current `show` page rather than introducing a new review page
  - prefer ViewComponent/shared primitives where reuse is meaningful
  - keep the workflow display readable without relying on color alone

### Architecture Compliance

- `app/models/loan_application.rb`: existing application status vocabulary and associations remain canonical
- `app/models/review_step.rb`: persistence, validation, associations, step labels/helpers, and optional `paper_trail`
- `app/services/loan_applications/create.rb`: authoritative application creation seam that should trigger workflow initialization
- `app/services/loan_applications/initialize_review_workflow.rb`: canonical fixed-step bootstrap and idempotency logic
- `app/controllers/loan_applications_controller.rb`: HTTP orchestration only
- `app/views/loan_applications/show.html.erb`: server-rendered application workspace with visible active-step context
- `app/components/shared/status_badge_component.*`: existing shared status primitive to reuse if step statuses need visible badges
- optionally `app/components/loan_applications/*`: reusable workflow UI if the step display becomes complex enough to justify extraction
- `db/migrate/*`: schema support for review steps and any backfill-safe constraints
- `spec/models`, `spec/services`, `spec/requests`, and `spec/system`: test structure mirroring runtime responsibilities

### File Structure Requirements

Likely implementation touchpoints:

- `app/models/loan_application.rb`
- `app/models/review_step.rb`
- `app/services/loan_applications/create.rb`
- `app/services/loan_applications/initialize_review_workflow.rb`
- optionally `app/services/review_steps/*.rb`
- `app/controllers/loan_applications_controller.rb`
- `app/views/loan_applications/show.html.erb`
- optionally `app/components/loan_applications/*.rb`
- `app/components/shared/status_badge_component.rb`
- `app/components/shared/status_badge_component.html.erb`
- `config/routes.rb` only if a read-only review-step route is truly needed; otherwise keep route expansion minimal in this story
- `db/migrate/*_create_review_steps.rb`
- `db/schema.rb`
- `spec/factories/review_steps.rb`
- `spec/models/review_step_spec.rb`
- `spec/services/loan_applications/create_spec.rb`
- `spec/services/loan_applications/initialize_review_workflow_spec.rb`
- `spec/requests/loan_applications_spec.rb`
- `spec/system/loan_application_workflow_spec.rb`

Avoid touching these unless a concrete need emerges:

- approval/rejection/cancellation services from later stories
- loan creation and disbursement services
- repayment, overdue, and ledger services
- borrower search/intake flows unrelated to truthful application review initialization
- document-upload workflows from later stories

### UX and Interaction Requirements

- The application workspace should now answer a third core question at a glance in addition to borrower and status context: "What review stage is active now?"
- The active step should be visible immediately after the admin lands on the application page, especially after starting a new application from the borrower detail page.
- The step list should look fixed, controlled, and system-owned, not configurable or ad hoc.
- Application status and review-step status should be readable together without making the admin infer how they relate.
- The workflow section should reinforce the product's calm operational tone: clear labels, ordered stages, and obvious current-stage visibility.
- The UI should preserve the existing breadcrumb, borrower linkage, and request-summary context so review visibility enhances orientation rather than replacing it.
- Do not rely on color alone to distinguish the active step or step state.
- Do not introduce action controls that imply progression is available if this story has not yet implemented those rules.

### Previous Story Intelligence

- Story `3.1` deliberately created the application record and canonical application workspace without inventing fake review-step records.
- Story `3.1` also established the create-service seam and the application show page as the right places for this story to extend, not replace.
- The strongest carry-forward lesson is reuse-first vertical slicing: grow the real borrower-to-application flow honestly, keep controllers thin, and leave future stories clear seams instead of speculative logic.
- Story `3.1` also preserved the existing application status vocabulary and eligibility rules; Story `3.2` must not break those assumptions while adding workflow structure.

### Testing Requirements

- Add model coverage for:
  - canonical `ReviewStep` status validation
  - ordered position handling
  - uniqueness per application for step key and position
  - any helper used to derive the active step
- Add service coverage for:
  - successful application creation creating the fixed step set exactly once
  - transactional rollback if step creation fails
  - no step creation for blocked borrower-eligibility outcomes
  - idempotent/backfill behavior for pre-existing applications
- Add request coverage proving:
  - authenticated admins can open the application workspace and see the active step plus ordered review workflow
  - unauthenticated users remain blocked as before
  - any read path used to backfill steps does not duplicate them on repeated access
- Add system coverage proving the admin can:
  - start a new application from the borrower page
  - land on the application workspace
  - immediately understand the fixed review workflow and the active current step
- Reuse current request/system authentication helpers, `APP-` application numbering patterns, and existing application factories instead of introducing parallel setup.

### Git Intelligence Summary

- Recent commits show a clean vertical slice from borrower history and eligibility into borrower-linked application creation.
- `Add borrower-linked application workflow.` is the direct predecessor and explicitly created the seam this story should now use.
- The repo is currently clean, so Story `3.2` does not need to work around unrelated local changes.
- Existing implementation style favors extending the current workflow surface rather than creating parallel temporary pages or duplicate business rules.

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
- Live checks confirm `rails 8.1.3` and `turbo-rails 2.0.23` are current stable references as of 2026-04-13.
- Treat the versions already installed in this repo as the runtime source of truth for Story `3.2`; do not introduce dependency churn just to add fixed review-step initialization and visibility.
- `ViewComponent 4.6.0` is the repo's UI component baseline, and the story should prefer that runtime truth over older planning-artifact version references.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` - Epic 3, Story `3.2`, FR16, FR17, FR18, FR19, FR20, FR21
- `/_bmad-output/planning-artifacts/prd.md` - Journey 1, Journey 3, FR16, FR17, FR19, FR20, FR59
- `/_bmad-output/planning-artifacts/architecture.md` - service/query/controller boundaries, status vocabulary rules, ViewComponent/Turbo patterns, aspirational review-step structure
- `/_bmad-output/planning-artifacts/ux-design-specification.md` - operational clarity, active-stage visibility, status communication, desktop-first detail-page behavior
- `/_bmad-output/planning-artifacts/implementation-readiness-report-2026-03-30.md` - FR15-FR21 coverage and FR17 underspecification signal
- `/_bmad-output/planning-artifacts/prd-validation-report-2026-03-30.md` - recommendation to name the MVP review steps or define one canonical step list
- `/_bmad-output/implementation-artifacts/3-1-create-a-borrower-linked-application-and-maintain-loan-details.md`
- `app/models/loan_application.rb`
- `app/services/loan_applications/create.rb`
- `app/services/loan_applications/update_details.rb`
- `app/controllers/loan_applications_controller.rb`
- `app/views/loan_applications/show.html.erb`
- `app/queries/borrowers/history_query.rb`
- `app/components/shared/status_badge_component.rb`
- `config/routes.rb`
- `spec/requests/loan_applications_spec.rb`
- `spec/system/loan_application_workflow_spec.rb`
- `Gemfile.lock`

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-04-13T20:08:20+0530
- BMad config loaded from `_bmad/bmm/config.yaml`
- Sprint auto-discovery selected `3-2-generate-the-fixed-review-workflow` as the first backlog story
- Planning context gathered from Epic 3, the PRD, the architecture document, the UX specification, the implementation-readiness and PRD-validation reports, the previous story artifact, the current application runtime seams, recent git history, and a focused read-only seam analysis
- No `project-context.md` file was found in the workspace during story preparation
- Live checks confirmed current Rails and `turbo-rails` context; repo dependency pins were used as the runtime source of truth for the rest of the stack
- Story reviewed against the create-story checklist concerns before finalizing, with added guardrails for step-list canonicalization, idempotent initialization, and existing-record backfill handling
- Implemented `ReviewStep` persistence, canonical workflow definition, and transactional workflow initialization from `LoanApplications::Create`
- Added bounded show-page backfill through `LoanApplications::InitializeReviewWorkflow` for pre-existing applications without duplicate step creation
- Validation run complete: `bundle exec rspec`, targeted `bundle exec rubocop` on changed files, and `bundle exec brakeman --no-pager`

### Implementation Plan

- Introduce a canonical `ReviewStep` model and fixed-step definition, then initialize it from `LoanApplications::Create` in one transactional, idempotent workflow.
- Extend the existing application workspace to show the active step and ordered fixed review workflow without adding progression controls or changing application semantics prematurely.
- Add focused model, service, request, and system coverage around workflow creation, visibility, non-duplication, and existing-record handling.

### Completion Notes List

- Implemented a new `ReviewStep` model, migration, workflow definition, and audit support for the fixed `history_check`, `phone_screening`, and `verification` sequence.
- Updated `LoanApplications::Create` to initialize review steps transactionally and kept blocked borrower-eligibility paths from persisting any workflow rows.
- Added a bounded show-page backfill path so legacy applications receive the fixed workflow exactly once when opened.
- Extended the application workspace to show the current application status, active review step, and ordered fixed workflow without introducing progression controls.
- Added model, service, request, and system coverage for initialization, rollback safety, active-step visibility, and non-duplication, then validated with the full RSpec suite plus RuboCop on changed files and Brakeman.

### File List

- `_bmad-output/implementation-artifacts/3-2-generate-the-fixed-review-workflow.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/controllers/loan_applications_controller.rb`
- `app/models/loan_application.rb`
- `app/models/review_step.rb`
- `app/services/loan_applications/create.rb`
- `app/services/loan_applications/initialize_review_workflow.rb`
- `app/views/loan_applications/show.html.erb`
- `db/migrate/20260413173000_create_review_steps.rb`
- `db/schema.rb`
- `spec/factories/review_steps.rb`
- `spec/models/loan_application_spec.rb`
- `spec/models/review_step_spec.rb`
- `spec/requests/loan_applications_spec.rb`
- `spec/services/loan_applications/create_spec.rb`
- `spec/services/loan_applications/initialize_review_workflow_spec.rb`
- `spec/system/loan_application_workflow_spec.rb`

### Change Log

- 2026-04-13: Created the Story `3.2` implementation guide and prepared sprint tracking to move the story to `ready-for-dev`.
- 2026-04-13: Implemented fixed review-step persistence, transactional initialization/backfill, application workspace visibility, and automated coverage for Story `3.2`.
