# Story 3.4: Review Borrower History During Decisioning

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want borrower history visible within application review,
so that I can make approval or rejection decisions with the right context.

## Acceptance Criteria

1. **Given** the admin is reviewing an application
   **When** they open the application detail
   **Then** borrower history is visible within the review experience
   **And** linked borrower context can be accessed without losing the application workflow state

2. **Given** the borrower has prior applications, loans, or outcomes
   **When** the admin views the review context
   **Then** those historical signals are presented clearly enough to support decision-making
   **And** the experience preserves orientation between the borrower and the application

3. **Given** the admin needs to work across multiple applications
   **When** they browse the application list
   **Then** they can view applications by operational state
   **And** list and detail behavior follows the shared UX patterns for filters, statuses, and navigation

## Tasks / Subtasks

- [x] Surface borrower lending history inside the application workspace (AC: 1, 2)
  - [x] Extend `LoanApplicationsController#show` to call `Borrowers::HistoryQuery` for the linked borrower and assign the result for view consumption
  - [x] Add a "Borrower lending context" section to `app/views/loan_applications/show.html.erb` that renders linked records (prior applications and loans) using the same `LinkedRecord` data shape already produced by `Borrowers::HistoryQuery`
  - [x] Reuse `Shared::StatusBadgeComponent` for linked record status display
  - [x] Show the eligibility state and current context headline so the reviewer understands whether the borrower has active blocking work
  - [x] Show a clear empty state when the borrower has no prior lending history beyond the current application
  - [x] Do NOT duplicate the full `Borrowers::LinkedRecordsPanelComponent` — instead render a focused inline section that fits the application workspace layout rhythm

- [x] Make borrower detail accessible from the application workspace without losing review state (AC: 1)
  - [x] The existing breadcrumb and borrower link already navigate to the borrower detail page; confirm these remain stable
  - [x] Add a clear "View full borrower profile" link inside the new borrower context section that opens the borrower detail in the same tab
  - [x] Ensure the breadcrumb path on the application show page continues to include the borrower as a navigable ancestor

- [x] Create the application list view with operational-state filtering (AC: 3)
  - [x] Create `app/queries/loan_applications/filtered_list_query.rb` that accepts optional `status` and `search` params, returns ordered loan applications with borrower associations eager-loaded
  - [x] Add `LoanApplicationsController#index` with search and status filter support
  - [x] Add `app/views/loan_applications/index.html.erb` following the same list-page layout rhythm as `app/views/borrowers/index.html.erb`
  - [x] Include the shared filter-bar pattern with status-chip quick filters for `open`, `in progress`, `approved`, `rejected`, and `cancelled`
  - [x] Include a data table showing application number, borrower name, status badge, created date, and a row-click link to the application detail
  - [x] Include empty-state and filtered-empty-state messaging
  - [x] Add `loan_applications#index` route to `config/routes.rb`

- [x] Add navigation entry point for the application list (AC: 3)
  - [x] Add an "Applications" link to the main navigation or workspace sidebar so the admin can reach the list directly
  - [x] Ensure the application show breadcrumb updates to include the applications list as an ancestor when arriving from the list

- [x] Add focused automated coverage (AC: 1, 2, 3)
  - [x] Add request specs for `LoanApplicationsController#index` covering unauthenticated redirect, empty state, filtered by status, and search behavior
  - [x] Extend request specs for `LoanApplicationsController#show` to verify borrower history data is assigned
  - [x] Add system specs for the borrower history section on the application detail page: visible linked records, empty-state, and navigation to borrower profile
  - [x] Add system specs for the application list: filter by status, search, navigate to detail
  - [x] Add query specs for `LoanApplications::FilteredListQuery` covering status filtering, search, and ordering

### Review Findings

- [x] [Review][Patch] Search submissions drop the active status filter [app/views/loan_applications/index.html.erb:31]
- [x] [Review][Patch] Context-preserving redirects lack targeted regression coverage [spec/system/loan_application_workflow_spec.rb:59]

## Dev Notes

### Story Intent

This story bridges the borrower context gap in the application review experience. Today the application workspace shows the borrower name and snapshot data, but does not surface the borrower's lending history (prior applications, loans, eligibility state) within the review flow. The admin must navigate away to the borrower detail page to see that context, losing their place in the review workflow.

The second major deliverable is the application list — a greenfield operational view that lets the admin browse and filter applications by workflow state. This is the first operational list for loan applications and sets the pattern for Story `3.5` and later Epic 4+ stories that need to locate applications by status.

### Epic Context and Sequencing Risk

