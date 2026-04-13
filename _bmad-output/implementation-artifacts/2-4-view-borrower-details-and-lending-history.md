# Story 2.4: View Borrower Details and Lending History

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want a borrower detail page with prior lending context,
so that I can understand the borrower's history before taking the next action.

## Acceptance Criteria

1. **Given** the admin opens a borrower record  
   **When** the borrower detail page loads  
   **Then** it presents a clear entity header with borrower identity and current lending context  
   **And** the page follows the shared detail-page UX patterns for orientation and top actions

2. **Given** the borrower has related applications or loans  
   **When** the admin views the borrower detail  
   **Then** they can see linked lending records and prior borrowing history in one place  
   **And** they can navigate from the borrower into the relevant linked records without losing context

3. **Given** the borrower has no prior lending history  
   **When** the admin views the borrower detail  
   **Then** the system communicates that state clearly  
   **And** still makes the next relevant action obvious

## Tasks / Subtasks

- [x] Replace the thin borrower `show` page with a real detail-page composition that stays inside the current authenticated Rails shell (AC: 1, 3)
  - [x] Keep `app/controllers/borrowers_controller.rb#show` thin and delegate read-side assembly to a borrower-scoped query or read service instead of embedding joins or branching presentation logic in the controller
  - [x] Rework `app/views/borrowers/show.html.erb` to follow the borrower-detail wireframe and shared detail-page patterns: breadcrumb/orientation, stable entity header, current lending context summary, and clear top actions
  - [x] Preserve the existing protected admin-only boundary from `ApplicationController`; do not introduce any public borrower detail surface

- [x] Add a borrower detail read model for lending context and history (AC: 1, 2, 3)
  - [x] Introduce `app/queries/borrowers/history_query.rb` or an equivalently named borrower-scoped read model alongside `Borrowers::LookupQuery`
  - [x] Assemble borrower identity, current lending context, linked records, and history presentation data in a deterministic order suitable for the server-rendered detail page
  - [x] Avoid N+1 loading and keep the detail view performant enough to align with the documented ~2 second page-load target for borrower detail flows

- [x] Surface linked lending records and borrower history without dragging full later workflows forward (AC: 2)
  - [x] Show related applications and loans together in one clearly labeled section with visible identifiers and state cues when that data exists
  - [x] Link to relevant read surfaces when those routes/resources exist; if a minimal linked-record read surface must be introduced here to satisfy navigation, keep it read-only, RESTful, and as small as possible
  - [x] If application and loan runtime models are still absent at implementation time, introduce only the smallest schema/model/routing seam needed to support borrower-linked read history for this story, aligned with architecture naming (`LoanApplication`, `Loan`, `loan_applications`, `loans`) and without pulling in approval, disbursement, repayment, or edit workflows

- [x] Provide clear empty, partial-history, and next-step guidance on the borrower detail page (AC: 1, 3)
  - [x] Distinguish between "no lending history yet" and "history exists but some linked context is limited"
  - [x] Make the next relevant action obvious from the borrower detail page, but do not implement or imply Story `2.5` eligibility enforcement logic as complete in this story
  - [x] Keep blocked or unavailable states explanatory and calm; do not leave the admin at a dead end

- [x] Introduce reusable UI primitives only where they reduce future drift and match the architecture direction (AC: 1, 2, 3)
  - [x] Prefer `ViewComponent` primitives under `app/components/borrowers/` or `app/components/shared/` for the entity header / linked-record panel if extracting them keeps the detail view maintainable
  - [x] Reuse `ApplicationComponent` as the component base if new components are introduced
  - [x] Do not build a bespoke client-heavy interaction layer or a parallel design system for this screen

- [x] Add focused automated coverage for borrower detail and history behavior (AC: 1, 2, 3)
  - [x] Extend request coverage in `spec/requests/borrowers_spec.rb` for authenticated show access, unauthenticated redirect, borrower detail rendering, no-history messaging, and linked-record presentation when related data exists
  - [x] Add a system spec such as `spec/system/borrower_detail_flow_spec.rb` that drives from the protected workspace or borrower list into the detail view and verifies orientation, visible lending context, and recovery/next-step clarity
  - [x] Add targeted query/component specs if new borrower history queries or components are introduced, rather than overloading request/system specs with all internal behavior assertions

### Review Findings

