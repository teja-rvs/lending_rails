# Story 2.2: Create Borrower Intake Flow

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want to create a borrower from a clear intake form,
so that I can bring a new borrower into the lending workflow without ambiguity.

## Acceptance Criteria

1. **Given** the admin is authenticated  
   **When** they open the borrower creation flow  
   **Then** they see a clear borrower intake form with explicit labels and calm validation feedback  
   **And** the form matches the product's desktop-first and accessibility-oriented UX direction

2. **Given** the admin enters valid borrower information  
   **When** they submit the borrower form  
   **Then** the system creates the borrower record successfully  
   **And** the admin is taken to an appropriate post-create borrower context

3. **Given** the admin enters a duplicate or invalid phone number  
   **When** they submit the borrower form  
   **Then** the system blocks creation with a specific, actionable error  
   **And** the admin can correct the issue without losing orientation

## Tasks / Subtasks

- [x] Add the authenticated borrower intake HTTP surface using the existing Rails HTML-first patterns (AC: 1, 2, 3)
  - [x] Add `resources :borrowers, only: %i[new create show]` in `config/routes.rb` unless an equally clear route shape is required for the story
  - [x] Create `app/controllers/borrowers_controller.rb` with thin `new` and `create` actions that delegate persistence to the existing borrower service seam
  - [x] Keep the route protected by the repo's existing authentication and admin-only access boundary; do not add public borrower access
  - [x] Add a minimal `show` action and page only if needed to satisfy the post-create context cleanly without prematurely implementing full borrower history or search stories

- [x] Build the borrower intake page with explicit, desktop-first form structure and calm feedback (AC: 1, 3)
  - [x] Create `app/views/borrowers/new.html.erb` and extract a `_form.html.erb` partial only if reuse with the minimal post-create surface materially improves clarity
  - [x] Follow the current Tailwind-heavy server-rendered form style already used in `app/views/sessions/new.html.erb`
  - [x] Keep labels explicit, field grouping simple, and page framing aligned with the borrower-create wireframe rather than inventing a denser dashboard-style layout
  - [x] Render invalid submissions with `render :new, status: :unprocessable_entity` so field values, inline errors, and orientation remain intact

- [x] Reuse the Story 2.1 borrower identity foundation instead of re-implementing create logic (AC: 2, 3)
  - [x] Submit borrower creation through `Borrowers::Create.call(...)` rather than calling `Borrower.create` directly from the controller
  - [x] Permit only the smallest justified intake attributes already supported by the borrower model and planning artifacts, currently `full_name` and `phone_number`
  - [x] Preserve the service-backed duplicate handling path that translates database uniqueness races into a normal validation-style `phone_number` error
  - [x] Do not add speculative borrower fields such as KYC, banking, underwriting, address, or notes unless the implementation uncovers a documented planning dependency

- [x] Define the post-create borrower context explicitly without dragging later stories forward (AC: 2)
  - [x] Redirect successful creates to a thin borrower confirmation/detail page that shows the saved borrower identity and a clear next-step orientation
  - [x] Keep that page intentionally minimal: identity summary, success confirmation, and room for future actions, but no borrower search/list/history workflow yet
  - [x] Avoid implementing Story 2.3 search/list, Story 2.4 linked-history detail, or Story 2.5 application-eligibility logic in this story

- [x] Keep authorization and app boundaries aligned with the architecture (AC: 1, 2, 3)
  - [x] Add `app/policies/borrower_policy.rb` if controller-level authorization is introduced, granting only the admin-only actions needed now
  - [x] Keep business rules in the model/service layer, not in JavaScript or view conditionals
  - [x] Use standard flash and field-error patterns already supported by `app/views/layouts/application.html.erb`

- [x] Add focused automated coverage for the borrower intake flow (AC: 1, 2, 3)
  - [x] Add request coverage for authenticated access, successful create, invalid-phone failure, and duplicate-phone failure
  - [x] Add a system spec for the end-to-end happy path and at least one actionable-error path using the real form labels
  - [x] Reuse existing borrower factories and keep service/model tests focused on 2.1 behavior rather than duplicating them at every layer

### Review Findings

- [x] [Review][Patch] Guard malformed borrower IDs on the thin show route [`app/controllers/borrowers_controller.rb:17`]
- [x] [Review][Patch] Add explicit accessibility semantics to borrower form error feedback [`app/views/borrowers/new.html.erb:19`]

## Dev Notes

### Story Intent