- Epic 3 flows: application creation (`3.1`) → fixed review workflow (`3.2`) → step progression (`3.3`) → **borrower history in review** (`3.4`) → final decision outcomes (`3.5`).
- Story `3.3` added sequential review-step progression with `ReviewSteps::Approve`, `ReviewSteps::RequestDetails`, and a shared transition service. The application workspace (`show.html.erb`) now has active-step controls and waiting-for-details guidance.
- The primary risk is overbuilding the borrower context section into a full detail replica. The goal is a focused lending-history summary that supports decisioning, not a second borrower detail page.
- A secondary risk is prematurely introducing application approval, rejection, or cancellation controls in the application list or detail. Those belong to Story `3.5`.
- A third risk is breaking the existing review-step progression or application-detail layout. The borrower context section must integrate cleanly below or alongside the existing review workflow section.

### Current Codebase Signals

- `Borrowers::HistoryQuery` already produces exactly the data shape needed: `linked_records` (array of `LinkedRecord` structs with type, label, identifier, status_label, status_tone, path, relevant_at, relevant_label), `current_context` (headline, summary, application_count, loan_count), `eligibility` (state, headline, message), and `history_state` (empty/partial state with message). Reuse this query directly.
- `Borrowers::LinkedRecordsPanelComponent` renders linked records on the borrower detail page. It expects `linked_records`, `history_state`, and `next_step_message`. For the application workspace, build a lighter inline section rather than reusing this full component, since the layout context is different (narrower max-width, embedded inside the review flow).
- `LoanApplicationsController` currently has `create`, `show`, and `update` — no `index` action. The controller delegates to service objects and uses `includes(:borrower)` for eager loading.
- `config/routes.rb` defines `loan_applications` with `only: %i[show update]`. Adding `index` requires updating the route definition.
- `app/views/borrowers/index.html.erb` provides the existing list-page pattern to replicate: breadcrumb, search input, filter controls, data table with status badges, empty states.
- The `Shared::StatusBadgeComponent` is used consistently across borrower detail, application workspace, and review steps — continue using it for linked record status display.
- `LoanApplication::STATUSES` defines the canonical status vocabulary: `open`, `in progress`, `approved`, `rejected`, `cancelled`.
- `LoanApplication#status_label` and `#status_tone` provide display helpers already used in the show page.

### Scope Boundaries

- In scope: borrower lending history section embedded in the application show page.
- In scope: application list view with operational-state filtering and search.
- In scope: navigation link to application list from workspace/sidebar.
- In scope: focused automated coverage for new query, controller actions, views, and system flows.
- Out of scope: final application approval, rejection, or cancellation (Story `3.5`).
- Out of scope: loan creation from approved applications (Epic 4).
- Out of scope: dashboard widgets or dashboard-driven application filtering (Epic 6).
- Out of scope: borrower detail page changes beyond confirming navigation stability.
- Out of scope: editable borrower data from within the application workspace.

### Developer Guardrails

- Reuse `Borrowers::HistoryQuery` as-is. Do NOT duplicate lending-history aggregation logic in a new query or in the controller.
- The borrower history section in the application workspace must be read-only context for decisioning. No eligibility-changing actions (like starting a new application) should appear inside the application review page.
- The application list query must live in `app/queries/loan_applications/filtered_list_query.rb`, not in the controller or model scopes.
- Do NOT add approval/rejection/cancellation buttons to the application list or detail page in this story. Reserve those for Story `3.5`.
- Keep the application show page layout rhythm intact: application header → review workflow → borrower lending context → pre-decision details → request summary. Insert the new section between the review workflow and the pre-decision details sections.
- Use the established Tailwind card/section pattern (`rounded-3xl border border-slate-200 bg-white p-8 shadow-sm`) for the new borrower context section.
- Keep controllers thin — `index` should delegate to the query object, `show` should call `Borrowers::HistoryQuery` and assign the result.
- Filter the current application OUT of the linked records displayed in the borrower history section to avoid redundancy (the admin is already looking at this application).
- The application list must follow HTML-first server-rendered patterns with standard Rails form submissions for search and filter, not client-side-only filtering.

### Technical Requirements

- **New query:** `app/queries/loan_applications/filtered_list_query.rb`
  - Accept optional `status:` (string, must be in `LoanApplication::STATUSES` or nil for all) and `search:` (string, searches application_number and borrower name)
  - Return `LoanApplication` relation with `.includes(:borrower)` for eager loading
  - Order by `created_at DESC` as the default sort
  - Use `ILIKE` for search matching against `loan_applications.application_number` and `borrowers.full_name` via a joined query