- [x] [Review][Patch] Add coverage for linked-record navigation and linked read surfaces [`spec/system/borrower_detail_flow_spec.rb`, `spec/requests/borrowers_spec.rb`]
- [x] [Review][Patch] Preserve status-tone cues on the loan-application detail page [`app/views/loan_applications/show.html.erb`]
- [x] [Review][Patch] Make the borrower detail request assertions deterministic and scoped to the created records [`spec/requests/borrowers_spec.rb`]

## Dev Notes

### Story Intent

This story turns the intentionally thin borrower record page into the first real borrower anchor page. The goal is not a full CRM profile or a future-heavy lending console; it is a trustworthy, detail-oriented surface that answers who the borrower is, what lending history exists, and what the admin can reasonably do next without guessing.

### Epic Context and Sequencing Risk

- Epic 2 covers borrower creation, search/browse, borrower detail/history, and borrower eligibility for new applications.
- Story `2.3` intentionally stopped at a thin borrower detail page and deferred richer history and linked record visibility to Story `2.4`.
- Story `2.5` depends on this story to make borrower-level lending context legible before eligibility is evaluated.
- Epic 3 and Epic 4 later introduce the fuller application and loan workflows, which means Story `2.4` must be careful not to invent broad lending workflows just to render borrower history.
- The planning set intentionally deferred Story `2.4` out of Sprint 1 as richer visibility work; this story should add only the borrower-detail/history slice needed now, not a premature end-to-end lending module.

### Current Codebase Signals

- `app/controllers/borrowers_controller.rb` currently loads the borrower in `show` with a direct `Borrower.find(params[:id])` and no read-model composition.
- `app/views/borrowers/show.html.erb` explicitly says the page is intentionally light until later stories add fuller borrower history and linked workflow actions. This story owns that expansion.
- `app/queries/borrowers/lookup_query.rb` establishes the current namespaced query-object pattern and should be treated as the model for a borrower detail/history query.
- `app/models/borrower.rb` already owns canonical phone normalization and remains the borrower identity source of truth.
- `app/models` currently contains only `ApplicationRecord`, `Borrower`, `Current`, `Session`, and `User`. There are no runtime `LoanApplication` or `Loan` model files yet.
- `app/queries` currently contains only `ApplicationQuery` and `Borrowers::LookupQuery`; there is no borrower history query yet.
- `config/routes.rb` exposes borrower index/new/create/show routes but no application or loan routes yet.
- `app/components/application_component.rb` exists as the base `ViewComponent`, but the repo does not yet have shared entity-header or linked-record components.
- `ApplicationController` already enforces authentication, admin-only access, `Pundit`, and `PaperTrail` user attribution at the application boundary.
- `config/initializers/paper_trail.rb` enables `PaperTrail`, but there is no evidence yet that borrower or future lending models have `has_paper_trail` configured in runtime code.

### Scope Boundaries

- In scope: a richer authenticated borrower detail page, borrower identity summary, current lending context summary, linked record/history visibility, detail-page orientation, and clear next-step messaging.
- In scope: a borrower-scoped read seam for history/current-context assembly and the smallest linked-record navigation support needed for this story.
- In scope: focused test coverage for detail-page rendering, linked history presentation, and no-history clarity.
- Out of scope: borrower edit flows, full application CRUD, full loan CRUD, review workflows, disbursement, repayment, overdue handling, audit exploration tooling, or any money-critical mutation path.
- Out of scope: fully implementing borrower eligibility rules for starting a new application; Story `2.5` owns that policy and messaging in depth.
- Out of scope: a JavaScript-heavy SPA/detail experience or speculative cross-entity search beyond the borrower detail surface.

### Developer Guardrails

- Keep the controller thin. Read-side composition belongs in a borrower query/read service, not in controller conditionals or the ERB template.
- Reuse the existing admin-only shell and borrower navigation flow. Do not add a parallel detail entry path outside the current authenticated workspace.
- Treat the lack of current `LoanApplication` and `Loan` runtime code as a sequencing constraint, not permission to invent broad future architecture. If minimal read-only seams are necessary, keep them aligned with planned naming and resource structure.
- Do not implement approval, rejection, disbursement, repayment, overdue, or other money-sensitive actions here just to make history look richer.
- Do not claim Story `2.5` eligibility is done just because a "Create application" next step is visible. Eligibility enforcement and reasons belong to the next story.
- Avoid dead or misleading links. If a linked record is shown, the navigation path should resolve to a meaningful read surface inside the workspace.
- Do not fabricate a timeline/audit UI disconnected from real persisted data. If activity/timeline UI is introduced, it must be backed by actual linked-record events or real version/audit data.
- Keep the page HTML-first and server-driven. Add Turbo behavior only if it improves clarity without creating a second source of truth.
- Preserve calm operational UX language. Empty, partial-history, and blocked states should explain the situation and the safest next step without sounding vague or alarming.

