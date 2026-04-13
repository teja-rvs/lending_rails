# Story 2.3: Search and Browse Borrowers

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want to search and browse borrowers by the identifiers that matter operationally,
so that I can find the right person before creating or reviewing lending work.

## Acceptance Criteria

1. **Given** borrower records exist  
   **When** the admin opens the borrower list  
   **Then** they see a consistent operational list with search and filtering controls  
   **And** the table behavior follows the shared filter-bar and data-table UX patterns

2. **Given** the admin searches by phone number  
   **When** they run the search  
   **Then** matching borrowers are returned using phone number as the primary lookup path  
   **And** name-based search remains available as a secondary lookup method

3. **Given** no borrower matches the search or filters  
   **When** the results are empty  
   **Then** the system shows a useful empty or filtered-empty state  
   **And** the admin understands whether to refine the search or create a new borrower

## Tasks / Subtasks

- [x] Add the authenticated borrower browse/read HTTP surface using the existing Rails HTML-first patterns (AC: 1, 2, 3)
  - [x] Update `config/routes.rb` to expose `index` alongside the existing borrower `new/create/show` flow while preserving the UUID constraint on `show`
  - [x] Add an `index` action to `app/controllers/borrowers_controller.rb` that stays thin and delegates search/list assembly to a read-model seam instead of embedding SQL in the controller
  - [x] Keep the route inside the repo's existing authentication and admin-only boundary; do not add public borrower search access

- [x] Implement borrower lookup logic with phone-primary and name-secondary behavior (AC: 2)
  - [x] Add a read-side query object such as `app/queries/borrowers/lookup_query.rb` or equivalent namespaced query under `app/queries/borrowers/`
  - [x] Reuse `Borrower.normalize_phone_number` so phone-like input matches `phone_number_normalized` through the canonical server-side normalization path
  - [x] Support secondary name lookup on `full_name` without introducing a new search stack, alternate phone parser, or client-side business logic
  - [x] Keep the query read-only and borrower-scoped; do not join in lending history, eligibility, applications, or loans yet

- [x] Build a search-first borrower list page aligned with the planned UX direction (AC: 1, 2, 3)
  - [x] Create `app/views/borrowers/index.html.erb` as the main list surface, with phone search visually dominant and `Create borrower` as the clear primary action
  - [x] Follow the borrower-list wireframe and the current Tailwind-heavy server-rendered page style already used in `app/views/home/index.html.erb` and borrower pages
  - [x] Render a consistent borrower table with only the data needed for this story's operational lookup goal, linking rows to the existing thin borrower `show` page rather than expanding detail/history scope

- [x] Add useful browse, empty, and filtered-empty states that preserve orientation (AC: 1, 3)
  - [x] Distinguish between "no borrowers exist yet" and "no borrowers match this search"
  - [x] Make the recovery path obvious with clear refine/reset/create actions
  - [x] Preserve submitted search input and keep list state understandable after each request

- [x] Expose borrower browse/search entry points without dragging later stories forward (AC: 1, 2)
  - [x] Add or update workspace navigation so borrower search is an obvious operational entry point before creating a duplicate borrower
  - [x] Add borrower-list links from adjacent thin borrower flows only where that materially improves orientation
  - [x] Keep the current borrower `show` page intentionally light; Story `2.4` owns richer borrower detail and lending history

- [x] Add focused automated coverage for borrower browse/search behavior (AC: 1, 2, 3)
  - [x] Add request coverage for authenticated access, unauthenticated redirect, default browse load, phone search, name search, and empty-result handling
  - [x] Add a system spec that exercises the search-first list flow from the protected workspace and proves the filtered-empty recovery path is understandable
  - [x] Reuse existing borrower factories and admin sign-in helpers rather than duplicating model/service assertions already covered by Stories `2.1` and `2.2`

### Review Findings

- [x] [Review][Patch] Normalize the controller/view search state the same way as `Borrowers::LookupQuery` so whitespace-only input does not show "matched your current search", "Showing results for ...", and "Clear search" while actually running the unfiltered browse path [`app/controllers/borrowers_controller.rb:3`]
- [x] [Review][Patch] Add a focused spec that proves the deterministic default borrower browse order promised by the story so regressions in `order(created_at: :desc, id: :desc)` fail visibly [`spec/requests/borrowers_spec.rb:24`]

## Dev Notes

### Story Intent

This story turns the borrower foundation and intake flow into the first real lookup surface for borrower operations. The goal is not a rich CRM-style directory; it is a dependable, search-first borrower list that lets the admin check for an existing borrower before creating a new one, find the correct record quickly, and move toward later borrower-review workflows without ambiguity.

### Epic Context and Downstream Dependencies