- **Controller changes:**
  - `LoanApplicationsController#index`: assign `@loan_applications` from query, `@search_query`, `@status_filter`, and `@has_applications` for empty-state logic
  - `LoanApplicationsController#show`: add `@borrower_history = Borrowers::HistoryQuery.call(id: @loan_application.borrower_id)` and filter the current application out of `linked_records`

- **Route changes:**
  - Add `:index` to the `loan_applications` resource: `resources :loan_applications, only: %i[index show update]`

- **View: application list** (`app/views/loan_applications/index.html.erb`):
  - Breadcrumb: Workspace / Applications
  - Search input with `params[:q]`
  - Status filter chips for each status in `LoanApplication::STATUSES`
  - Data table: Application number (link), Borrower name, Status badge, Created date
  - Empty state: "No applications found" with guidance
  - Filtered empty state: "No applications match the current filters"

- **View: borrower context section** in application show page:
  - Section title: "Borrower lending context"
  - Current context headline and summary from `HistoryQuery`
  - Eligibility state badge (eligible/blocked) for decisioning awareness
  - Linked records list (filtered to exclude current application) with type, identifier link, status badge, and relevant date
  - Empty state: "No prior lending history for this borrower beyond the current application"
  - "View full borrower profile" link

### Architecture Compliance

- `app/queries/loan_applications/filtered_list_query.rb`: new read-model query following the established `app/queries/<domain>/` pattern
- `app/queries/borrowers/history_query.rb`: reused as-is, no modifications
- `app/controllers/loan_applications_controller.rb`: thin orchestration, delegates to query objects
- `app/views/loan_applications/show.html.erb`: extended with borrower context section
- `app/views/loan_applications/index.html.erb`: new list view following established patterns
- `app/components/shared/status_badge_component.*`: reused for all status display
- `config/routes.rb`: route addition only
- `spec/queries/loan_applications/filtered_list_query_spec.rb`: new query specs
- `spec/requests/loan_applications_spec.rb`: extended with index action specs
- `spec/system/loan_application_workflow_spec.rb`: extended with borrower context and list navigation specs

### File Structure Requirements

Likely implementation touchpoints:

- `app/queries/loan_applications/filtered_list_query.rb` (new)
- `app/controllers/loan_applications_controller.rb` (extend with `index`, extend `show`)
- `app/views/loan_applications/index.html.erb` (new)
- `app/views/loan_applications/show.html.erb` (extend with borrower context section)
- `config/routes.rb` (add `index` to loan_applications)
- `app/views/layouts/application.html.erb` (add Applications nav link if sidebar/nav exists)
- `spec/queries/loan_applications/filtered_list_query_spec.rb` (new)
- `spec/requests/loan_applications_spec.rb` (extend)
- `spec/system/loan_application_workflow_spec.rb` (extend)

Avoid touching these unless a concrete need emerges:

- `app/queries/borrowers/history_query.rb` — reuse as-is
- `app/components/borrowers/linked_records_panel_component.*` — do not extract into shared; build focused inline markup
- `app/services/loan_applications/*` — no service changes needed
- `app/services/review_steps/*` — no changes
- `app/models/loan_application.rb` — no model changes unless scopes are needed for the query (prefer query object)
- Final application decision services from Story `3.5`
- Loan creation, disbursement, repayment, or dashboard services

### UX and Interaction Requirements

- The borrower lending context section must feel like a natural read-only reference panel within the review workflow, not a competing detail page.
- Linked records should be scannable: type label, identifier as link, status badge, and date — following the same visual pattern used in `Borrowers::LinkedRecordsPanelComponent` but adapted for the narrower application workspace.
- The eligibility state should be clearly visible but not actionable — it informs the reviewer whether the borrower is blocked or eligible, without offering "start application" controls inside the review page.
- The application list should follow the same UX rhythm as the borrower list: search bar at top, filter chips, clean data table, obvious row navigation to detail.
- Status filter chips should use the same semantic tone colors as the `Shared::StatusBadgeComponent` for consistency.
- Empty and filtered-empty states must be helpful, explaining whether no applications exist at all or whether the current filter yields no results.
- Breadcrumb navigation must remain coherent whether the admin arrives from the borrower detail or from the application list.

### Previous Story Intelligence

- Story `3.3` established the review-step progression UI inside the application show page, including current-step-only actions, waiting-for-details guidance, and clear blocked-state messaging. Story `3.4` must integrate the borrower context section without disrupting this layout.
- Story `3.3` confirmed that `ReviewSteps::Transition` locks the `loan_application` record during mutation. No changes to this pattern are needed.
- Story `3.3` extended request and system specs for the application workspace. Story `3.4` should extend those same spec files rather than creating parallel test setups.
- The strongest carry-forward lesson from Story `3.3` is that the application show page is the canonical review workspace. All review-context additions should be embedded there, not on a separate page.