This story turns the borrower foundation from Story `2.1` into the first real borrower-facing operational workflow. The core outcome is not "more borrower fields"; it is a trustworthy, low-friction borrower creation flow that lets an authenticated admin add a borrower, recover gracefully from duplicate or invalid data, and land in a sensible post-create context without losing confidence in the system.

### Epic Context and Downstream Dependencies

- Epic 2 covers borrower intake, borrower search, borrower detail/history, and borrower eligibility for new application work.
- Story `2.1` already established the borrower model, canonical phone normalization, duplicate prevention, and a service seam for safe creates.
- Story `2.2` should expose that capability through a real HTML-first admin workflow.
- Story `2.3` will add borrower search and list browsing, so this story should not try to solve lookup UX beyond clear create-time validation.
- Story `2.4` will add richer borrower detail and linked lending history, so any post-create borrower page in this story should stay intentionally thin.
- Story `2.5` will evaluate whether the borrower can begin a new application; do not pull loan-application eligibility logic into this story.
- Epic 3 depends on clean borrower creation so later application creation can start from a stable borrower record.

### Current Codebase Signals

- `app/models/borrower.rb` already owns borrower normalization, invalid-phone validation, and duplicate-phone checks.
- `app/services/borrowers/create.rb` already exists to convert `ActiveRecord::RecordNotUnique` races into a normal borrower validation error. Reuse it.
- `app/services/application_service.rb` defines the repo's `.call` service convention.
- `config/routes.rb` currently exposes only auth/workspace routes, so borrower routing will be new and should remain HTML-first.
- `app/views/sessions/new.html.erb` and `app/views/home/index.html.erb` are the clearest current UI references for spacing, typography, button treatment, and server-rendered form patterns.
- `app/views/layouts/application.html.erb` already renders global `alert` and `notice` feedback; field-level feedback should complement that layout rather than duplicate it.
- `app/controllers/application_controller.rb` already enforces authentication and admin-only access across protected surfaces.
- `app/policies/application_policy.rb` defaults everything to false, so if this story introduces `authorize` calls it must add an explicit `BorrowerPolicy`.

### Scope Boundaries

- In scope: authenticated borrower `new/create` flow, explicit form labels, actionable validation handling, successful borrower persistence, and a thin post-create borrower context.
- In scope: strong parameter handling for the already-supported borrower attributes and test coverage for the new HTTP/UI surface.
- Out of scope: borrower edit flow, borrower search/list browsing, linked lending history, application creation, borrower eligibility rules, document upload, or richer dashboard navigation.
- Out of scope: adding extra borrower data fields not justified by the current planning artifacts.

### Developer Guardrails

- Do not bypass `Borrowers::Create` from the controller. That service already protects the duplicate-phone race path that a naive `Borrower.create` call would surface poorly.
- Do not move borrower identity rules into Stimulus or ad hoc client-side formatting logic. Client-side hints are acceptable, but the canonical validation path must stay server-side.
- Keep the create form grounded in the existing borrower schema from Story `2.1`. The safest implementation is a small form with `full_name` and `phone_number`.
- Use calm, actionable error language. Duplicate and invalid phone scenarios should tell the admin what to fix, not just that something failed.
- Preserve orientation on invalid submission by re-rendering the same page with entered values and inline error feedback.
- Treat UI completeness as both functional and visual. Epic 1's retro explicitly called out wireframe alignment as part of "done" for UI-facing stories.

### Technical Requirements

- Add an authenticated borrower create route and controller surface that fits the Rails monolith's existing HTML-first flow.
- Use `Borrowers::Create` as the borrower write seam for create operations.
- Accept only the smallest justified borrower intake fields already present in the model: `full_name` and `phone_number`.
- Successful create must persist the borrower and redirect to a clear post-create borrower context.
- Invalid or duplicate phone submissions must keep the admin on the intake flow with actionable errors and no loss of orientation.
- Keep responses server-rendered; do not introduce a parallel JSON API or a client-managed form state architecture for this story.
- If a minimal borrower `show` page is added, keep it intentionally thin and future-friendly rather than implementing full borrower history early.

### Architecture Compliance