- Epic 2 covers borrower intake, borrower search/list browsing, borrower detail/history, and borrower eligibility for new application work.
- Story `2.1` established the borrower identity foundation: canonical phone normalization, duplicate prevention, and safe creation through `Borrowers::Create`.
- Story `2.2` added the protected borrower intake workflow and a deliberately thin post-create borrower page.
- Story `2.3` should add the lookup/list surface that sits between workspace entry and richer borrower review work.
- Story `2.4` owns the fuller borrower detail page plus linked lending history, so this story should not expand the thin `show` page into a history view.
- Story `2.5` owns borrower eligibility for a new application; do not pull active-loan or active-application eligibility checks into this story.
- Epic 3 depends on a reliable borrower search path so future application creation starts from the correct borrower instead of from duplicate intake.

### Current Codebase Signals

- `app/models/borrower.rb` already provides the canonical lookup foundation through `phone_number_normalized`, `Borrower.normalize_phone_number`, and duplicate validation rules.
- `app/controllers/borrowers_controller.rb` currently exposes only `new`, `create`, and `show`; there is no borrower `index` yet.
- `app/views/borrowers/show.html.erb` explicitly states that richer borrower history arrives in later stories. Preserve that boundary.
- `config/routes.rb` currently exposes only `resources :borrowers, only: %i[new create show]` with a UUID constraint on borrower IDs.
- `app/views/home/index.html.erb` currently links only to `Create borrower` and explicitly describes search/detail work as later stories, so Story `2.3` should update the workspace entry points.
- The repo has no borrower read query yet and no existing generic list/filter component in runtime code, even though the architecture reserves `app/queries` and `app/components/shared` for those responsibilities.
- The repo also has no pagination gem or existing pagination helper in active use, so any pagination decision should stay lightweight and justified by the story.

### Scope Boundaries

- In scope: authenticated borrower list access, search-first lookup UX, phone-primary search, secondary name search, useful empty states, and row-level navigation into the existing thin borrower surface.
- In scope: server-rendered filter/search behavior and test coverage for auth, browse, search, and no-result states.
- Out of scope: borrower edit flow, richer borrower profile sections, borrower-linked application or loan history, eligibility for starting a new application, dashboard borrower metrics, or any cross-entity search.
- Out of scope: speculative schema expansion for extra borrower fields or new lending relationships not already required by current stories.
- Out of scope: inventing a JavaScript-heavy data grid or SPA-style search experience.

### Developer Guardrails

- Do not bypass `Borrower.normalize_phone_number` or re-implement phone parsing in the controller, view helpers, or JavaScript.
- Do not weaken the phone-first lookup rule by treating name search as the primary search path. Phone remains the operationally dominant identifier.
- Keep the borrower `show` page thin. If rows link to `show`, that page must remain an orientation surface, not an early implementation of Story `2.4`.
- Do not add application, loan, overdue, or eligibility columns to the borrower list in this story unless a documented planning dependency proves they are required now.
- Keep the list HTML-first and server-driven. Use normal GET params and page refreshes or minimal Turbo behavior only if it improves clarity without creating a second source of state truth.
- Preserve calm, actionable UX language for empty and filtered-empty states so the admin understands whether to refine the search or create a borrower.
- Treat wireframe alignment as part of done for this UI-facing story, not just passing behavior and tests.

### Technical Requirements

- Add a borrower `index` route and controller surface that fits the current Rails monolith's HTML-first flow.
- Route search/list logic through a dedicated borrower read seam, preferably a query object under `app/queries/borrowers/`, rather than embedding business or query-building logic directly in the controller.
- Use canonical phone normalization for phone lookups and keep that logic server-side.
- Support a secondary name search path against borrower names without introducing an external search engine or speculative query abstraction.
- Keep the search input in normal Rails query params so the resulting list context is bookmarkable, testable, and easy to reason about.
- Use a deterministic default browse order for borrowers when no search is present so the list remains stable and predictable.
- If result volume makes browsing unwieldy, add lightweight server-side pagination only if justified by the story; do not build a custom client-side table state system.
- Keep responses server-rendered and reuse the current protected workspace shell and borrower route conventions.

### Architecture Compliance

- `config/routes.rb`: extend the borrower resource with `index` while preserving the existing UUID route constraint for `show`
- `app/controllers/borrowers_controller.rb`: keep the controller thin and orchestration-focused
- `app/models/borrower.rb`: treat the model as the canonical source of phone normalization and borrower identity rules
- `app/queries/borrowers/lookup_query.rb`: preferred home for borrower list/search logic
- `app/views/borrowers/index.html.erb`: primary list/search UI surface for this story
- `app/views/home/index.html.erb`: likely update point for borrower-search entry from the authenticated workspace
- `app/views/borrowers/show.html.erb`: may need only minimal orientation updates, not richer detail/history
- `spec/requests/borrowers_spec.rb` or a borrower index-specific request spec: request-level proof for browse/search and auth behavior
- `spec/system/borrower_search_flow_spec.rb` or equivalent: end-to-end proof that the search-first flow is usable and clear

