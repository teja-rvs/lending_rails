# Story 2.5: Evaluate Borrower Eligibility for a New Application

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want the borrower record to tell me whether a new application is allowed,
so that I do not begin conflicting lending work for the same borrower.

## Acceptance Criteria

1. **Given** the admin is viewing a borrower record  
   **When** the system evaluates that borrower's current lending context  
   **Then** it shows whether the borrower is eligible for a new application  
   **And** the reason for the eligibility or ineligibility is clear from the borrower context

2. **Given** the borrower already has an active application  
   **When** the admin reviews the borrower record  
   **Then** the system shows that a new application is not allowed  
   **And** explains that a new application cannot be started while an active application exists

3. **Given** the borrower has an active loan  
   **When** the admin reviews the borrower record  
   **Then** the system shows that repeat borrowing is currently blocked  
   **And** explains that a new application becomes available only after the active loan is closed

4. **Given** the borrower's active loan has been closed and there is no active application  
   **When** the admin reviews the borrower record  
   **Then** the system shows that the borrower is eligible for a new application  
   **And** the borrower history remains available to support the next lending decision

## Tasks / Subtasks

- [x] Add a deterministic borrower eligibility read model on top of the existing borrower detail query surface (AC: 1, 2, 3, 4)
  - [x] Extend `app/queries/borrowers/history_query.rb` or introduce a tightly related borrower-scoped read object/value object so eligibility is computed server-side and returned as structured data, not ad hoc ERB conditionals
  - [x] Return explicit eligibility state plus a stable reason/message payload suitable for rendering and for focused query/request assertions
  - [x] Keep controller orchestration thin in `app/controllers/borrowers_controller.rb`; do not move borrower eligibility rules into the controller or the template

- [x] Encode the borrower eligibility rules using the current minimal lending models without pulling Story `3.1` forward (AC: 1, 2, 3, 4)
  - [x] Treat blocking application states conservatively from the current model: `open`, `in progress`, and `approved` should prevent a new application until later lifecycle stories explicitly narrow that rule
  - [x] Treat blocking loan states as persisted workflow states only: `active` and `overdue` block repeat borrowing, while `closed` can allow eligibility if no blocking application exists
  - [x] Use persisted status values from `LoanApplication` and `Loan`; do not invent derived workflow transitions, money calculations, or future approval/disbursement rules here
  - [x] Define deterministic precedence when multiple blockers exist so the borrower page always explains the same primary reason in the same way

- [x] Surface eligibility clearly on the borrower detail page while preserving borrower history visibility (AC: 1, 2, 3, 4)
  - [x] Replace the current placeholder next-step copy in the borrower detail experience with a real eligibility summary/callout that makes allowed vs blocked state obvious at a glance
  - [x] Keep linked lending history visible beside or below the eligibility signal so the admin can understand why the borrower is or is not eligible without leaving the page
  - [x] Preserve calm operational language, visible status tone, and desktop-first detail-page layout consistency with the existing borrower detail page
  - [x] If a reusable callout or summary primitive is warranted, keep it small and place it under `app/components/borrowers/` or `app/components/shared/` using `ApplicationComponent`

- [x] Make the next valid action clear without fabricating an unfinished application-creation workflow (AC: 1, 4)
  - [x] If the borrower is eligible, communicate readiness for the next workflow step without claiming that application creation is already implemented when the route/action does not yet exist
  - [x] If the borrower is blocked, explain the exact blocker and the condition that must change before a new application becomes available
  - [x] Do not add speculative `loan_applications#new` / `#create` routes, forms, or mutations in this story unless they are the smallest possible seam and are explicitly required by existing, meaningful navigation

- [x] Add focused automated coverage for borrower eligibility rules and rendering (AC: 1, 2, 3, 4)
  - [x] Extend `spec/requests/borrowers_spec.rb` to cover at least: no-history eligible state, active-application blocked state, active-loan blocked state, and closed-loan eligible state
  - [x] Extend `spec/queries/borrowers/history_query_spec.rb` or add an equivalent focused query spec for eligibility rule precedence and reason shaping if read-model logic becomes non-trivial
  - [x] Extend `spec/system/borrower_detail_flow_spec.rb` so the borrower detail page proves the admin can understand eligibility from the rendered screen without losing borrower context
  - [x] Reuse existing factories and authenticated borrower navigation patterns instead of introducing a parallel test setup

### Review Findings

- [x] [Review][Patch] Borrower eligibility copy treats `approved` applications as if they were only "active" blockers [`app/queries/borrowers/history_query.rb:180`]
- [x] [Review][Patch] Eligible-with-history messaging claims linked loans are closed even when the borrower has no loans [`app/queries/borrowers/history_query.rb:216`]
- [x] [Review][Patch] Automated coverage does not exercise `approved` applications or `overdue` loans as standalone blocking states [`spec/queries/borrowers/history_query_spec.rb:25`]