### Technical Requirements

- Prefer a borrower-scoped read object such as `Borrowers::HistoryQuery` under `app/queries/borrowers/` to assemble the show-page data.
- Maintain a deterministic presentation order for linked history so the borrower detail surface remains predictable and testable.
- Use Rails-standard plural REST naming and `snake_case` params/keys if this story introduces any new routes or query params.
- If new runtime lending models or tables are required to satisfy the borrower history acceptance criteria, keep them read-oriented and minimal, matching the planned domain names from the architecture rather than ad hoc placeholders.
- Ensure the detail page can render a no-history state cleanly without requiring lending records to exist.
- Protect against N+1 query behavior when rendering linked applications/loans/history.
- Consider `fresh_when` or other standard Rails response freshness helpers only if they remain simple and do not obscure correctness or test clarity.
- If component extraction is justified, keep it small and reusable: entity header / summary block, linked-record panel, and possibly a lightweight history block are the most likely candidates.
- Keep all business/state interpretation server-side; any Stimulus behavior should be purely local UI enhancement.

### Architecture Compliance

- `app/controllers/borrowers_controller.rb`: keep the `show` action orchestration-focused and compatible with the current authentication/authorization boundary
- `app/queries/borrowers/history_query.rb`: preferred home for borrower detail/history read composition
- `app/models/borrower.rb`: continue to treat borrower identity and normalized phone behavior as canonical here
- `app/views/borrowers/show.html.erb`: primary borrower detail/history UI surface
- `app/components/application_component.rb`: base for any new ViewComponent extraction
- `app/components/borrowers/*` or `app/components/shared/*`: preferred location for reusable entity header / linked-record UI primitives if extracted
- `config/routes.rb`: update only if a minimal read-only application or loan detail navigation path is required to satisfy linked-record navigation
- `spec/requests/borrowers_spec.rb`: request-level proof for borrower detail access and rendered states
- `spec/system/borrower_detail_flow_spec.rb` or equivalent: end-to-end proof that borrower detail/history is understandable and operationally usable

### File Structure Requirements

Likely implementation touchpoints:

- `app/controllers/borrowers_controller.rb`
- `app/views/borrowers/show.html.erb`
- `app/queries/borrowers/history_query.rb`
- optionally `app/components/borrowers/*.rb`
- optionally `app/components/shared/*.rb`
- optionally `config/routes.rb` if minimal read-only linked-record routing is needed
- `spec/requests/borrowers_spec.rb`
- `spec/system/borrower_detail_flow_spec.rb`
- optionally new factories/spec support for minimal lending-history fixtures if related runtime models are introduced

Avoid touching these unless a concrete implementation need emerges:

- money-critical services under `app/services/`
- dashboard-specific code paths
- borrower create/search logic in `Borrowers::Create` or `Borrowers::LookupQuery`, except for narrow integration cleanup
- unrelated session/auth flows
- speculative API-only controllers or client-side state layers

### UX and Interaction Requirements

- Align the page with `ux-wireframes-pages/04-4-borrower-detail.html`: a single borrower anchor page with summary, linked history, and next actions.
- The entity header should make borrower identity and current lending context immediately legible.
- The page should preserve orientation with breadcrumb/section framing and stable top actions.
- Linked records should be shown in one place with explicit relationship labels and visible state cues so the admin can verify context quickly.
- No-history states should be explicit and useful, not blank or ambiguous.
- The detail page should feel desktop-first, operationally calm, and consistent with the borrower list/workspace styling already in the repo.
- If a timeline/history block is included, treat it as light operational context, not a substitute for a full audit browser.
- Accessibility matters: clear headings, semantic lists/tables where appropriate, keyboard-reachable actions, and state information that does not rely on color alone.