- `config/routes.rb`: add the borrower route surface using standard Rails resource routing.
- `app/controllers/borrowers_controller.rb`: keep the controller thin and orchestration-focused.
- `app/services/borrowers/create.rb`: reuse the existing create service seam for persistence and duplicate handling.
- `app/models/borrower.rb`: treat the model as the source of borrower normalization and validation rules; avoid duplicating them elsewhere.
- `app/views/borrowers/new.html.erb`: primary form surface for the intake workflow.
- `app/views/borrowers/show.html.erb`: optional thin success/detail surface if used for post-create orientation.
- `app/policies/borrower_policy.rb`: add only if the controller begins using `authorize`, but prefer policy-backed authorization if introducing a new protected resource surface.
- `spec/requests/borrowers_spec.rb`: request-level proof that auth gates, create success, and create failures behave correctly.
- `spec/system/borrower_intake_flow_spec.rb`: end-to-end proof that the form is usable and errors are actionable.

### File Structure Requirements

Likely implementation touchpoints:

- `config/routes.rb`
- `app/controllers/borrowers_controller.rb`
- `app/views/borrowers/new.html.erb`
- optionally `app/views/borrowers/_form.html.erb`
- optionally `app/views/borrowers/show.html.erb`
- optionally `app/policies/borrower_policy.rb`
- `spec/requests/borrowers_spec.rb`
- `spec/system/borrower_intake_flow_spec.rb`
- possibly `app/views/home/index.html.erb` if the workspace should expose a borrower-create entry point now

Avoid touching these in Story `2.2` unless a concrete implementation detail truly requires it:

- `app/models/loan_application.rb`
- `app/models/loan.rb`
- `app/queries/borrowers/*`
- `app/components/borrowers/*` unless a component meaningfully reduces duplication in the small intake flow
- any API-only controller or JavaScript-heavy client state layer

### UX and Interaction Requirements

- The wireframe intent is "simple, explicit data-entry form with duplicate-awareness and clear save path."
- The page should feel desktop-first, calm, and operationally trustworthy, not consumer-signup styled or overly dense.
- Labels should be explicit and visible; do not rely on placeholders as the only field description.
- Validation should feel composed and corrective. Inline field errors are preferred for correction guidance, while flash can support success state after redirect.
- The create flow should make the primary action obvious and the successful next state understandable.
- Accessibility direction matters here: use semantic labels, standard Rails form helpers, clear focusable controls, and readable contrast consistent with the existing UI.

### Previous Story Intelligence

- Story `2.1` deliberately kept borrower scope small and warned against speculative borrower schema expansion. Respect that boundary here.
- Story `2.1` identified the phone storage/lookup strategy as the highest-risk implementation mistake. Do not introduce UI logic that undermines canonical server-side normalization.
- Story `2.1` added `Borrowers::Create` specifically so future write flows can show duplicate-phone failures cleanly even when the DB unique index wins a race. This story is the first real consumer of that decision and should preserve it.
- Story `2.1` also avoided placeholder service/query scaffolding. Continue that discipline: add only the HTTP/UI pieces this story genuinely needs.
- Epic 1's retrospective established that UI stories are not done on behavior alone; they also need wireframe alignment.

### Testing Requirements

- Add request specs proving unauthenticated access is redirected to sign-in for borrower-create surfaces.
- Add request specs proving an authenticated admin can load the borrower intake page and create a borrower successfully.
- Add request specs proving duplicate and invalid phone submissions do not create records and return actionable feedback with an unprocessable response.
- Add a system spec that exercises the real borrower form labels and the end-to-end happy path.
- Add at least one system-level error-path spec for duplicate or invalid phone handling so the UX requirement is tested, not assumed.
- Reuse existing borrower factory data and the service/model coverage already added in Story `2.1` rather than duplicating foundation assertions unnecessarily.

### Git Intelligence Summary

- Recent history shows the repo just finished stabilizing the authenticated workspace: `Update workspace route coverage.`, `Establish borrower identity foundations.`, `Complete Epic 1 retrospective.`, `Add auth coverage reporting and browser specs.`, and `Complete authenticated workspace entry and logout flow.`.
- That means the current story should extend the existing protected workspace patterns instead of inventing a parallel shell or auth approach.
- The last lending-domain commit established borrower persistence but intentionally stopped before adding routes, controllers, or views. This story should add those missing pieces without bundling borrower search or richer borrower detail.

### Latest Technical Information

