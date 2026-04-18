# Story 6.2: Drill from Dashboard into Filtered Operational Views

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want dashboard widgets to open the right filtered operational lists,
so that I can move directly from signal to action without losing context.

## Acceptance Criteria

1. **Given** the admin is on the dashboard
   **When** they click the overdue payments, upcoming payments, open applications, active loans, closed loans, total disbursed amount, or total repayment amount widget
   **Then** the system opens the corresponding filtered list
   **And** the resulting list makes the filter context explicit

2. **Given** the admin drills into upcoming, overdue, active, open, or summary-driven work
   **When** the list page loads
   **Then** it uses the shared filter-bar and data-table patterns
   **And** the admin can continue investigating from that operational context without confusion

3. **Given** the admin drills in from overdue payments or upcoming payments
   **When** the filtered repayment list loads
   **Then** the matching repayment-state or due-window filter is already applied
   **And** the admin does not need to rebuild the same triage filter manually

4. **Given** no records match a drilled-in view
   **When** the filtered list is empty
   **Then** the system shows a clear empty-state explanation
   **And** the admin understands whether the result means healthy operations or active filter constraints

## Tasks / Subtasks

- [x] Task 1: Fix dashboard drill-in link parity so widget counts match what the filtered list shows (AC: #1, #3)
  - [x] 1.1 **Open applications widget:** Change `loan_applications_path(status: "open")` to `loan_applications_path(status: "open,in progress")` (or equivalent multi-status param) so the drill-in list shows the same set of records the dashboard counts. The `OpenApplicationsQuery` counts BOTH `"open"` AND `"in progress"` statuses; the current link only sends `status=open`. **Requires** `LoanApplications::FilteredListQuery` and `LoanApplicationsController` to support a comma-separated multi-status param.
  - [x] 1.2 **Active loans widget:** Change `loans_path(status: "active")` to `loans_path(status: "active,overdue")` (or equivalent multi-status param) so the drill-in list shows both `active` and `overdue` loans, matching what `ActiveLoansQuery` counts. **Requires** `Loans::FilteredListQuery` and `LoansController` to support a comma-separated multi-status param.
  - [x] 1.3 **Total disbursed widget:** Add `href: loans_path` and `label: "View all"` to the "Total disbursed" `SummaryWidgetComponent` in `dashboard/show.html.erb`. Per PRD FR64, all summary metrics intended for operational investigation should link to filtered lists.
  - [x] 1.4 **Total repayment widget:** Add `href: payments_path` and `label: "View all"` to the "Total repayment" `SummaryWidgetComponent` in `dashboard/show.html.erb`.

- [x] Task 2: Support multi-status filtering in `LoanApplicationsController` and `LoanApplications::FilteredListQuery` (AC: #1, #2, #3)
  - [x] 2.1 Update `LoanApplicationsController#normalized_status_filter` to accept a comma-separated string of statuses. Parse `params[:status]` by splitting on `,`, stripping whitespace, downcasing each, then selecting only values present in `LoanApplication::STATUSES`. Return the array if multiple valid statuses, the single string if one valid status, or `nil` if none valid. Store as `@status_filter` (may now be a String or Array).
  - [x] 2.2 Update `LoanApplications::FilteredListQuery#call` to handle `status:` as either a String (single status — existing behavior) or an Array (multi-status — use `.where(status: array)`). No change when `status:` is nil/blank.
  - [x] 2.3 Update `app/views/loan_applications/index.html.erb` to display active filter context when multiple statuses are applied. Show a "Filtered by: Open, In progress" indicator (or similar) when the current filter is an array. Ensure the "Clear filters" link appears and works when multi-status filters are active.

- [x] Task 3: Support multi-status filtering in `LoansController` and `Loans::FilteredListQuery` (AC: #1, #2, #3)
  - [x] 3.1 Update `LoansController#normalized_status_filter` to accept a comma-separated string of statuses. Parse `params[:status]` by splitting on `,`, stripping whitespace, downcasing each, then selecting only values matching `Loan.aasm.states.map { |s| s.name.to_s }`. Return the array if multiple valid statuses, the single string if one valid status, or `nil` if none valid.
  - [x] 3.2 Update `Loans::FilteredListQuery#call` to handle `status:` as either a String or an Array. No change when nil/blank.
  - [x] 3.3 Update `app/views/loans/index.html.erb` to display active filter context when multiple statuses are applied. Show a "Filtered by: Active, Overdue" indicator when the current filter is an array. Ensure filter pills visually indicate multi-selection or show a combined active state. Ensure "Clear filters" link works.

- [x] Task 4: Add explicit filter-context banners to list views (AC: #2, #4)
  - [x] 4.1 On `app/views/payments/index.html.erb`: When the page is loaded with `view` or `status` params (especially from dashboard drill-in), display a contextual banner at the top of the filter area: e.g., "Showing overdue payments" or "Showing upcoming payments". This makes the filter context explicit per AC #1.
  - [x] 4.2 On `app/views/loan_applications/index.html.erb`: When loaded with `status` params, display contextual banner: e.g., "Showing open and in-progress applications" for multi-status, or "Showing open applications" for single status.
  - [x] 4.3 On `app/views/loans/index.html.erb`: When loaded with `status` params, display contextual banner: e.g., "Showing active and overdue loans" for multi-status, or "Showing closed loans" for single status.
  - [x] 4.4 All banners must include a "View all" or "Clear filters" link back to the unfiltered list. This ensures the admin always has a clear exit from a drill-in view.
  - [x] 4.5 Use consistent styling across all banners: `bg-slate-50 border border-slate-200 rounded-lg px-4 py-2 text-sm text-slate-700` with a dismiss/clear link styled in `text-indigo-600`.

- [x] Task 5: Improve empty states for drill-in filtered views (AC: #4)
  - [x] 5.1 On `payments/index.html.erb`: When the view filter is `overdue` and no overdue payments exist, show a positive empty state: "No overdue payments — all repayments are on track." with a link back to the dashboard. When the view filter is `upcoming` and no upcoming payments exist, show: "No upcoming payments in the next 7 days." with a link back to the dashboard.
  - [x] 5.2 On `loan_applications/index.html.erb`: When the status filter returns no results and it came from a dashboard drill-in (multi-status filter), show: "No open or in-progress applications at this time." with a link back to the dashboard.
  - [x] 5.3 On `loans/index.html.erb`: When the status filter returns no results, show contextual empty state based on filter: "No active or overdue loans." or "No closed loans." with a link back to the dashboard.
  - [x] 5.4 Preserve existing empty states and "no search results" messaging for non-drill-in scenarios (direct navigation without filter params). Only add drill-in-specific empty states when filter params are present.

- [x] Task 6: Tests (AC: #1, #2, #3, #4)
  - [x] 6.1 `spec/requests/loan_applications_spec.rb` — Add tests:
    - Multi-status filter: `get loan_applications_path, params: { status: "open,in progress" }` returns both open and in-progress applications, excludes approved/rejected/cancelled.
    - Single status filter still works: `get loan_applications_path, params: { status: "open" }` returns only open.
    - Invalid status in multi-status is ignored: `get loan_applications_path, params: { status: "open,bogus" }` returns only open.
    - Filter context banner is rendered with correct text when multi-status applied.
    - Empty state renders correct message when no results match filter.
  - [x] 6.2 `spec/requests/loans_spec.rb` — Add tests:
    - Multi-status filter: `get loans_path, params: { status: "active,overdue" }` returns both active and overdue loans, excludes created/closed.
    - Single status filter still works.
    - Invalid status in multi-status is ignored.
    - Filter context banner is rendered.
    - Empty state renders correct message.
  - [x] 6.3 `spec/requests/payments_spec.rb` — Add tests:
    - Filter context banner renders "Showing overdue payments" when `view: "overdue"`.
    - Filter context banner renders "Showing upcoming payments" when `view: "upcoming"`.
    - Dashboard drill-in empty state for overdue shows positive "No overdue payments" message.
    - Dashboard drill-in empty state for upcoming shows "No upcoming payments" message.
  - [x] 6.4 `spec/requests/dashboard_spec.rb` — Add/update tests:
    - Dashboard open applications widget links to `loan_applications_path(status: "open,in progress")`.
    - Dashboard active loans widget links to `loans_path(status: "active,overdue")`.
    - Dashboard total disbursed widget links to `loans_path`.
    - Dashboard total repayment widget links to `payments_path`.
  - [x] 6.5 Run `bundle exec rspec` green. Run `bundle exec rubocop` green on all touched files. No new gems.

## Dev Notes

### Epic 6 Cross-Story Context

- **Epic 6** covers portfolio visibility, search, and trusted record history (FR57–FR70, FR73–FR74).
- **Story 6.1** (done) built the action-first dashboard with triage/summary widgets, query objects, controller, components, and nav bar. It established the drill-in links with query params but noted parity gaps as deferred work.
- **This story (6.2)** fixes parity between dashboard counts and drill-in filtered lists, adds explicit filter context, and improves empty states for dashboard-driven drill-in navigation.
- **Story 6.3** will add cross-entity search and linked record investigation.
- **Story 6.4** will add audit history visibility and record protection.
- **Story 6.5** will add derived-state integrity and historical snapshots.

### Critical Parity Gaps from Story 6.1

Story 6.1 explicitly documented these gaps (see `6-1-build-the-action-first-operational-dashboard.md` Dev Notes, "Drill-In Link Mappings" section):

1. **Open applications:** `OpenApplicationsQuery` counts `status IN ("open", "in progress")`, but the drill-in link sends `status=open` only. Users drilling in see fewer records than the dashboard shows.
2. **Active loans:** `ActiveLoansQuery` counts `status IN ("active", "overdue")`, but the drill-in link sends `status=active` only. Users drilling in miss overdue loans.
3. **Total disbursed / Total repayment:** These `SummaryWidgetComponent` widgets have no drill-in links at all. PRD FR64 requires: "Admin can open the relevant filtered record list directly from each dashboard widget or summary metric intended for operational investigation."

**These are the primary bugs this story fixes.**

### Critical Architecture Constraints

- **No new query objects.** Existing `FilteredListQuery` classes for payments, loans, and loan_applications already support the required filtering. This story only extends them to handle multi-status arrays.
- **No new controllers or routes.** All drill-in links use existing index routes with query params.
- **No new components.** Filter context banners and empty states are view-level markup, not new ViewComponents.
- **No mutations.** This story is entirely read-side: query parameter handling, filter display, and empty state messaging.
- **No new gems, no new migrations, no new initializers.**
- **Controllers remain thin.** The only controller changes are in `normalized_status_filter` private methods to support comma-separated params.

### Existing Infrastructure to Reuse

1. **`Payments::FilteredListQuery`** — Already supports `view: "overdue"` and `view: "upcoming"` params perfectly. No changes needed for payment drill-ins. Payments use `view` param, not `status`, for the dashboard-driven overdue/upcoming filters.
2. **`Loans::FilteredListQuery`** — Supports single `status:` string. Needs extension to handle an array of statuses via `.where(status: array)`.
3. **`LoanApplications::FilteredListQuery`** — Supports single `status:` string. Needs extension to handle an array of statuses.
4. **`Shared::StatusBadgeComponent`** — Used in filter pill rendering. No changes needed; multi-status highlighting is handled via view logic, not component changes.
5. **Dashboard widget components** — `TriageWidgetComponent` and `SummaryWidgetComponent` already support `href` and `label` props. Only the dashboard view template needs URL changes.
6. **Existing empty states** — All three list views already have empty-state and filtered-empty-state rendering. This story adds dashboard-drill-in-specific messaging variants.

### Files NOT to Create or Modify

- Do NOT create new ViewComponents for filter banners — use inline ERB in the existing views.
- Do NOT create new query objects — extend existing `FilteredListQuery` classes.
- Do NOT modify dashboard query objects (`app/queries/dashboard/*`) — they are correct; the drill-in links need to match them.
- Do NOT modify `DashboardController` — it doesn't change.
- Do NOT modify dashboard widget components (`app/components/dashboard/*`) — they already support all needed props.
- Do NOT modify `app/queries/payments/filtered_list_query.rb` — payment drill-ins already work correctly via `view` param.
- Do NOT modify `PaymentsController` index logic — `view: "overdue"` and `view: "upcoming"` already work.
- Do NOT add Turbo Frames or Streams — standard page navigation.

### File Structure (Expected Touchpoints)

| Area | Files |
|------|--------|
| Modify | `app/views/dashboard/show.html.erb` — Fix drill-in URLs for open apps, active loans; add hrefs for total disbursed/repayment |
| Modify | `app/controllers/loan_applications_controller.rb` — Support comma-separated multi-status filter |
| Modify | `app/controllers/loans_controller.rb` — Support comma-separated multi-status filter |
| Modify | `app/queries/loan_applications/filtered_list_query.rb` — Handle status as String or Array |
| Modify | `app/queries/loans/filtered_list_query.rb` — Handle status as String or Array |
| Modify | `app/views/loan_applications/index.html.erb` — Add filter context banner, multi-status display, drill-in empty states |
| Modify | `app/views/loans/index.html.erb` — Add filter context banner, multi-status display, drill-in empty states |
| Modify | `app/views/payments/index.html.erb` — Add filter context banners, drill-in-specific empty states |
| Modify | `spec/requests/loan_applications_spec.rb` — Add multi-status filter and banner tests |
| Modify | `spec/requests/loans_spec.rb` — Add multi-status filter and banner tests |
| Modify | `spec/requests/payments_spec.rb` — Add filter context banner and drill-in empty state tests |
| Modify | `spec/requests/dashboard_spec.rb` — Update drill-in link assertions |

### Existing Patterns to Follow

1. **Controller filter normalization** — See `PaymentsController#normalized_view_filter` for the allowlist pattern. Multi-status should follow the same defensive approach: split, strip, validate each against the allowlist, reject invalid entries.
2. **Query object `where` clause** — ActiveRecord `.where(status: value)` already handles both strings and arrays transparently. `.where(status: "active")` and `.where(status: ["active", "overdue"])` both work. The query object change is minimal.
3. **View filter display** — See `payments/index.html.erb` lines 30-70 for the existing pill-based filter bar with selected state styling. Multi-status filtering should visually highlight all active pills.
4. **Empty state pattern** — See `payments/index.html.erb` lines 180-215 for the existing empty/filtered-empty state pattern with conditional messaging based on `@has_payments` and filter presence.
5. **Request spec pattern** — See `spec/requests/payments_spec.rb` for how to test filtered lists: `get index_path, params: { ... }` followed by `assert_select` for expected content and absence of unexpected content.
6. **Tailwind styling** — Existing views use `bg-slate-50 border border-slate-200 rounded-lg` for secondary panels. Filter context banners should match this palette.

### Dashboard Drill-In Link Mapping (Corrected)

| Widget | Current Link (6.1) | Corrected Link (6.2) | Query Handled By |
|--------|---------------------|----------------------|------------------|
| Overdue payments | `payments_path(view: "overdue")` | **No change** — already correct | `Payments::FilteredListQuery` view: "overdue" |
| Upcoming payments | `payments_path(view: "upcoming")` | **No change** — already correct | `Payments::FilteredListQuery` view: "upcoming" |
| Open applications | `loan_applications_path(status: "open")` | `loan_applications_path(status: "open,in progress")` | `LoanApplications::FilteredListQuery` status: ["open", "in progress"] |
| Active loans | `loans_path(status: "active")` | `loans_path(status: "active,overdue")` | `Loans::FilteredListQuery` status: ["active", "overdue"] |
| Closed loans | `loans_path(status: "closed")` | **No change** — already correct | `Loans::FilteredListQuery` status: "closed" |
| Total disbursed | No link | `loans_path` | Unfiltered loans index |
| Total repayment | No link | `payments_path` | Unfiltered payments index |

### Edge Cases

1. **Comma-separated status with all invalid values:** `status: "bogus,invalid"` → treated as no filter (show all records). Same behavior as current single invalid status.
2. **Comma-separated status with mix of valid/invalid:** `status: "active,bogus"` → filter by `["active"]` only (single valid status treated as string, not array).
3. **Single status in comma format:** `status: "active"` → no change in behavior, backward compatible.
4. **Empty status param:** `status: ""` → treated as no filter. Existing behavior preserved.
5. **URL encoding of comma:** `status=open%2Cin+progress` or `status=open,in+progress` — both should work because `params[:status].to_s` will produce the string with commas.
6. **"in progress" status with spaces:** The comma split must preserve internal spaces: `"open,in progress"` → `["open", "in progress"]`. Use `split(",").map(&:strip)` NOT `split(/[,\s]+/)`.
7. **Browser back button after drill-in:** Standard page navigation — back button returns to dashboard with no stale state concerns.
8. **Multiple filter params together:** `status=active,overdue&q=search_term` — both multi-status and search should work together. The existing query composition pattern already supports this.

### UX Requirements

- **Filter context must be explicit (FR64, UX-DR5, AC #1):** When the admin arrives from a dashboard drill-in, the list page must clearly show what filter is active. This means a visible banner or indicator that names the filter, not just silently narrowing the list.
- **Empty states must be helpful (UX-DR5, AC #4):** An empty overdue payments list after drill-in should communicate "No overdue payments — all repayments are on track" rather than a generic "No results found." This is a positive operational signal.
- **Consistent filter bar behavior (UX-DR5):** Multi-status filters should visually indicate which pills are active. The "Clear filters" action must reset all query params and return to the unfiltered view.
- **Dashboard-to-list continuity (UX-DR3, UX-DR4):** The transition from dashboard widget click to filtered list should feel direct and contextual. The admin should not wonder "did I click the right thing?" upon landing.
- **WCAG 2.1 Level A (UX-DR17):** Filter context banners must be accessible. Use semantic HTML, visible text labels, and ensure keyboard navigation works for the "Clear filters" link.

### Library / Framework Requirements

- **Rails ~> 8.1** — standard controller param handling, routing.
- **No new gems, no new migrations, no new initializers.**
- **ActiveRecord `.where(status: array)`** — built-in array handling for IN queries.

### Previous Story Intelligence (6.1)

- **Story 6.1 explicitly documented parity gaps as deferred work.** The "Drill-In Link Mappings" section noted: "The open applications widget count includes BOTH 'open' and 'in progress' statuses, but the drill-in link uses `status: 'open'`. This is intentional for Story 6.1 — Story 6.2 will refine drill-in behavior to support multi-status filtering if needed."
- **Story 6.1 established all dashboard components, queries, and routes.** No structural changes needed — only URL tweaks in the view and filter-handling extensions in controllers/queries.
- **Story 6.1 debug notes:** The `resource :dashboard` route required explicit `controller: "dashboard"` to avoid mapping to `DashboardsController`. This is already fixed and stable.
- **Story 6.1 test regressions:** 11 existing tests had to be updated for root route change and nav bar. This story should be careful with any changes that affect existing test assertions (e.g., changing dashboard link URLs will require updating `spec/requests/dashboard_spec.rb`).
- **Story 6.1 review findings:** Deferred items include "Nav bar logic in layout should be extracted to helper or ViewComponent" — not in scope for 6.2.

### Git Intelligence

Recent commits and their relevance:

- `ff3b07d` **Add action-first operational dashboard with triage widgets and portfolio summary.** (Story 6.1) — Established all dashboard infrastructure. This story builds directly on it.
- `7d88ce1` **Add end-to-end repayment lifecycle system tests.** — System test patterns for payment flows.
- `b6c7bdb` **Add test coverage for LateFeePolicy, Transition, LookupQuery, Session, and payment E2E flows.** — Query and spec patterns.
- `a09b7a7` **Apply flat late fees and close loans from completed repayment facts.** (Story 5.6) — Loan lifecycle states are complete.
- `fd223fc` **Derive overdue payment and loan states from recorded facts.** (Story 5.5) — Overdue state derivation is in place.

**Preferred commit style:** `"Add dashboard drill-in filtered views with multi-status support and filter context."`

### Non-Goals (Explicit Scope Boundaries)

- **No cross-entity search.** Story 6.3 handles global search across borrowers, applications, loans, and payments.
- **No audit history visibility.** Story 6.4 handles audit trail display.
- **No new shared components.** Filter banners are inline view markup, not reusable components. A `Shared::FilterBarComponent` may be created in a future refactoring story.
- **No payment list query changes.** The `Payments::FilteredListQuery` already handles `view: "overdue"` and `view: "upcoming"` correctly. Payment drill-ins work as-is.
- **No dashboard query changes.** The counts are correct; only the drill-in URLs need to match them.
- **No dashboard layout changes.** Widget positioning and visual design remain from Story 6.1.
- **No auto-refresh, polling, or Turbo Streams.**
- **No mobile or tablet considerations.**

### Project Context Reference

- No `project-context.md` found. PRD, architecture, UX spec, and Story 6.1 are the authoritative sources.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md:907-934` — Story 6.2 BDD acceptance criteria]
- [Source: `_bmad-output/planning-artifacts/prd.md:171-181` — Journey 4: Dashboard Monitoring and Searchable Records]
- [Source: `_bmad-output/planning-artifacts/prd.md:337` — Every dashboard widget should open the relevant filtered list]
- [Source: `_bmad-output/planning-artifacts/prd.md:386` — Dashboard widgets for upcoming/overdue payments with filtered-list drill-in]
- [Source: `_bmad-output/planning-artifacts/prd.md:403` — Upcoming/overdue are non-negotiable launch drill-in entry points]
- [Source: `_bmad-output/planning-artifacts/prd.md:482-483` — FR44/FR45: Dashboard widget and filtered list for upcoming/overdue payments]
- [Source: `_bmad-output/planning-artifacts/prd.md:505` — FR64: Open filtered list from each dashboard widget or summary metric]
- [Source: `_bmad-output/planning-artifacts/architecture.md:649-654` — Dashboard query objects in `app/queries/dashboard/`]
- [Source: `_bmad-output/planning-artifacts/architecture.md:817` — Query objects must not perform mutations]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md:536-543` — Dashboard Triage Widget component specification]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md:547-553` — Filter Bar specification: active filter state must be visible]
- [Source: `_bmad-output/implementation-artifacts/6-1-build-the-action-first-operational-dashboard.md:244-254` — Drill-in link mappings with known parity gaps]
- [Source: `app/controllers/payments_controller.rb` — Existing view/status/due_window filter normalization]
- [Source: `app/controllers/loans_controller.rb` — Existing status filter normalization]
- [Source: `app/controllers/loan_applications_controller.rb` — Existing status filter normalization]
- [Source: `app/queries/payments/filtered_list_query.rb` — Existing payment query with VIEW_TO_STATUS mapping]
- [Source: `app/queries/loans/filtered_list_query.rb` — Existing loan query]
- [Source: `app/queries/loan_applications/filtered_list_query.rb` — Existing application query]
- [Source: `app/views/payments/index.html.erb` — Existing filter bar and empty state patterns]
- [Source: `app/views/loans/index.html.erb` — Existing filter bar]
- [Source: `app/views/loan_applications/index.html.erb` — Existing filter bar]
- [Source: `config/routes.rb` — Current routing structure]

## Dev Agent Record

### Agent Model Used

Cursor Opus 4.6

### Debug Log References

- 1 system test regression (`payment_workflow_spec.rb`) caused by updated overdue empty state text — fixed immediately.
- 1 request test failure in payments upcoming empty state — initial test used a pending payment (due in 30 days) which was returned by the "upcoming" filter (maps to pending status). Fixed by using a completed payment so the filter returns nothing.

### Completion Notes List

- Fixed dashboard drill-in link parity: open applications widget now sends `status=open,in progress`, active loans widget sends `status=active,overdue`, total disbursed links to `loans_path`, total repayment links to `payments_path`.
- Extended `LoanApplicationsController` and `LoansController` to parse comma-separated multi-status params with allowlist validation. Single valid status returns string (backward compatible); multiple valid returns array.
- Extended `LoanApplications::FilteredListQuery` and `Loans::FilteredListQuery` to pass arrays through to ActiveRecord's `.where(status:)` which handles `IN (?)` transparently.
- Updated loan_applications, loans, and payments index views with filter-context banners (consistent `bg-slate-50` styling with `text-indigo-600` clear link).
- Added contextual drill-in empty states: overdue payments shows positive "all on track" message, upcoming shows "no upcoming in next 7 days", multi-status filters show descriptive messages with dashboard return links.
- Preserved all existing non-drill-in empty states and filter behaviors.
- Added 16 new request spec tests across all 4 spec files. Updated 2 existing tests (dashboard drill-in links, payments filtered-empty). Updated 1 system test for new empty state text.
- Full suite: 614 examples, 0 failures. RuboCop: 0 offenses on all Ruby files. No new gems, no new migrations.

### Review Findings

- [x] [Review][Decision] Query objects pass Array through without per-element validation — Fixed: added per-element allowlist validation in both `FilteredListQuery#normalized_status` methods. [app/queries/loan_applications/filtered_list_query.rb:28, app/queries/loans/filtered_list_query.rb:28]
- [x] [Review][Decision] Hardcoded empty-state copy in loan_applications assumes exactly "open,in progress" — Fixed: made dynamic using `filter_label` pattern matching the loans view. [app/views/loan_applications/index.html.erb:134]
- [x] [Review][Decision] Filter-context banner uses inconsistent conjunction ("and" vs "or") — Fixed: standardized to "or" across all banner and empty-state text in both views. [app/views/loan_applications/index.html.erb:78, app/views/loans/index.html.erb:89]
- [x] [Review][Defer] Status pill click in multi-status mode replaces filter instead of toggling — Deferred: UX enhancement for a future story; current single-select pill behavior is the standard pattern. [app/views/loan_applications/index.html.erb:60, app/views/loans/index.html.erb:71]
- [x] [Review][Patch] Loan applications filter bar lacks "All" pill — Fixed: added "All" pill matching the loans and payments filter bar pattern. [app/views/loan_applications/index.html.erb:57-70]
- [x] [Review][Patch] No test for single-status filter-context banner rendering — Fixed: added tests in both loan_applications and loans request specs. [spec/requests/loan_applications_spec.rb, spec/requests/loans_spec.rb]
- [x] [Review][Defer] Duplicated `normalized_status_filter` logic across controllers — deferred, pre-existing pattern
- [x] [Review][Defer] Polymorphic return type (String vs Array) from `normalized_status_filter` — deferred, design choice affecting downstream consumers
- [x] [Review][Defer] Hardcoded status combinations in dashboard view as magic strings — deferred, pre-existing pattern
- [x] [Review][Defer] No upper bound on comma-separated status count — deferred, low-risk given allowlist validation
- [x] [Review][Defer] Payments filter banner pattern differs from loans/applications pattern — deferred, pre-existing divergence
- [x] [Review][Defer] Test specs use inconsistent auth strategies (post session vs sign_in_as) — deferred, pre-existing
- [x] [Review][Defer] Currency hardcoded to "INR" in dashboard view — deferred, pre-existing
- [x] [Review][Defer] No unit test for query-layer array pass-through — deferred, covered by integration tests

### File List

- `app/views/dashboard/show.html.erb` — Modified (drill-in URLs for open apps, active loans; added hrefs for total disbursed/repayment)
- `app/controllers/loan_applications_controller.rb` — Modified (multi-status comma param support in `normalized_status_filter`)
- `app/controllers/loans_controller.rb` — Modified (multi-status comma param support in `normalized_status_filter`)
- `app/queries/loan_applications/filtered_list_query.rb` — Modified (pass-through array status in `normalized_status`)
- `app/queries/loans/filtered_list_query.rb` — Modified (pass-through array status in `normalized_status`)
- `app/views/loan_applications/index.html.erb` — Modified (multi-status pill selection, filter-context banner, drill-in empty state)
- `app/views/loans/index.html.erb` — Modified (multi-status pill selection, filter-context banner, drill-in empty state)
- `app/views/payments/index.html.erb` — Modified (filter-context banner, drill-in-specific empty states for overdue/upcoming)
- `spec/requests/dashboard_spec.rb` — Modified (updated drill-in link assertions for multi-status + summary widget links)
- `spec/requests/loan_applications_spec.rb` — Modified (added multi-status filter, banner, empty state tests)
- `spec/requests/loans_spec.rb` — Modified (added multi-status filter, banner, empty state tests)
- `spec/requests/payments_spec.rb` — Modified (added banner and drill-in empty state tests, updated existing filtered-empty test)
- `spec/system/payment_workflow_spec.rb` — Modified (updated empty state text assertion for overdue)