### File Structure Requirements

Likely implementation touchpoints:

- `config/routes.rb`
- `app/controllers/borrowers_controller.rb`
- `app/queries/borrowers/lookup_query.rb`
- `app/views/borrowers/index.html.erb`
- `app/views/home/index.html.erb`
- optionally `app/views/borrowers/show.html.erb`
- `spec/requests/borrowers_spec.rb` or a new borrower list request spec
- `spec/system/borrower_search_flow_spec.rb` or equivalent

Avoid touching these in Story `2.3` unless a concrete implementation detail truly requires it:

- `app/models/loan_application.rb`
- `app/models/loan.rb`
- any future borrower history component beyond the current thin `show`
- `app/services/borrowers/create.rb` except where reuse or small integration cleanup is necessary
- any API-only controller or JavaScript-heavy client state layer

### UX and Interaction Requirements

- The wireframe intent is "search-first table view for lookup, intake checks, and quick entry into borrower history."
- Phone-number search should be visually and functionally dominant, since borrower lookup is a core starting action.
- The page should feel desktop-first, calm, and operationally trustworthy, not like a generic admin grid or a consumer directory.
- The page should use a clear primary action for `Create borrower` while still making search the main operational behavior.
- Empty and filtered-empty states should explain whether the system has no borrowers yet or whether the current search returned no matches.
- The list/table behavior should stay consistent with the broader UX direction for filter bars, searchable list views, explicit states, and predictable navigation.
- Accessibility matters here: use semantic labels for search inputs, table semantics for results, clear focusable controls, and state language that does not rely on color alone.

### Previous Story Intelligence

- Story `2.2` intentionally kept the borrower `show` page thin and explicitly deferred fuller borrower history to later stories. Preserve that scope boundary.
- Story `2.2` also established that borrower routes are part of the protected admin shell, so Story `2.3` should extend the same auth boundary rather than introducing a parallel surface.
- Story `2.2` reinforced that UI-facing stories must satisfy both behavior and wireframe alignment.
- Story `2.1` identified phone normalization and duplicate handling as the critical borrower-identity seam. This story should rely on that existing design instead of introducing alternate search logic.
- Stories `2.1` and `2.2` already provide model, service, request, and system coverage for borrower creation; Story `2.3` should build on those testing patterns rather than restating borrower foundation behavior.

### Testing Requirements

- Add request specs proving unauthenticated access is redirected to sign-in for the borrower list/search surface.
- Add request specs proving an authenticated admin can load the borrower list and see borrowers without search params.
- Add request specs proving phone-based search matches canonical normalized phone data even when the submitted search input is formatted differently.
- Add request specs proving name-based search remains available as a secondary lookup path.
- Add request specs proving empty and filtered-empty states are rendered clearly and preserve the current search input.
- Add a system spec that exercises the real workspace-to-borrower-search flow and verifies the search-first UX plus recovery path when no match is found.
- Reuse existing borrower factories and request/system sign-in patterns instead of inventing new authentication helpers.

### Git Intelligence Summary

- Recent history shows the repo just completed Story `2.2` with `Add borrower intake workflow.` after the earlier borrower foundation commit `Establish borrower identity foundations.`.
- Those commits created the borrower model, create service, create/show controller flow, borrower request/system specs, and a thin post-create borrower context. Story `2.3` should extend that line of work rather than replacing it.
- The repo's current borrower-related changes intentionally stop before list/search behavior. This story should add only the missing browse/search slice and avoid bundling borrower-history or application-eligibility work.
- The recent workspace route update also shows the app is still using a small, protected HTML-first shell, so borrower search should plug into that shell cleanly.

### Latest Technical Information