- Rails `8.1.3` is the current stable `8.1` release as of late March 2026. The repo is on `rails ~> 8.1.2`, so this story should stay within the existing Rails 8.1 HTML-first conventions rather than inventing compatibility workarounds.
- Current Rails guidance continues to center `form_with` as the standard form helper with native Turbo compatibility. Use `form_with` for the borrower intake form.
- `phonelib 0.10.17` remains the current release as of March 2026, which matches the version already pinned in the repo. Reuse it through the model/service layer instead of introducing alternate phone parsing libraries.
- `shadcn-rails` documentation continues to support Rails-native form composition, but this story does not need generator-driven component expansion unless a specific component meaningfully improves the small intake flow.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` - Epic 2, Story 2.2, Stories 2.3-2.5 dependency context
- `/_bmad-output/planning-artifacts/prd.md` - admin journey, borrower creation goals, duplicate-prevention rule, borrower-first workflow context
- `/_bmad-output/planning-artifacts/architecture.md` - Rails monolith direction, HTML-first routing, borrower/service/controller boundaries, policy guidance
- `/_bmad-output/planning-artifacts/ux-design-specification.md` - desktop-first form direction, validation posture, accessibility expectations
- `/_bmad-output/planning-artifacts/ux-wireframes-pages/05-5-create-edit-borrower.html` - borrower create/edit wireframe and duplicate-awareness note
- `/_bmad-output/implementation-artifacts/2-1-establish-borrower-identity-and-searchable-records.md`
- `/_bmad-output/implementation-artifacts/epic-1-retro-2026-03-31.md`
- `app/controllers/application_controller.rb`
- `app/models/borrower.rb`
- `app/services/application_service.rb`
- `app/services/borrowers/create.rb`
- `app/views/layouts/application.html.erb`
- `app/views/sessions/new.html.erb`
- `app/views/home/index.html.erb`
- `config/routes.rb`
- `Gemfile`

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-04-01T07:37:43+0530
- BMad config loaded from `_bmad/bmm/config.yaml`
- Sprint auto-discovery selected `2-2-create-borrower-intake-flow` as the first backlog story
- No `project-context.md` file was found in the workspace during story preparation
- Planning context gathered from Epic 2, the PRD, the architecture document, the UX specification, the borrower create/edit wireframe, and the Epic 1 retrospective
- Previous implementation context gathered from Story `2.1` plus the current borrower model/service/runtime codebase state
- Live version checks confirmed current Rails 8.1 and `phonelib` guidance before finalizing the story
- Docker Desktop started so the repo's local PostgreSQL dependency could be launched from `compose.yaml`
- Executed `docker compose up -d postgres` to restore the local test database dependency
- Added borrower request and system specs first, then implemented the route/controller/view flow to satisfy the failing examples
- Validated the completed story with `bundle exec rspec` and `bundle exec rubocop config/routes.rb app/controllers/borrowers_controller.rb spec/requests/borrowers_spec.rb spec/system/borrower_intake_flow_spec.rb`

### Implementation Plan

- Add a thin, authenticated borrower create route/controller flow that reuses `Borrowers::Create`.
- Build a clear borrower intake form with explicit labels, inline corrective feedback, and a calm desktop-first layout aligned to the wireframe.
- Redirect successful creates into a deliberately thin borrower post-create context without pulling search, edit, or history stories forward.
- Add request and system coverage for the happy path, auth gate, and actionable duplicate/invalid phone flows.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- The most important reuse decision in this story is to route borrower creation through `Borrowers::Create` so duplicate-phone races surface as ordinary user-correctable errors.
- The main scope-control decision is to satisfy the post-create context with a thin borrower success/detail surface instead of prematurely implementing borrower search or rich borrower history.
- UI completion for this story should include wireframe alignment, not just passing tests and a functional create action.
- Implemented a protected borrower intake flow with `new`, `create`, and thin `show` surfaces using the existing admin-only Rails shell.
- Added a calm desktop-first borrower form with inline validation feedback, preserved field values on invalid submission, and a minimal post-create confirmation page with next-step orientation.
- Added automated coverage for authenticated access, successful borrower creation, invalid phone handling, and duplicate phone handling at both request and system levels.
- Confirmed the full RSpec suite passes after the story implementation (`51 examples, 0 failures`).

### File List

- `_bmad-output/implementation-artifacts/2-2-create-borrower-intake-flow.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/controllers/borrowers_controller.rb`
- `app/views/borrowers/new.html.erb`
- `app/views/borrowers/show.html.erb`
- `app/views/home/index.html.erb`
- `config/routes.rb`
- `spec/requests/borrowers_spec.rb`
- `spec/system/borrower_intake_flow_spec.rb`

### Change Log

- 2026-04-01: Created the Story `2.2` implementation guide and moved sprint tracking to `ready-for-dev`.
- 2026-04-01: Implemented the borrower intake route/controller/views, added a minimal post-create borrower page, exposed the workspace entry point, and added request/system coverage for success plus actionable invalid and duplicate phone flows.