## Dev Notes

### Story Intent

This story turns the borrower detail page from a passive history view into an operational decision aid. The goal is not to start application creation yet; it is to make the borrower page answer a single critical question reliably: "Can I safely begin a new application for this borrower right now?"

### Epic Context and Sequencing Risk

- Epic 2 progresses from borrower identity and intake into borrower search, borrower history visibility, and finally borrower eligibility for new work.
- Story `2.4` intentionally introduced borrower detail and linked history but left eligibility as future-facing placeholder copy.
- Story `2.5` is the bridge between borrower history and Epic 3 application creation. It should make eligibility explicit without dragging the actual application-creation workflow into Epic 2.
- Story `3.1` owns creating a borrower-linked application and maintaining loan details. Story `2.5` should prepare for that workflow, not duplicate it.
- The highest sequencing risk is accidentally adding speculative application-creation mutations or broad workflow state machinery just to satisfy the eligibility message.

### Current Codebase Signals

- `app/controllers/borrowers_controller.rb` already keeps `show` thin by delegating read-side assembly to `Borrowers::HistoryQuery`.
- `app/queries/borrowers/history_query.rb` currently computes linked history and hardcodes a placeholder message saying eligibility review arrives in the next story. That query is the clearest extension seam for this story.
- `app/views/borrowers/show.html.erb` and `app/components/borrowers/*` already establish the borrower-detail layout, current-context cards, linked-record panel, and read-only next-step orientation.
- Story `2.4` introduced minimal read-only `LoanApplication` and `Loan` runtime seams plus read-only detail pages and routes. This story should reuse those seams, not replace them.
- `app/models/loan_application.rb` currently supports statuses `open`, `in progress`, `approved`, `rejected`, and `cancelled`.
- `app/models/loan.rb` currently supports statuses `active`, `closed`, and `overdue`.
- `spec/requests/borrowers_spec.rb`, `spec/queries/borrowers/history_query_spec.rb`, and `spec/system/borrower_detail_flow_spec.rb` already cover borrower detail/history behaviors and should be extended in place.

### Scope Boundaries

- In scope: borrower eligibility evaluation based on the current persisted lending context shown on the borrower detail page.
- In scope: clear explanation for why the borrower is eligible or blocked from starting a new application.
- In scope: keeping borrower history visible so eligibility is explainable and auditable from the existing detail page.
- In scope: focused read-model, UI, and automated test changes around the borrower detail vertical slice.
- Out of scope: full application creation, application edit forms, review-step generation, approval/rejection flows, loan creation, disbursement, repayment, or overdue derivation logic.
- Out of scope: introducing a client-heavy workflow UI, a new dashboard flow, or speculative cross-entity search changes.
- Out of scope: changing how borrower identity, phone normalization, or authentication currently work.

### Developer Guardrails

- Keep the borrower `show` action orchestration-only. Eligibility rules belong in a borrower-scoped read seam, not in controller branches or raw view conditionals.
- Reuse the Story `2.4` borrower detail layout, linked-record panel, and current read-only lending seams. Do not create a second borrower decision page.
- Do not invent new lifecycle states. Use the persisted `LoanApplication` and `Loan` statuses that already exist.
- Do not treat `closed` loans as blockers. Repeat borrowing is allowed only when no blocking application exists and all prior loans are non-blocking.
- Do not silently hide blocker details. The page should explain whether the blocker is an active application, an active/overdue loan, or both.
- Do not add speculative application creation routes or forms just because the borrower is eligible. If no real next-step route exists yet, say so clearly and honestly.
- Do not push money-sensitive or workflow-sensitive logic into Stimulus or client-side state. This evaluation should remain server-driven and testable.
- Preserve the protected admin-only boundary from `ApplicationController` and current authenticated navigation patterns.

### Technical Requirements

- Prefer extending `Borrowers::HistoryQuery` with an eligibility result struct/value object unless a very small adjacent borrower query object makes the rule set clearer. Keep the read seam borrower-scoped and deterministic.
- Shape eligibility data so the UI can render:
  - overall state: eligible or blocked
  - primary reason code/message
  - optional supporting counts or related blocker details
- Use the current domain model as the source of truth:
  - blocking application statuses: `open`, `in progress`, `approved`
  - blocking loan statuses: `active`, `overdue`
  - non-blocking statuses for repeat-borrowing readiness: `rejected`, `cancelled`, `closed`