### Git Intelligence Summary

- Recent commits follow a clean vertical progression through Epic 3:
  - `Add borrower-linked application workflow.` (Story `3.1`)
  - `Add fixed application review workflow.` (Story `3.2`)
  - `Add review step progression controls.` (Story `3.3`)
- The working tree is clean and the codebase is consistent with the established patterns.
- The borrower detail page (`borrower detail and lending history workflow` commit) established the `Borrowers::HistoryQuery` → component rendering pattern that Story `3.4` will reuse on the application side.

### Latest Technical Information

- `Gemfile.lock` pins:
  - `rails 8.1.3`
  - `turbo-rails 2.0.23`
  - `view_component 4.6.0`
  - `pundit 2.5.2`
  - `paper_trail 17.0.0`
  - `aasm 5.5.2`
  - `shadcn-rails 0.2.1`
  - `pagy` for pagination (use if the application list grows beyond a single page)
- These are the current stable versions already installed. Do not introduce dependency changes for this story.
- Continue using HTML-first Rails flows with Turbo-compatible redirects/renders and server-owned query logic.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` — Epic 3, Story `3.4`, FR22, FR29
- `/_bmad-output/planning-artifacts/prd.md` — Application review with borrower context, application list browsing
- `/_bmad-output/planning-artifacts/architecture.md` — Query object patterns, controller boundaries, ViewComponent rules, HTML-first routing
- `/_bmad-output/planning-artifacts/ux-design-specification.md` — Filter bar, data table, entity header, linked-record panel, status badge patterns
- `/_bmad-output/implementation-artifacts/3-3-progress-review-steps-in-sequence.md` — Previous story with review progression implementation
- `app/queries/borrowers/history_query.rb` — Reusable borrower history aggregation
- `app/components/borrowers/linked_records_panel_component.*` — Visual pattern reference for linked records
- `app/views/loan_applications/show.html.erb` — Canonical application workspace to extend
- `app/controllers/loan_applications_controller.rb` — Controller to extend
- `app/views/borrowers/index.html.erb` — List page pattern to replicate
- `app/models/loan_application.rb` — Status vocabulary and display helpers
- `config/routes.rb` — Route definitions to update
- `Gemfile.lock` — Pinned dependency versions

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-04-13
- BMad config loaded from `_bmad/bmm/config.yaml`
- Sprint auto-discovery selected `3-4-review-borrower-history-during-decisioning` as the first backlog story
- Planning context gathered from Epic 3, the PRD, the architecture document, the UX specification, the previous story artifact, the current codebase state, recent git history, and a thorough read-only codebase review
- No `project-context.md` file was found in the workspace during story preparation
- Gemfile.lock verified current dependency pins; no version changes needed for this story
- Implemented borrower lending context inside the application workspace using `Borrowers::HistoryQuery`, filtering the current application out of the rendered linked records
- Added the applications list flow with `LoanApplications::FilteredListQuery`, status/search filtering, and workspace navigation entry points
- Preserved list-origin orientation on the application detail page via breadcrumb/source propagation through detail actions
- Validation completed with `bundle exec rspec`, targeted `bundle exec rubocop` on changed Ruby files, and `bundle exec brakeman -q`

### Completion Notes List

- Added an inline "Borrower lending context" section to the application review workspace with current context, eligibility awareness, linked record history, and an empty state for borrowers with no prior history beyond the current application.
- Added an `Applications` operational list page with server-rendered status chips, search, empty states, and links into the application review workspace.
- Preserved navigation orientation by adding a workspace entry point for applications and showing an applications breadcrumb ancestor when the reviewer arrives from the list.
- Added focused request, system, and query coverage for the new history section, applications index, filtering, search, and detail navigation flows.
- Full validation passed: `bundle exec rspec` (`153 examples, 0 failures`), `bundle exec rubocop` on changed Ruby files, and `bundle exec brakeman -q`.

### File List

- app/controllers/loan_applications_controller.rb
- app/controllers/review_steps_controller.rb
- app/queries/loan_applications/filtered_list_query.rb
- app/views/home/index.html.erb
- app/views/loan_applications/_form.html.erb
- app/views/loan_applications/index.html.erb
- app/views/loan_applications/show.html.erb
- config/routes.rb
- spec/queries/loan_applications/filtered_list_query_spec.rb
- spec/requests/loan_applications_spec.rb
- spec/system/loan_application_workflow_spec.rb

### Change Log

- 2026-04-13: Added borrower lending context to the application review workspace, created the applications operational list with filtering/search, preserved list-origin breadcrumb context, and expanded request/system/query coverage for the new flows.
