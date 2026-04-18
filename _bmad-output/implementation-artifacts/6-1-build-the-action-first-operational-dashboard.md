# Story 6.1: Build the Action-First Operational Dashboard

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want a dashboard that surfaces the work that matters most,
so that I can begin each day with immediate operational clarity.

## Acceptance Criteria

1. **Given** the admin lands on the dashboard
   **When** the page loads
   **Then** it presents the dashboard as an action-first operational workspace
   **And** it prioritizes overdue payments, upcoming payments, open applications, and active loans as the primary triage signals for lending operations

2. **Given** operational data exists
   **When** the dashboard renders
   **Then** it shows widgets for overdue payments, upcoming payments, open applications, active loans, closed loans, total disbursed amount, and total repayment amount
   **And** the information follows the shared dashboard widget and visual hierarchy patterns

3. **Given** the dashboard is the primary workspace entry point
   **When** the admin uses it repeatedly
   **Then** the experience remains clear, desktop-first, and fast to scan
   **And** the data reflects the latest committed system state on each load

## Tasks / Subtasks

- [x] Task 1: Create the dashboard query objects (AC: #1, #2, #3)
  - [x] 1.1 Create `app/queries/dashboard/overdue_payments_query.rb`. Return count of payments where `status == "overdue"`. Use `Payment.where(status: "overdue").count`. Expose via `self.call` returning `Integer`. Do NOT run `Loans::RefreshStatus` — the dashboard is a read surface; freshness comes from per-record hooks already in place (Story 5.5/5.6).
  - [x] 1.2 Create `app/queries/dashboard/upcoming_payments_query.rb`. Return count of payments where `status == "pending"` AND `due_date` is between `Date.current` and `Date.current + 7.days` (inclusive). The 7-day window matches the existing `Payments::FilteredListQuery` `next_7_days` due-window AND the PRD ("upcoming payments due within the next 7 calendar days"). Use `Payment.where(status: "pending", due_date: Date.current..(Date.current + 7.days)).count`.
  - [x] 1.3 Create `app/queries/dashboard/open_applications_query.rb`. Return count of `LoanApplication` where `status IN ("open", "in progress")`. These are the two pre-decision active statuses from `LoanApplication::STATUSES`. Use `LoanApplication.where(status: ["open", "in progress"]).count`.
  - [x] 1.4 Create `app/queries/dashboard/active_loans_query.rb`. Return count of `Loan` where `status IN ("active", "overdue")`. Both are "active" in the operational sense — loans with outstanding repayment obligations. Use `Loan.where(status: %w[active overdue]).count`.
  - [x] 1.5 Create `app/queries/dashboard/portfolio_summary_query.rb`. Return a `Result` struct with: `closed_loans_count` (`Loan.where(status: "closed").count`), `total_disbursed_cents` (`Invoice.disbursement.sum(:amount_cents)` — uses the existing `Invoice.disbursement` scope which filters `invoice_type == "disbursement"`), `total_repayment_cents` (`Invoice.payment.sum(:amount_cents)` — uses the existing `Invoice.payment` scope which filters `invoice_type == "payment"`). Expose via `self.call` → `Result`. Use `Money.new(cents, "INR")` for display in the view.
  - [x] 1.6 All query files extend `ApplicationQuery` and follow `self.call(...)` → `new(...).call` pattern established by `Borrowers::LookupQuery`, `Loans::FilteredListQuery`, etc.
  - [x] 1.7 Do NOT add caching. Dashboard queries are simple counts/sums on indexed columns; NFR1 2-second target is achievable without caching for MVP single-admin usage. Caching can be added in a later story if needed.

- [x] Task 2: Create the `DashboardController` (AC: #1, #2, #3)
  - [x] 2.1 Create `app/controllers/dashboard_controller.rb`. Single `show` action. Include the `Authentication` concern (same as all other controllers — `before_action :require_authentication`).
  - [x] 2.2 In `show`: call each dashboard query and assign instance variables: `@overdue_payments_count`, `@upcoming_payments_count`, `@open_applications_count`, `@active_loans_count`, `@portfolio` (from `PortfolioSummaryQuery`).
  - [x] 2.3 Authorize with `authorize :dashboard` using `DashboardPolicy`.
  - [x] 2.4 Do NOT call `Loans::RefreshStatus` or `Payments::DeriveOverdueStates`. Dashboard is a read surface. State derivation happens on individual record views (Story 5.5/5.6 hooks).
  - [x] 2.5 Do NOT paginate. Dashboard is a single summary page with counts/totals.

- [x] Task 3: Create `DashboardPolicy` (AC: #1)
  - [x] 3.1 Create `app/policies/dashboard_policy.rb`. For MVP, `show?` returns `true` for any authenticated user (single seeded admin). Follow the `ApplicationPolicy` pattern. Define `class Scope` even if unused — Pundit convention.
  - [x] 3.2 The policy must inherit from `ApplicationPolicy`. Use `def show? = true` for the MVP seeded-admin model (same pattern as other policies that default-allow for authenticated users).

- [x] Task 4: Create the `Dashboard::TriageWidgetComponent` (AC: #2)
  - [x] 4.1 Create `app/components/dashboard/triage_widget_component.rb` inheriting from `ApplicationComponent`. Props: `title:` (String), `count:` (Integer), `tone:` (Symbol — `:danger`, `:warning`, `:neutral`, `:success`), `href:` (String — drill-in link URL), `label:` (String — link text, e.g. "View all"). Default `tone: :neutral`.
  - [x] 4.2 Create `app/components/dashboard/triage_widget_component.html.erb`. Structure: a card (`<article>`) with:
    - Title as `<p>` with muted style
    - Count as `<p>` with large bold text and tone-driven color (`:danger` → rose, `:warning` → amber, `:success` → emerald, `:neutral` → slate)
    - Drill-in link styled as a secondary text link
    - Tone-driven left border accent (4px colored border-left matching the tone)
  - [x] 4.3 Use Tailwind classes consistent with the existing `Shared::StatusBadgeComponent` tone mapping: `danger` → rose, `warning` → amber, `success` → emerald, `neutral` → slate. Add a `TONE_BORDER_CLASSES` and `TONE_TEXT_CLASSES` hash mirroring the badge pattern.
  - [x] 4.4 Accessibility: card has `role="region"` and `aria-label` set to the title. Count is visually prominent. Link is keyboard-focusable with visible focus ring.

- [x] Task 5: Create the `Dashboard::SummaryWidgetComponent` (AC: #2)
  - [x] 5.1 Create `app/components/dashboard/summary_widget_component.rb` inheriting from `ApplicationComponent`. Props: `title:` (String), `value:` (String — pre-formatted for display, e.g. "₹1,25,000.00" or "12"), `href:` (String, optional — drill-in link URL), `label:` (String, optional — link text).
  - [x] 5.2 Create `app/components/dashboard/summary_widget_component.html.erb`. Structure: a card (`<article>`) with:
    - Title as `<p>` with muted style
    - Value as `<p>` with large semibold text in slate-950
    - Optional drill-in link when `href` is present
  - [x] 5.3 Simpler than triage widgets — no tone-driven coloring. These are informational, not action-driving. Use consistent card styling with the triage widgets (same border radius, padding, shadow).

- [x] Task 6: Create the dashboard view (AC: #1, #2, #3)
  - [x] 6.1 Create `app/views/dashboard/show.html.erb`. Structure the page with a clear visual hierarchy:
    - Page header: "Dashboard" title with current date and signed-in admin email
    - **Action-driving triage section** (top, most prominent): 2×2 grid of `TriageWidgetComponent` cards for:
      - Overdue payments (tone: `:danger`, href: `payments_path(view: "overdue")`)
      - Upcoming payments (tone: `:warning`, href: `payments_path(view: "upcoming")`)
      - Open applications (tone: `:neutral`, href: `loan_applications_path(status: "open")`)
      - Active loans (tone: `:neutral`, href: `loans_path(status: "active")`)
    - **Portfolio summary section** (below triage): 3-column grid of `SummaryWidgetComponent` cards for:
      - Closed loans (value: count, href: `loans_path(status: "closed")`)
      - Total disbursed (value: formatted money amount using `humanized_money_with_symbol`)
      - Total repayment (value: formatted money amount using `humanized_money_with_symbol`)
  - [x] 6.2 The triage section must be the first and most visually prominent section. FR57/FR58/UX-DR3 require the dashboard to prioritize overdue payments as the primary triage signal.
  - [x] 6.3 When a count is zero, the widget should still render with the zero count visible and the drill-in link active. Zero overdue payments is a healthy state the admin should see explicitly (PRD Journey 4: "the admin never loses clarity").
  - [x] 6.4 Use `content_for :title, "Dashboard | lending_rails"`.
  - [x] 6.5 Navigation links at top of the dashboard: Borrowers, Applications, Loans, Payments, Sign out. These provide quick access to the main operational areas. Keep consistent with the current home page link set but remove non-operational links (health check, background jobs).
  - [x] 6.6 Do NOT add auto-refresh, polling, or Turbo Stream subscriptions. NFR8 requires freshness on each page load, not live updates.
  - [x] 6.7 Design should be desktop-first, optimized for laptop and desktop widths (1024px+). Use responsive grid that collapses gracefully on narrower desktop widths.
  - [x] 6.8 Visual tone: calm, professional, slate-based neutral palette matching the existing app style. Triage widgets use subtle tone-driven accents, not alarming full-color backgrounds.

- [x] Task 7: Wire routing and root redirect (AC: #1, #3)
  - [x] 7.1 Add to `config/routes.rb`: `resource :dashboard, only: :show`. This creates `GET /dashboard` → `DashboardController#show` with `dashboard_path` helper.
  - [x] 7.2 Change the root route from `root "home#index"` to `root "dashboard#show"`. The dashboard IS the primary workspace entry point (FR57, PRD Journey 4). The admin should land here after login.
  - [x] 7.3 Keep the `HomeController` and `home/index.html.erb` in place for now — they will be removed in a cleanup story if needed. Do NOT delete them in this story.
  - [x] 7.4 `SessionsController#create` already redirects to `after_authentication_url` which resolves to `root_url` via `Authentication` concern (`app/controllers/concerns/authentication.rb:37-38`). Changing `root` to `dashboard#show` automatically makes post-login redirect land on the dashboard. NO change to `SessionsController` needed.

- [x] Task 8: Update the application layout for dashboard navigation (AC: #1)
  - [x] 8.1 Add a minimal top navigation bar to `app/views/layouts/application.html.erb` that renders ONLY for authenticated users (`if Current.user`). Structure: logo/product name on the left, navigation links (Dashboard, Borrowers, Applications, Loans, Payments) in the center, Sign out on the right.
  - [x] 8.2 Use Tailwind classes matching the existing slate-based palette. The nav should be `bg-white border-b border-slate-200` with `max-w-7xl` centering.
  - [x] 8.3 Highlight the current section using `current_page?` helper or a simple controller-name check. Use a subtle underline or weight change, not a full background highlight.
  - [x] 8.4 Move the flash alert/notice rendering BELOW the nav bar but ABOVE the main content area (current placement).
  - [x] 8.5 Do NOT render the nav bar on the login page. Use the `if Current.user` guard.
  - [x] 8.6 Preserve the existing `<main>` wrapper with `max-w-7xl` and padding.
  - [x] 8.7 Accessibility: nav uses `<nav>` element with `aria-label="Main navigation"`. Links are keyboard-accessible with visible focus states.

- [x] Task 9: Tests (AC: #1, #2, #3)
  - [x] 9.1 `spec/queries/dashboard/overdue_payments_query_spec.rb` (new):
    - Returns 0 when no payments exist.
    - Returns correct count when overdue payments exist.
    - Excludes pending and completed payments from count.
  - [x] 9.2 `spec/queries/dashboard/upcoming_payments_query_spec.rb` (new):
    - Returns 0 when no pending payments in 7-day window.
    - Returns correct count for payments due within 7 days.
    - Excludes payments due after 7 days.
    - Excludes overdue and completed payments.
    - Includes payments due today.
  - [x] 9.3 `spec/queries/dashboard/open_applications_query_spec.rb` (new):
    - Returns 0 when no open/in-progress applications.
    - Counts "open" and "in progress" applications.
    - Excludes approved, rejected, and cancelled applications.
  - [x] 9.4 `spec/queries/dashboard/active_loans_query_spec.rb` (new):
    - Returns 0 when no active/overdue loans.
    - Counts active and overdue loans.
    - Excludes created, documentation_in_progress, ready_for_disbursement, and closed loans.
  - [x] 9.5 `spec/queries/dashboard/portfolio_summary_query_spec.rb` (new):
    - Returns zeros when no data exists.
    - Returns correct `closed_loans_count`.
    - Returns correct `total_disbursed_cents` from `Invoice.disbursement` scope.
    - Returns correct `total_repayment_cents` from `Invoice.payment` scope.
    - Excludes invoices of the wrong `invoice_type` from the respective totals.
  - [x] 9.6 `spec/requests/dashboard_spec.rb` (new):
    - Unauthenticated user is redirected to login.
    - Authenticated user sees the dashboard page (200 response).
    - Dashboard renders overdue payments widget with correct count.
    - Dashboard renders upcoming payments widget with correct count.
    - Dashboard renders open applications widget with correct count.
    - Dashboard renders active loans widget with correct count.
    - Dashboard renders closed loans count.
    - Dashboard renders total disbursed amount.
    - Dashboard renders total repayment amount.
    - Dashboard renders drill-in links to the correct filtered list paths.
    - Dashboard renders navigation links.
    - Root path resolves to the dashboard.
  - [x] 9.7 `spec/components/dashboard/triage_widget_component_spec.rb` (new):
    - Renders title, count, and drill-in link.
    - Applies danger tone classes for `:danger`.
    - Applies warning tone classes for `:warning`.
    - Applies neutral tone classes for `:neutral`.
    - Renders zero count without error.
  - [x] 9.8 `spec/components/dashboard/summary_widget_component_spec.rb` (new):
    - Renders title and value.
    - Renders drill-in link when href provided.
    - Omits link when href is nil.
  - [x] 9.9 `spec/policies/dashboard_policy_spec.rb` (new):
    - `show?` returns true for authenticated admin user.
  - [x] 9.10 Run `bundle exec rspec` green. Run `bundle exec rubocop` green on all touched files. No new gems.

## Dev Notes

### Epic 6 Cross-Story Context

- **Epic 6** covers portfolio visibility, search, and trusted record history (FR57–FR70, FR73–FR74).
- **This story (6.1)** builds the action-first dashboard as the primary workspace entry point. It replaces the current `HomeController#index` placeholder with a real dashboard surface.
- **Story 6.2** will add drill-in behavior from dashboard widgets to filtered operational lists with pre-applied filters. The dashboard links in this story should use query params that Story 6.2's existing filtered list queries already understand (e.g. `payments_path(view: "overdue")`).
- **Story 6.3** will add cross-entity search and linked record investigation.
- **Story 6.4** will add audit history visibility.
- **Story 6.5** will add derived-state integrity and historical snapshots.

### Critical Architecture Constraints

- **Dashboard queries live in `app/queries/dashboard/`.** [Source: `_bmad-output/planning-artifacts/architecture.md:649-654`] These are read-model query objects, not services. They must NOT perform mutations.
- **Controller is thin.** [Source: `_bmad-output/planning-artifacts/architecture.md:579-582`] `DashboardController#show` calls query objects and assigns ivars. No business logic in the controller.
- **No state derivation on dashboard load.** The dashboard is a summary read surface. Running `Loans::RefreshStatus` or `Payments::DeriveOverdueStates` per-request on the dashboard would be O(loans) cost. State freshness is guaranteed by the per-record hooks already wired in Stories 5.5/5.6 (`LoansController#show`, `PaymentsController#show`, `PaymentsController#mark_completed`). The dashboard reads the latest committed state, which is what NFR8 requires.
- **Money-rails for currency display.** Use `humanized_money_with_symbol(Money.new(cents, "INR"))` consistently. [Source: `app/views/loans/show.html.erb`, `app/services/loans/disburse.rb:48`]
- **ViewComponent for reusable widgets.** [Source: `_bmad-output/planning-artifacts/architecture.md:277-282`] Dashboard triage widgets and summary widgets are reusable components. Use the established `ApplicationComponent` base class.
- **Pundit for authorization.** [Source: `_bmad-output/planning-artifacts/architecture.md:259`] Even though MVP is single-admin, the `DashboardPolicy` must exist for consistency.
- **Turbo is the navigation model.** The dashboard should work with standard Turbo page visits. No Turbo Frames or Streams needed for this story.
- **No new gems.** Query objects + controller + view + components + specs.
- **No new migrations.** All underlying tables and columns exist.

### Existing Infrastructure to Reuse

1. **`Payments::FilteredListQuery`** — already supports `view: "overdue"` and `view: "upcoming"` params, plus `due_window: "next_7_days"`. Dashboard drill-in links should pass params that this query already understands. [Source: `app/queries/payments/filtered_list_query.rb`]
2. **`Loans::FilteredListQuery`** — already supports `status: "active"` and `status: "closed"` params. [Source: `app/queries/loans/filtered_list_query.rb`]
3. **`LoanApplications::FilteredListQuery`** — already supports `status: "open"` param. [Source: `app/queries/loan_applications/filtered_list_query.rb`]
4. **`Shared::StatusBadgeComponent`** — tone mapping (`:danger`, `:warning`, `:success`, `:neutral`) and Tailwind class patterns. [Source: `app/components/shared/status_badge_component.rb`]
5. **`ApplicationComponent`** — base class for ViewComponents. [Source: `app/components/application_component.rb`]
6. **`ApplicationQuery`** — base class for query objects. [Source: `app/queries/application_query.rb`]
7. **`ApplicationPolicy`** — base class for Pundit policies. [Source: `app/policies/application_policy.rb`]
8. **`Invoice` model** — has `invoice_type` attribute with values `"disbursement"` and `"payment"`, plus matching scopes `Invoice.disbursement` and `Invoice.payment`. Used for `total_disbursed_cents` and `total_repayment_cents` aggregation. [Source: `app/models/invoice.rb`]
9. **`money-rails` `humanized_money_with_symbol`** — already used throughout views. Include `MoneyRails::ActionViewExtension` or ensure the helper is available (it should be globally available via money-rails Railtie).

### Files NOT to Create or Modify

- Do NOT create `app/services/dashboard/` — the dashboard has no mutations; query objects are sufficient.
- Do NOT create `app/jobs/refresh_dashboard_snapshots_job.rb` — live queries are sufficient for MVP single-admin usage.
- Do NOT create `app/models/dashboard_snapshot.rb` or any dashboard-related model.
- Do NOT modify `Loans::RefreshStatus`, `Payments::DeriveOverdueStates`, `Payments::MarkOverdue`, or any existing service.
- Do NOT modify existing controllers (`LoansController`, `PaymentsController`, `LoanApplicationsController`, `BorrowersController`).
- Do NOT modify existing query objects in `app/queries/borrowers/`, `app/queries/loans/`, `app/queries/loan_applications/`, `app/queries/payments/`.
- Do NOT modify existing views for loans, payments, applications, or borrowers.
- Do NOT delete `HomeController` or `app/views/home/index.html.erb` — leave them in place.
- Do NOT add `DoubleEntry` postings, new accounting accounts, or any financial mutations.

### File Structure (Expected Touchpoints)

| Area | Files |
|------|--------|
| New | `app/queries/dashboard/overdue_payments_query.rb` |
| New | `app/queries/dashboard/upcoming_payments_query.rb` |
| New | `app/queries/dashboard/open_applications_query.rb` |
| New | `app/queries/dashboard/active_loans_query.rb` |
| New | `app/queries/dashboard/portfolio_summary_query.rb` |
| New | `app/controllers/dashboard_controller.rb` |
| New | `app/policies/dashboard_policy.rb` |
| New | `app/components/dashboard/triage_widget_component.rb` |
| New | `app/components/dashboard/triage_widget_component.html.erb` |
| New | `app/components/dashboard/summary_widget_component.rb` |
| New | `app/components/dashboard/summary_widget_component.html.erb` |
| New | `app/views/dashboard/show.html.erb` |
| New | `spec/queries/dashboard/overdue_payments_query_spec.rb` |
| New | `spec/queries/dashboard/upcoming_payments_query_spec.rb` |
| New | `spec/queries/dashboard/open_applications_query_spec.rb` |
| New | `spec/queries/dashboard/active_loans_query_spec.rb` |
| New | `spec/queries/dashboard/portfolio_summary_query_spec.rb` |
| New | `spec/requests/dashboard_spec.rb` |
| New | `spec/components/dashboard/triage_widget_component_spec.rb` |
| New | `spec/components/dashboard/summary_widget_component_spec.rb` |
| New | `spec/policies/dashboard_policy_spec.rb` |
| Modify | `config/routes.rb` — add `resource :dashboard, only: :show` and change `root` |
| Modify | `app/views/layouts/application.html.erb` — add authenticated nav bar |

### Existing Patterns to Follow

1. **Query object shape** — `self.call(...)` → `new(...).call` pattern. See `Payments::FilteredListQuery`, `Loans::FilteredListQuery`. Dashboard queries are simpler (just counts/sums) but follow the same class structure. [Source: `app/queries/payments/filtered_list_query.rb`]
2. **ViewComponent shape** — `initialize` with keyword args, ERB template, `ApplicationComponent` base. See `Shared::StatusBadgeComponent` for tone mapping pattern. [Source: `app/components/shared/status_badge_component.rb`]
3. **Controller shape** — thin controller that delegates to queries, assigns ivars, renders view. Include `Authentication` concern. Call `authorize`. See `PaymentsController`, `LoansController`. [Source: `app/controllers/payments_controller.rb`]
4. **Pundit policy shape** — inherit `ApplicationPolicy`, define action predicate methods. [Source: `app/policies/application_policy.rb`]
5. **Tailwind visual system** — slate-based neutral palette, `bg-white` cards with `border border-slate-200 rounded-2xl shadow-sm`, `text-slate-950` for primary text, `text-slate-600` for secondary text. See existing views for consistent class application.
6. **Route conventions** — UUID constraints for resource IDs, `resource` (singular) for singleton resources like `session` and `dashboard`. [Source: `config/routes.rb`]
7. **Request spec shape** — `sign_in` helper, test response codes and body content. See `spec/requests/loans_spec.rb`, `spec/requests/payments_spec.rb` for patterns.

### Drill-In Link Mappings

| Widget | Drill-in URL | Filtered List Query |
|--------|-------------|---------------------|
| Overdue payments | `payments_path(view: "overdue")` | `Payments::FilteredListQuery` with `view: "overdue"` → status `"overdue"` |
| Upcoming payments | `payments_path(view: "upcoming")` | `Payments::FilteredListQuery` with `view: "upcoming"` → status `"pending"` |
| Open applications | `loan_applications_path(status: "open")` | `LoanApplications::FilteredListQuery` with `status: "open"` |
| Active loans | `loans_path(status: "active")` | `Loans::FilteredListQuery` with `status: "active"` |
| Closed loans | `loans_path(status: "closed")` | `Loans::FilteredListQuery` with `status: "closed"` |
| Total disbursed | `loans_path` | General loans index (no pre-filter) |
| Total repayment | `payments_path` | General payments index (no pre-filter) |

**Important:** The open applications widget count includes BOTH "open" and "in progress" statuses, but the drill-in link uses `status: "open"`. This is intentional for Story 6.1 — Story 6.2 will refine drill-in behavior to support multi-status filtering if needed. For now, the link serves as a starting point for investigation.

### Dashboard Widget Priority Order

Per FR57/FR58 and UX-DR3, the dashboard layout must prioritize action-driving widgets:

1. **Overdue payments** — highest urgency, danger tone (rose)
2. **Upcoming payments** — time-sensitive, warning tone (amber)
3. **Open applications** — needs attention, neutral tone (slate)
4. **Active loans** — operational context, neutral tone (slate)

Then portfolio summary:
5. **Closed loans** — summary context
6. **Total disbursed** — financial summary
7. **Total repayment** — financial summary

### Edge Cases

1. **Empty database (no data at all):** All widgets show 0. No errors. Dashboard renders successfully with all zero-state widgets visible.
2. **No overdue payments:** Overdue widget shows 0 with danger tone — this is a HEALTHY state, not an empty state. The admin should see "0 overdue" as reassurance.
3. **High counts:** Widget displays should handle 4+ digit numbers without layout break.
4. **Concurrent requests:** Dashboard queries are read-only; no lock contention.
5. **Money formatting for zero:** `humanized_money_with_symbol(Money.new(0, "INR"))` renders `"₹0.00"` — confirm this displays correctly.
6. **Active loans includes overdue loans:** The "Active loans" widget counts both `active` and `overdue` statuses. This is correct — from the admin's operational perspective, overdue loans are still "active" (they have outstanding obligations). If the admin wants to distinguish, they drill into the filtered list.
7. **Invoice type values:** `Invoice` model uses `invoice_type` column (NOT `category`) with values `"disbursement"` and `"payment"`, plus matching scopes `Invoice.disbursement` and `Invoice.payment`. Use the scopes, not raw `where` clauses on `invoice_type`.

### UX Requirements

- **Visual hierarchy:** Triage widgets (overdue, upcoming, open apps, active loans) are the first and most prominent section. Summary widgets are below and visually subordinate. This matches the UX spec's "action-first triage surface" principle (UX-DR3).
- **Tone-driven accents:** Overdue → rose/danger accent. Upcoming → amber/warning accent. Others → slate/neutral. Use subtle left-border accents, NOT full-color backgrounds. The design should feel calm and professional, not alarming.
- **Consistent card styling:** All widgets use the same card structure (`rounded-2xl border border-slate-200 bg-white shadow-sm`) matching existing views.
- **Zero states are valid states:** Zero counts render normally. No empty-state illustrations or special messaging for zero-count widgets. The dashboard is always populated with all 7 widgets.
- **Desktop-first layout:** Triage section uses a `grid-cols-2 lg:grid-cols-4` responsive grid. Summary section uses `grid-cols-3`. Collapses gracefully.
- **Navigation bar:** Simple, clean, slate-based. Links to Dashboard, Borrowers, Applications, Loans, Payments. Sign out on the right. Current section highlighted.
- **Semantic state without color alone (UX-DR16):** All triage widgets have explicit text labels ("Overdue payments", "Upcoming payments") — the tone color is supplementary, not the sole indicator.
- **WCAG 2.1 Level A (UX-DR17):** All interactive elements keyboard-accessible. Links have visible focus states. Semantic HTML (`<nav>`, `<article>`, `role="region"`).

### Library / Framework Requirements

- **Rails ~> 8.1** — standard controller, routing, view rendering.
- **`view_component`** — `ApplicationComponent` base class already available.
- **`pundit`** — `authorize :dashboard` pattern for headless policy.
- **`money-rails`** — `humanized_money_with_symbol` for currency display.
- **`factory_bot`** — existing factories for `Loan`, `Payment`, `LoanApplication`, `Invoice`, `Borrower`, `User`.
- **No new gems, no new migrations, no new initializers.**

### Previous Story Intelligence (5.6)

- **Story 5.6 explicitly deferred dashboard work to Story 6.1.** [Source: `_bmad-output/implementation-artifacts/5-6-apply-late-fees-and-close-loans-from-completed-repayment-facts.md:270`] "Dashboard, late-fee analytics, and closed-loan summary widgets are out of scope. Story 6.1 owns the dashboard."
- **All derived loan lifecycle states (overdue, closed) are already functional.** The `Loans::RefreshStatus` service handles `mark_overdue`, `resolve_overdue`, and `close` transitions. Dashboard queries simply read the current committed state.
- **Late fees are already visible on payment detail pages.** Dashboard does not need to show late-fee totals — that's a potential Story 6.2+ enhancement.
- **Read-surface hooks for state freshness are complete.** `LoansController#show`, `PaymentsController#show`, and `PaymentsController#mark_completed` all call `Loans::RefreshStatus`. When the admin drills from dashboard to a record detail, the detail view triggers freshness.

### Git Intelligence

Recent commits (last 5) and their relevance:

- `7d88ce1` **Add end-to-end repayment lifecycle system tests.** (Epic 5 system tests) — Confirms full lifecycle coverage is in place. Dashboard queries read from the same underlying data.
- `b6c7bdb` **Add test coverage for LateFeePolicy, Transition, LookupQuery, Session, and payment E2E flows.** — Query and component spec patterns to follow.
- `a09b7a7` **Apply flat late fees and close loans from completed repayment facts.** (Story 5.6) — Last business story before this one. All loan lifecycle states now exist.
- `fd223fc` **Derive overdue payment and loan states from recorded facts.** (Story 5.5) — Installed the freshness hooks the dashboard depends on.
- `3759c40` **Add payment invoice and repayment ledger posting on completion.** (Story 5.4) — Installed invoice records the dashboard aggregates for total disbursed/repayment.

**Preferred commit style:** `"Add action-first operational dashboard with triage widgets and portfolio summary."`

### Non-Goals (Explicit Scope Boundaries)

- **No drill-in behavior refinement.** Story 6.2 handles detailed drill-in with pre-applied filters and filter context preservation.
- **No cross-entity search.** Story 6.3 handles global search across borrowers, applications, loans, and payments.
- **No audit history on the dashboard.** Story 6.4 handles audit trail visibility.
- **No derived-state integrity enforcement.** Story 6.5 handles borrower snapshots and derived-state consistency.
- **No late-fee totals or analytics on the dashboard.** Detail-page surfaces from Story 5.6 are sufficient for MVP.
- **No auto-refresh, polling, WebSocket, or Turbo Stream.** Page-load freshness only (NFR8).
- **No background job for dashboard data.** Live queries sufficient for MVP.
- **No caching layer.** Simple counts/sums on indexed columns for single-admin usage.
- **No mobile or tablet layout.** Desktop-first only (UX-DR18).
- **No borrower count or document metrics.** Not in the FR57–FR63 scope.

### Project Context Reference

- No `project-context.md` found in repo. The PRD (`_bmad-output/planning-artifacts/prd.md`), architecture (`_bmad-output/planning-artifacts/architecture.md`), UX spec (`_bmad-output/planning-artifacts/ux-design-specification.md`), and Stories 5.1–5.6 are the authoritative sources.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md:880-905` — Story 6.1 BDD acceptance criteria]
- [Source: `_bmad-output/planning-artifacts/epics.md:262-263` — Epic 6 overview and FR coverage]
- [Source: `_bmad-output/planning-artifacts/prd.md:155-181` — Journey 2 (Payment Follow-Up) and Journey 4 (Dashboard Monitoring)]
- [Source: `_bmad-output/planning-artifacts/prd.md:336-337` — Dashboard as default post-login control surface]
- [Source: `_bmad-output/planning-artifacts/architecture.md:649-654` — Dashboard query objects in `app/queries/dashboard/`]
- [Source: `_bmad-output/planning-artifacts/architecture.md:563-564` — `dashboard_controller.rb` and `dashboard/triage_widget_component`]
- [Source: `_bmad-output/planning-artifacts/architecture.md:869-873` — Dashboard and operational investigation feature mapping]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md:536-543` — Dashboard Triage Widget component specification]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md:547-553` — Filter Bar component specification]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md:3-5` — UX-DR3 action-first triage surface]
- [Source: `app/queries/payments/filtered_list_query.rb` — Existing payment query patterns]
- [Source: `app/queries/loans/filtered_list_query.rb` — Existing loan query patterns]
- [Source: `app/components/shared/status_badge_component.rb` — Tone mapping pattern]
- [Source: `config/routes.rb` — Current routing structure]
- [Source: `app/views/layouts/application.html.erb` — Current layout structure]
- [Source: `app/views/home/index.html.erb` — Current workspace placeholder]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (via Cursor)

### Debug Log References

- Initial test run: `resource :dashboard` mapped to `DashboardsController` (plural). Fixed by adding `controller: "dashboard"` to the route definition.
- Component specs: `render_inline` not available. Added `spec/support/view_component.rb` to include `ViewComponent::TestHelpers` and `Capybara::RSpecMatchers` for `:component` type specs.
- Rubocop: `Layout/SpaceInsideArrayLiteralBrackets` offense in `open_applications_query.rb`. Fixed by adding spaces inside array brackets.
- Existing test regressions: 11 existing tests failed due to root route change (old workspace page → new dashboard) and nav bar introducing ambiguous links/button_to forms. Fixed all by updating assertions to match new dashboard UI.

### Completion Notes List

- Implemented 5 dashboard query objects following the established `ApplicationQuery` + `self.call` pattern. All queries are read-only counts/sums — no mutations, no state derivation.
- Created `DashboardController` with thin `show` action delegating to query objects and assigning ivars. Uses `authorize :dashboard` for Pundit consistency.
- Created `DashboardPolicy` with `show?` returning `true` for MVP single-admin model.
- Created `Dashboard::TriageWidgetComponent` with tone-driven border and text color accents (danger/warning/success/neutral), matching `Shared::StatusBadgeComponent` tone vocabulary.
- Created `Dashboard::SummaryWidgetComponent` for informational widgets (closed loans, total disbursed, total repayment) with optional drill-in links.
- Dashboard view structured with clear visual hierarchy: triage section (4 action-driving widgets) first, portfolio summary (3 informational widgets) below.
- Root route changed from `home#index` to `dashboard#show`. HomeController preserved as specified.
- Application layout updated with authenticated-only nav bar (`<nav aria-label="Main navigation">`) featuring Dashboard, Borrowers, Applications, Loans, Payments links and Sign out button. Flash messages render below nav, above main content.
- Added ViewComponent test configuration (`spec/support/view_component.rb`) for component specs.
- 40 new tests: 5 query specs (16 examples), 1 request spec (12 examples), 2 component specs (8 examples), 1 policy spec (1 example). Plus updated 8 existing specs to align with the new dashboard as workspace entry point.
- Full suite: 602 examples, 0 failures. 97.04% line coverage, 83.98% branch coverage. Rubocop clean on all touched files.

### File List

New files:
- `app/queries/dashboard/overdue_payments_query.rb`
- `app/queries/dashboard/upcoming_payments_query.rb`
- `app/queries/dashboard/open_applications_query.rb`
- `app/queries/dashboard/active_loans_query.rb`
- `app/queries/dashboard/portfolio_summary_query.rb`
- `app/controllers/dashboard_controller.rb`
- `app/policies/dashboard_policy.rb`
- `app/components/dashboard/triage_widget_component.rb`
- `app/components/dashboard/triage_widget_component.html.erb`
- `app/components/dashboard/summary_widget_component.rb`
- `app/components/dashboard/summary_widget_component.html.erb`
- `app/views/dashboard/show.html.erb`
- `spec/queries/dashboard/overdue_payments_query_spec.rb`
- `spec/queries/dashboard/upcoming_payments_query_spec.rb`
- `spec/queries/dashboard/open_applications_query_spec.rb`
- `spec/queries/dashboard/active_loans_query_spec.rb`
- `spec/queries/dashboard/portfolio_summary_query_spec.rb`
- `spec/requests/dashboard_spec.rb`
- `spec/components/dashboard/triage_widget_component_spec.rb`
- `spec/components/dashboard/summary_widget_component_spec.rb`
- `spec/policies/dashboard_policy_spec.rb`
- `spec/support/view_component.rb`

Modified files:
- `config/routes.rb` — Added `resource :dashboard` and changed `root` to `dashboard#show`
- `app/views/layouts/application.html.erb` — Added authenticated nav bar
- `spec/requests/root_shell_spec.rb` — Updated to expect dashboard
- `spec/requests/workspace_access_spec.rb` — Updated to expect dashboard
- `spec/requests/loan_applications_spec.rb` — Scoped `button_to` assertion to `main`
- `spec/system/session_flow_spec.rb` — Updated post-login expectations
- `spec/system/password_reset_flow_spec.rb` — Updated post-login expectations
- `spec/system/borrower_detail_flow_spec.rb` — Updated nav link references
- `spec/system/borrower_intake_flow_spec.rb` — Updated navigation approach
- `spec/system/borrower_search_flow_spec.rb` — Updated nav link references
- `spec/system/loan_application_workflow_spec.rb` — Updated nav link references
- `spec/system/loan_detail_flow_spec.rb` — Scoped nav link clicks to avoid ambiguity

### Review Findings

- [x] [Review][Patch] Dashboard nav link uses `root_path` instead of `dashboard_path` [app/views/layouts/application.html.erb:35] — fixed
- [x] [Review][Patch] Widget ERB templates use raw href interpolation instead of `link_to` [app/components/dashboard/*.html.erb] — fixed
- [x] [Review][Patch] `SummaryWidgetComponent` link renders with empty text when href provided but label is nil [app/components/dashboard/summary_widget_component.html.erb:4-6] — fixed
- [x] [Review][Patch] Root section of dashboard view has no `aria-label` [app/views/dashboard/show.html.erb:3] — fixed
- [x] [Review][Defer] Duplicated `self.call(...)` boilerplate across 5 query classes [app/queries/dashboard/*.rb] — deferred, pre-existing pattern across all query objects
- [x] [Review][Defer] System specs use `match: :first` to work around nav link ambiguity [spec/system/*_spec.rb] — deferred, cosmetic test concern
- [x] [Review][Defer] Nav bar logic in layout should be extracted to helper or ViewComponent [app/views/layouts/application.html.erb:30-48] — deferred, refactoring opportunity

### Change Log

- 2026-04-18: Implemented Story 6.1 — action-first operational dashboard with triage widgets, portfolio summary, authenticated nav bar, and comprehensive test suite (40 new examples). Root route now serves the dashboard.