- Use persisted status only. Do not derive "active" from dates, unpaid amounts, or future workflow assumptions in this story.
- Keep the UI HTML-first and server-rendered. Use Turbo only if it improves local composition without introducing a second source of truth.
- Avoid schema changes unless a concrete implementation need appears. The current story should be satisfiable with the runtime seams already added in Story `2.4`.
- Preserve predictable rendering order and readable copy so tests can make stable assertions against the borrower detail surface.

### Architecture Compliance

- `app/controllers/borrowers_controller.rb`: keep `show` thin and aligned with current authenticated Rails patterns
- `app/queries/borrowers/history_query.rb`: preferred home for borrower detail plus eligibility evaluation
- `app/components/borrowers/detail_header_component.*`: likely extension point for surfacing borrower-level eligibility status near current lending context
- `app/components/borrowers/linked_records_panel_component.*`: keep linked record history visible and explanatory
- `app/views/borrowers/show.html.erb`: main orchestration surface for borrower detail layout
- `app/models/loan_application.rb` and `app/models/loan.rb`: current persisted status vocabularies that eligibility rules must respect
- `config/routes.rb`: avoid changes unless a real, already-implemented next-step route is required
- `spec/requests/borrowers_spec.rb`, `spec/queries/borrowers/history_query_spec.rb`, `spec/system/borrower_detail_flow_spec.rb`: preferred proof points

### File Structure Requirements

Likely implementation touchpoints:

- `app/controllers/borrowers_controller.rb`
- `app/queries/borrowers/history_query.rb`
- `app/views/borrowers/show.html.erb`
- `app/components/borrowers/detail_header_component.rb`
- `app/components/borrowers/detail_header_component.html.erb`
- optionally `app/components/borrowers/*.rb`
- optionally `app/components/shared/*.rb`
- `spec/requests/borrowers_spec.rb`
- `spec/queries/borrowers/history_query_spec.rb`
- `spec/system/borrower_detail_flow_spec.rb`

Avoid touching these unless a concrete need emerges:

- `app/controllers/loan_applications_controller.rb` beyond minimal read-only navigation alignment
- `config/routes.rb` for speculative application-creation routes
- money-critical services under `app/services/`
- dashboard/list flows outside the borrower detail vertical slice
- authentication/session code paths

### UX and Interaction Requirements

- Eligibility should be visible near the top of the borrower detail experience, not buried below the linked history list.
- The borrower page should answer both "is a new application allowed?" and "why?" without requiring the admin to infer rules from raw statuses alone.
- Blocked states should read as calm operational guidance, not as generic errors.
- Eligible states should communicate readiness clearly while staying honest about the fact that application creation lands in the next workflow slice.
- Keep linked history and borrower identity visible so the admin retains orientation and confidence in the decision.
- Maintain the current desktop-first, detail-page visual grammar with clear headings, semantic sections, visible focus states, and status cues that do not rely on color alone.

### Previous Story Intelligence

- Story `2.4` already created the borrower detail page as the canonical borrower anchor page and intentionally deferred eligibility from placeholder copy into this story.
- Story `2.4` established that borrower read concerns belong in namespaced query objects and lightweight server-rendered components rather than in controllers or client-heavy UI.
- Story `2.4` also introduced the minimal read-only `LoanApplication` and `Loan` seams specifically to make borrower-linked lending context visible before later workflows arrive.
- The main lesson from Story `2.4` is reuse-first sequencing discipline: extend the borrower detail slice honestly without pretending later workflows are complete.

### Testing Requirements

- Add request coverage for each primary borrower eligibility state:
  - no lending history -> eligible
  - blocking application present -> blocked
  - blocking loan present -> blocked
  - closed loan and no blocking application -> eligible
- Add at least one focused query-level assertion for deterministic rule precedence when multiple blockers are present.
- Extend the borrower detail system flow so the visible page content proves the admin can understand eligibility from the borrower screen itself.
- Reuse existing authenticated admin sign-in helpers/factories and current borrower detail navigation patterns.
- Keep tests focused on business-visible outcomes and structured read-model behavior; avoid low-value duplication across request and system layers.

### Git Intelligence Summary

- Recent commits show Epic 2 work progressing vertically through borrower identity, intake, search/browse, and borrower detail/history.
- The latest commit, `Add borrower detail and lending history workflow.`, already established the exact borrower detail seams this story should extend.
- Current git history confirms the project favors thin controllers, query-object read seams, server-rendered views, and focused request/system coverage for borrower workflows.
- There are no uncommitted working-tree changes right now, so Story `2.5` can be framed directly against the current `main` branch state.

### Latest Technical Information