### Previous Story Intelligence

- Story `2.3` explicitly kept the borrower detail page thin and marked Story `2.4` as the owner of richer detail/history work.
- Story `2.3` established the `Borrowers::LookupQuery` pattern and reinforced that borrower read concerns should live in namespaced query objects, not in controllers.
- Story `2.3` also reinforced that UI-facing stories are not done when behavior passes alone; wireframe alignment and calm operational states matter too.
- Earlier Epic 2 work established the protected admin shell, canonical borrower phone normalization, and reuse-first borrower flows. This story should extend those seams rather than replacing them.

### Testing Requirements

- Extend request coverage for authenticated borrower detail access and unauthenticated redirect behavior.
- Add request coverage for the borrower detail page in both no-history and linked-history cases.
- If linked application/loan records are introduced, add request assertions proving the rendered identifiers, state cues, and navigation targets are correct.
- Add a system spec that exercises the path from workspace or borrower list into the borrower detail page and verifies the admin can understand the current borrower context and next action.
- Add focused query specs if `Borrowers::HistoryQuery` contains non-trivial ordering or shaping logic.
- Add component specs if reusable detail-page components are introduced.
- Reuse existing admin sign-in and borrower factory patterns instead of inventing a second auth/test setup.

### Git Intelligence Summary

- Recent borrower-related work landed in `Add borrower intake workflow.` and `Add borrower search and browse workflow.`.
- Those commits touched the borrower controller, borrower views, workspace entry points, routes, and request/system coverage. This story should extend that same vertical slice instead of starting a separate borrower-detail architecture.
- The existing implementation history confirms that the borrower `show` page is the intended extension point for this story.
- The repo still lacks runtime application/loan models and routes, so any linked-history implementation must respect that sequencing reality and keep new lending seams minimal and read-only unless clearly required.

### Latest Technical Information