- The repo currently pins `rails ~> 8.1.2` in `Gemfile`, while the current stable Rails release is `8.1.3` as of 2026-03-24. Stay within normal Rails 8.1 HTML-first controller, routing, and query conventions.
- The repo currently pins `phonelib ~> 0.10.17`, while the current stable `phonelib` release is `0.10.18` as of 2026-04-04. Reuse the existing `phonelib`-backed borrower normalization path rather than adding another phone library.
- If lightweight pagination becomes necessary for borrower browsing, `pagy 43.5.0` is the current stable release as of 2026-04-08. The repo does not currently depend on `pagy`, so only add it if the story implementation truly needs server-side pagination support.
- Current Rails guidance continues to favor standard GET query params and server-rendered search/filter flows for straightforward operational list pages like this one.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` - Epic 2, Story 2.3, Stories 2.4-2.5 dependency context
- `/_bmad-output/planning-artifacts/prd.md` - borrower search requirements, dashboard/list investigation direction, performance targets
- `/_bmad-output/planning-artifacts/architecture.md` - query-object guidance, borrower search strategy, HTML-first Rails boundaries, test-location rules
- `/_bmad-output/planning-artifacts/ux-design-specification.md` - filter-bar, data-table, empty-state, desktop-first, and accessibility guidance
- `/_bmad-output/planning-artifacts/ux-wireframes-pages/03-3-borrowers-list.html` - borrower list wireframe and phone-dominant search note
- `/_bmad-output/implementation-artifacts/2-2-create-borrower-intake-flow.md`
- `/_bmad-output/implementation-artifacts/2-1-establish-borrower-identity-and-searchable-records.md`
- `/_bmad-output/implementation-artifacts/epic-1-retro-2026-03-31.md`
- `app/controllers/borrowers_controller.rb`
- `app/models/borrower.rb`
- `app/views/borrowers/show.html.erb`
- `app/views/home/index.html.erb`
- `config/routes.rb`
- `spec/requests/borrowers_spec.rb`
- `spec/system/borrower_intake_flow_spec.rb`
- `Gemfile`

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-04-13T16:16:17+0530
- BMad config loaded from `_bmad/bmm/config.yaml`
- Sprint auto-discovery selected `2-3-search-and-browse-borrowers` as the first backlog story
- No `project-context.md` file was found in the workspace during story preparation
- Planning context gathered from Epic 2, the PRD, the architecture document, the UX specification, the borrower-list wireframe, the Epic 1 retrospective, and the previous borrower stories
- Current runtime context gathered from the borrower model, controller, views, routes, tests, workspace shell, and recent git history
- Live version checks confirmed current Rails, `phonelib`, and optional pagination context before finalizing the story
- Updated sprint tracking to `in-progress` before implementation work began
- Validation was initially blocked because PostgreSQL was not running locally; restored the documented local dependency with `docker compose up -d postgres`
- Prepared the test database with `RAILS_ENV=test bin/rails db:prepare`
- Verified the implementation with focused borrower request/system coverage and a full `bundle exec rspec` run

### Implementation Plan

- Add a thin, authenticated borrower list/index flow that plugs into the existing Rails shell and borrower controller.
- Introduce a borrower read query that keeps phone lookup primary, name lookup secondary, and all normalization server-side.
- Build a search-first list page with helpful empty states and a clear create-borrower escape hatch.
- Add request and system coverage for auth, browse, phone search, name search, and filtered-empty recovery behavior.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- The highest-risk mistake in this story is bypassing canonical phone normalization or turning name search into the primary lookup path.
- The most important scope-control decision is to keep borrower list/search separate from borrower history detail and new-application eligibility logic.
- This story should reuse the existing borrower foundation and protected workspace shell instead of introducing a new search stack, a client-heavy grid, or richer borrower-detail scope.
- Added a thin borrower `index` flow that stays inside the existing admin-only Rails shell and delegates read behavior to `Borrowers::LookupQuery`.
- Implemented phone-primary lookup through `Borrower.normalize_phone_number`, secondary name search on `full_name`, and deterministic borrower ordering for default browse behavior.
- Built a search-first borrower list with distinct empty and filtered-empty states, plus navigation updates from the workspace, borrower intake flow, and thin borrower record page.
- Added request and system coverage for borrower browse/search behavior, plus a small shared-policy spec so the full suite satisfies the repo's SimpleCov gate.
- Full validation passed with `bundle exec rspec` (61 examples, 0 failures; line coverage 91.22%, branch coverage 82.0%).

### File List

- `_bmad-output/implementation-artifacts/2-3-search-and-browse-borrowers.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/controllers/borrowers_controller.rb`
- `app/queries/borrowers/lookup_query.rb`
- `app/views/borrowers/index.html.erb`
- `app/views/borrowers/new.html.erb`
- `app/views/borrowers/show.html.erb`
- `app/views/home/index.html.erb`
- `config/routes.rb`
- `spec/policies/application_policy_spec.rb`
- `spec/requests/borrowers_spec.rb`
- `spec/system/borrower_intake_flow_spec.rb`
- `spec/system/borrower_search_flow_spec.rb`

### Change Log

- 2026-04-13: Created the Story `2.3` implementation guide and moved sprint tracking to `ready-for-dev`.
- 2026-04-13: Implemented borrower browse/search, updated borrower navigation/orientation surfaces, and passed the full RSpec suite before moving the story to `review`.