- The app currently pins `rails ~> 8.1.2`, while current Rails references point to stable Rails `8.1.3` as of 2026-04-13. Stay within standard Rails 8.1 HTML-first controller, view, and query-object conventions for this story.
- Current `turbo-rails` references continue to point to stable `2.0.23` as of 2026-04-13. Use Turbo only where it improves server-driven composition; do not make eligibility depend on client-side workflow state.
- The architecture remains aligned around Rails, `Pundit`, `ViewComponent`, Tailwind, and server-rendered flows. This story should continue that path rather than introducing a new presentation stack.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` - Epic 2, Story `2.5`, FR12, FR13, FR14
- `/_bmad-output/planning-artifacts/prd.md` - borrower-to-application journey and repeat-borrowing constraints
- `/_bmad-output/planning-artifacts/architecture.md` - query-object guidance, HTML-first Rails patterns, `Pundit`, `ViewComponent`, `Turbo`, routing and model conventions
- `/_bmad-output/planning-artifacts/ux-design-specification.md` - operational clarity, linked context, consistent detail-page grammar
- `/_bmad-output/implementation-artifacts/2-4-view-borrower-details-and-lending-history.md`
- `app/controllers/borrowers_controller.rb`
- `app/queries/borrowers/history_query.rb`
- `app/views/borrowers/show.html.erb`
- `app/components/borrowers/detail_header_component.rb`
- `app/components/borrowers/detail_header_component.html.erb`
- `app/components/borrowers/linked_records_panel_component.rb`
- `app/components/borrowers/linked_records_panel_component.html.erb`
- `app/models/loan_application.rb`
- `app/models/loan.rb`
- `config/routes.rb`
- `spec/requests/borrowers_spec.rb`
- `spec/queries/borrowers/history_query_spec.rb`
- `spec/system/borrower_detail_flow_spec.rb`
- `Gemfile`

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-04-13T17:23:18+0530
- BMad config loaded from `_bmad/bmm/config.yaml`
- Sprint auto-discovery selected `2-5-evaluate-borrower-eligibility-for-a-new-application` as the first backlog story
- No `project-context.md` file was found in the workspace during story preparation
- Planning context gathered from Epic 2, the PRD, the architecture document, the UX specification, the previous story artifact, and the current borrower detail implementation
- Git intelligence gathered from the most recent Epic 2 commits
- Live version checks confirmed current Rails and `turbo-rails` context before finalizing the story
- Implemented borrower eligibility in `Borrowers::HistoryQuery` with deterministic blocker precedence across loan applications and loans
- Updated the borrower detail header and next-step messaging to surface eligibility without introducing speculative application-creation routes
- Extended borrower query, request, and system specs for no-history eligible, application-blocked, loan-blocked, closed-loan eligible, and combined-blocker scenarios
- Validation completed with `bundle exec rspec` (78 examples, 0 failures) and `bundle exec rubocop app/queries/borrowers/history_query.rb app/components/borrowers/detail_header_component.rb spec/queries/borrowers/history_query_spec.rb spec/requests/borrowers_spec.rb spec/system/borrower_detail_flow_spec.rb`

### Implementation Plan

- Extend the borrower detail read seam so it returns a deterministic eligibility evaluation and reason payload.
- Update the borrower detail page to surface eligibility prominently while preserving the linked lending history added in Story `2.4`.
- Add focused request, query, and system coverage so borrower eligibility remains reliable as later application and loan workflows arrive.

### Completion Notes List

- Added a borrower-scoped eligibility payload to `Borrowers::HistoryQuery`, including stable state and reason codes plus explicit next-step guidance for rendering and focused assertions.
- Encoded the current blocker rules using persisted statuses only: loan applications in `open`, `in progress`, or `approved` block new work; loans in `active` or `overdue` block repeat borrowing; `closed` loans are non-blocking.
- Surfaced eligibility prominently in the borrower detail header while preserving linked lending history and keeping the borrower `show` action orchestration-only.
- Added focused request, query, and system coverage for eligible and blocked borrower states, including deterministic handling when both an application and a loan block repeat borrowing.
- Full regression and lint validation passed: `bundle exec rspec` and targeted `bundle exec rubocop`.

### File List

- `_bmad-output/implementation-artifacts/2-5-evaluate-borrower-eligibility-for-a-new-application.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/components/borrowers/detail_header_component.html.erb`
- `app/components/borrowers/detail_header_component.rb`
- `app/components/borrowers/linked_records_panel_component.html.erb`
- `app/queries/borrowers/history_query.rb`
- `app/views/borrowers/show.html.erb`
- `spec/queries/borrowers/history_query_spec.rb`
- `spec/requests/borrowers_spec.rb`
- `spec/system/borrower_detail_flow_spec.rb`

### Change Log

- 2026-04-13: Created the Story `2.5` implementation guide and prepared sprint tracking to move the story to `ready-for-dev`.
- 2026-04-13: Implemented deterministic borrower eligibility evaluation, surfaced the borrower-detail readiness callout, added focused automated coverage, and moved the story to `review`.