- The app currently pins `rails ~> 8.1.2`, while the current stable Rails release is `8.1.3` as of 2026-03-24. Stay within standard Rails 8.1 HTML-first `show` action, server-rendered view, and query-object conventions for this story.
- The architecture's selected `turbo-rails` version `2.0.23` remains current as of 2026-04-13. Use Turbo only where it improves detail-page flow without introducing duplicate UI state.
- The architecture selected `ViewComponent` and current live references indicate `ViewComponent` `4.6.0` is the latest stable release as of 2026-04-13. If component extraction is needed, favor small reusable primitives over large composite abstractions.
- Current Rails guidance still favors conventional server-rendered detail pages, thin controllers, and system/request tests for flows like this one.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` - Epic 2, Story 2.4, Story 2.5 dependency context
- `/_bmad-output/planning-artifacts/prd.md` - FR8, FR11, FR22, linked record visibility, auditability, and borrower-history business context
- `/_bmad-output/planning-artifacts/architecture.md` - query-object guidance, detail-page/read-model rules, ViewComponent/Turbo direction, naming/structure rules
- `/_bmad-output/planning-artifacts/ux-design-specification.md` - entity header, linked-record panel, activity/timeline block, detail-page interaction grammar
- `/_bmad-output/planning-artifacts/ux-wireframes-pages/04-4-borrower-detail.html` - borrower detail wireframe and primary-action intent
- `/_bmad-output/planning-artifacts/recommended-first-sprint-order.md` - note that Story 2.4 was deliberately deferred as richer visibility/history work
- `/_bmad-output/implementation-artifacts/2-3-search-and-browse-borrowers.md`
- `app/controllers/application_controller.rb`
- `app/controllers/borrowers_controller.rb`
- `app/models/borrower.rb`
- `app/components/application_component.rb`
- `app/views/borrowers/show.html.erb`
- `app/views/home/index.html.erb`
- `app/queries/borrowers/lookup_query.rb`
- `config/routes.rb`
- `config/initializers/paper_trail.rb`
- `spec/requests/borrowers_spec.rb`
- `spec/system/borrower_search_flow_spec.rb`
- `Gemfile`

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-04-13T16:49:16+0530
- BMad config loaded from `_bmad/bmm/config.yaml`
- Sprint auto-discovery selected `2-4-view-borrower-details-and-lending-history` as the first backlog story
- No `project-context.md` file was found in the workspace during story preparation
- Planning context gathered from Epic 2, the PRD, the architecture document, the UX specification, the borrower-detail wireframe, the implementation-readiness report, and the sprint-order note
- Previous story intelligence gathered from `2-3-search-and-browse-borrowers.md`
- Current runtime context gathered from borrower controllers, views, queries, routes, components, tests, application shell, and recent git history
- Live version checks confirmed current Rails, `turbo-rails`, and `ViewComponent` context before finalizing the story
- Story moved to `in-progress` in `_bmad-output/implementation-artifacts/sprint-status.yaml`
- Added minimal read-only `LoanApplication` and `Loan` runtime seams, routes, and show pages to support borrower-linked navigation without pulling full lending workflows forward
- Implemented `Borrowers::HistoryQuery` and new borrower detail components for shared entity-header, linked-record, and status rendering
- Ran `bin/rails db:migrate`, `bundle exec rubocop` on changed files, and `bundle exec rspec` with 70 examples passing

### Implementation Plan

- Add a borrower-scoped detail/history read seam that keeps controller code thin and prepares the show page for linked lending context.
- Replace the thin borrower record page with a real detail layout that matches the wireframe and shared detail-page UX grammar.
- Surface linked records and no-history states in a way that stays honest about the repo's current lack of full application/loan runtime workflows.
- Add focused request/system coverage so the detail page remains understandable as Epic 3 and Epic 4 add downstream lending entities.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- The highest-risk implementation mistake in this story is inventing broad application/loan workflows just to satisfy linked-history rendering.
- The most important sequencing guardrail is to keep any newly introduced lending seams minimal, read-only, and aligned with the architecture because the repo does not yet have runtime `LoanApplication` or `Loan` code.
- The most important UX requirement is that the borrower detail page clearly communicates identity, current lending context, and next-step orientation even when no lending history exists yet.
- Replaced the thin borrower confirmation/show screen with a full authenticated detail page that adds breadcrumb orientation, a stable borrower header, lending-context summaries, calm empty and partial-history messaging, and explicit next-step guidance.
- Added minimal read-only lending history seams with `LoanApplication`, `Loan`, UUID-backed routes, and small protected detail pages so linked borrower history records resolve to meaningful workspace surfaces.
- Introduced `Borrowers::HistoryQuery` plus small `ViewComponent` primitives for the borrower header, linked-record panel, and reusable status badges to keep the detail page server-rendered and maintainable.
- Added focused borrower-detail request, query, and system coverage and updated the existing borrower intake system expectation to reflect the new Story 2.4 detail page.
- Validation completed successfully with `bundle exec rubocop` on changed Ruby files and `bundle exec rspec` passing all 70 examples with 90.7% line coverage.

### File List

- `_bmad-output/implementation-artifacts/2-4-view-borrower-details-and-lending-history.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/components/borrowers/detail_header_component.html.erb`
- `app/components/borrowers/detail_header_component.rb`
- `app/components/borrowers/linked_records_panel_component.html.erb`
- `app/components/borrowers/linked_records_panel_component.rb`
- `app/components/shared/status_badge_component.html.erb`
- `app/components/shared/status_badge_component.rb`
- `app/controllers/borrowers_controller.rb`
- `app/controllers/loan_applications_controller.rb`
- `app/controllers/loans_controller.rb`
- `app/models/borrower.rb`
- `app/models/loan.rb`
- `app/models/loan_application.rb`
- `app/queries/borrowers/history_query.rb`
- `app/views/borrowers/show.html.erb`
- `app/views/loan_applications/show.html.erb`
- `app/views/loans/show.html.erb`
- `config/routes.rb`
- `db/migrate/20260413170500_create_loan_applications.rb`
- `db/migrate/20260413170600_create_loans.rb`
- `db/schema.rb`
- `spec/factories/loan_applications.rb`
- `spec/factories/loans.rb`
- `spec/queries/borrowers/history_query_spec.rb`
- `spec/requests/borrowers_spec.rb`
- `spec/system/borrower_detail_flow_spec.rb`
- `spec/system/borrower_intake_flow_spec.rb`

### Change Log

- 2026-04-13: Created the Story `2.4` implementation guide and moved sprint tracking to `ready-for-dev`.
- 2026-04-13: Implemented borrower detail and lending history, added minimal read-only application/loan seams, introduced focused UI components and tests, and moved the story to `review`.
