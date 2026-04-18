# Story 5.2: View Upcoming and Overdue Repayment Work

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want clear upcoming and overdue repayment views,
So that I can focus daily servicing work on the loans that need attention now.

## Acceptance Criteria

1. **Given** repayment records exist
   **When** the admin opens repayment-focused views
   **Then** they can see upcoming payments and overdue payments as distinct operational views
   **And** those views follow the shared filter, table, and status UX patterns

2. **Given** the admin is reviewing a loan or payment
   **When** the relevant detail pages load
   **Then** the current repayment state is shown clearly
   **And** the admin can understand whether the item is upcoming, completed, overdue, or otherwise action-relevant

3. **Given** the admin needs to work across many payments
   **When** they browse the payments list
   **Then** they can filter or browse payments by repayment state and operational need
   **And** the list supports efficient operational scanning

## Tasks / Subtasks

- [x] Task 1: Add payments routes and controller skeleton (AC: #1, #2, #3)
  - [x] 1.1 Add `resources :payments, only: %i[index show]` to `config/routes.rb` with the same UUID constraint used by `loans` and `loan_applications`
  - [x] 1.2 Create `app/controllers/payments_controller.rb` with `index` and `show` actions; inherit `ApplicationController` so the existing `Authentication` concern guards access (match the gating behaviour in `LoansController` / `LoanApplicationsController`)
  - [x] 1.3 In `index`, populate `@search_query`, `@status_filter`, `@view_filter`, `@due_window_filter`, and `@payments` from the new query (see Task 2); set `@has_payments = Payment.exists?`
  - [x] 1.4 In `show`, load the payment with `Payment.includes(loan: :borrower).find(params[:id])`; do NOT add any write action (completion is Story 5.3)
  - [x] 1.5 Keep the controller thin: no calculations, no AASM calls — delegate all filtering to `Payments::FilteredListQuery`

- [x] Task 2: Create `Payments::FilteredListQuery` (AC: #1, #3)
  - [x] 2.1 Create `app/queries/payments/filtered_list_query.rb` extending `ApplicationQuery`, mirroring the keyword signature and private helpers of `Loans::FilteredListQuery`
  - [x] 2.2 Accept `scope: Payment.all`, `status:`, `search:`, `view:`, `due_window:` keywords
  - [x] 2.3 Whitelist `status` against `Payment.aasm.states.map { |state| state.name.to_s }` (pending, completed, overdue); reject anything else to `nil`
  - [x] 2.4 Whitelist `view` to one of `%w[upcoming overdue completed]` (operational view labels); treat any other value as `nil` so the default is "all"
  - [x] 2.5 Whitelist `due_window` to one of `%w[today this_week next_7_days this_month]`; map each to a deterministic `due_date` range anchored on `Date.current` (apply only when `status == "pending"` or `view == "upcoming"`; otherwise ignore so overdue/completed views do not get double-filtered)
  - [x] 2.6 Ordered scope: `scope.includes(loan: :borrower).order(:due_date, :installment_number, :created_at, :id)` — upcoming surface earliest-first; match index order (by `due_date`) for fast scans
  - [x] 2.7 Search: match `loans.loan_number ILIKE :query OR borrowers.full_name ILIKE :query` using `Payment.sanitize_sql_like`; join `:loan` and through the loan to `:borrower`
  - [x] 2.8 When `view` is present, translate to a canonical status filter: `upcoming → status = pending`, `overdue → status = overdue`, `completed → status = completed`. If both `view` and explicit `status` arrive, prefer the explicit `status` (view is a convenience alias)
  - [x] 2.9 Return an `ActiveRecord::Relation` so the controller can size/count it consistently with existing list queries

- [x] Task 3: Build payments index view (AC: #1, #3)
  - [x] 3.1 Create `app/views/payments/index.html.erb`. Reuse the exact outer layout pattern used by `app/views/loans/index.html.erb` (breadcrumb nav, rounded-3xl workspace card, filter bar, table, empty states)
  - [x] 3.2 Breadcrumb: Workspace › Payments (add Payments to the workspace header in Task 7)
  - [x] 3.3 Filter bar content:
    - Search field: "Search by loan number or borrower name" (`search_field_tag :q`)
    - Quick-view chips: `All`, `Upcoming`, `Overdue`, `Completed` linking to `payments_path(view:)` — selected chip highlighted via the established ring pattern used in `loans/index.html.erb`
    - Status chip row (secondary, under the view chips): `Pending`, `Completed`, `Overdue` rendered through `Shared::StatusBadgeComponent` with the tone map below; selected status keeps the same ring highlight used on the loans list
    - Due-window secondary filter (select or link group): `All`, `Overdue by any`, `Due today`, `Due this week`, `Due next 7 days`, `Due this month`. Map values to the `due_window` query param; only surface this control when `view == "upcoming"` or `status == "pending"` so it never contradicts the overdue/completed lists
    - Reset link: "Clear filters" → `payments_path`
  - [x] 3.4 Results table columns (left-to-right): `Payment` (loan number + installment number like "LOAN-0123 · #3"), `Borrower`, `Due date` (with a muted "Overdue by N days" / "Due in N days" helper line derived at view time from `payment.due_date` vs `Date.current` — presentation only, no persisted state change), `Principal`, `Interest`, `Total`, `Status` (render `Shared::StatusBadgeComponent.new(label: payment.status_label, tone: payment.status_tone)`), `Open` link to `payment_path(payment, from: "payments")`
  - [x] 3.5 Result summary line: pluralize `@payments.size` "payment"; indicate "match the current search and status filters" when any filter is active (match copy style of loans index)
  - [x] 3.6 Empty states (match the loans index triad):
    - No repayment records at all: neutral empty card — "No repayment records yet" with copy explaining payments are generated when a loan is disbursed
    - Records exist but filters match nothing: amber "Filtered results" card with "Clear filters" CTA
    - Records exist and matches found: render the table
  - [x] 3.7 Use `humanized_money_with_symbol(payment.principal_amount|interest_amount|total_amount)` for money — follow Story 5.1 precedent

- [x] Task 4: Build payment show view (AC: #2)
  - [x] 4.1 Create `app/views/payments/show.html.erb`. Do NOT add any completion action, form, or button — Story 5.3 owns `mark_completed`
  - [x] 4.2 Breadcrumb: Workspace › Payments › <loan_number> · #<installment_number>. When `params[:from] == "loans"`, insert a Loan breadcrumb link to `loan_path(@payment.loan, from: "loans")` — mirror how `loans/show.html.erb` handles the `from` parameter
  - [x] 4.3 Hero card: installment title, status badge (`Shared::StatusBadgeComponent` with `payment.status_label` + `payment.status_tone`), due-date banner with derived "Overdue by N days" / "Due in N days" / "Due today" helper (view-only)
  - [x] 4.4 Details `<dl>` grid: Loan (link to `loan_path(@payment.loan)`), Borrower (link to `borrower_path(@payment.loan.borrower)`), Installment number, Due date, Principal (money), Interest (money), Total (money), Late fee (money, show "—" when zero), Repayment frequency (from loan), Current repayment state (status label + derived helper), Payment date (show "Not recorded yet" when nil), Payment mode (show "Not recorded yet" when nil), Completed at (show "—" when nil), Notes (show "Not provided yet" when nil)
  - [x] 4.5 Consequence callout card explaining that payment completion is performed on the payment detail page in a future story (informational only — no action button). Copy should read calmly, e.g. "Recording a completed payment is guarded by its own confirmation flow introduced in a later step." This keeps the detail page useful today without promising 5.3 behaviour
  - [x] 4.6 Accessibility: breadcrumb `aria-label="Breadcrumb"`, status badge included inside headings where appropriate, no form elements

- [x] Task 5: Enhance loan detail repayment section with current state summary (AC: #2)
  - [x] 5.1 In `app/views/loans/show.html.erb`, inside the existing `has_repayment_schedule` section (added by Story 5.1), add a small summary `<dl>` above the existing installments table showing: `Next payment due` (earliest pending installment's due date + "Overdue by N days" / "Due in N days" helper), `Completed installments` (count), `Pending installments` (count), `Overdue installments` (count from persisted status)
  - [x] 5.2 Derive counts with `payments.count(&:completed?)` / `pending?` / `overdue?` on the already-loaded ordered collection — do NOT add new queries (payments are already preloaded by `set_loan`)
  - [x] 5.3 In each installments-table row, add a right-aligned link "Open payment" → `payment_path(payment, from: "loans")` so admins can drill into the payment detail from the loan workspace
  - [x] 5.4 Do NOT change the existing summary card (installments / frequency / first due / last due / total scheduled) — this story adds a new sibling summary, not a rewrite

- [x] Task 6: Presentation helper for derived due-date messaging (AC: #1, #2)
  - [x] 6.1 Add a small view helper (e.g. `PaymentsHelper#payment_due_hint(payment, today: Date.current)`) under `app/helpers/payments_helper.rb` returning one of: "Due today", "Due in N days", "Overdue by N days", "Completed on <date>". This is **presentation only** — do NOT persist, do NOT transition AASM state (overdue derivation lives in Story 5.5)
  - [x] 6.2 Use the helper in both `payments/index.html.erb`, `payments/show.html.erb`, and inside the loan show "Next payment due" summary so phrasing stays consistent
  - [x] 6.3 Keep `completed?` branch short — when completed and `payment_date` is nil (which is only possible before Story 5.3), fall back to "Completed"

- [x] Task 7: Cross-link navigation (AC: #1, #3)
  - [x] 7.1 Add a `Payments` link to the workspace header action group in `app/views/home/index.html.erb` (between `Loans` and `Browse borrowers`) using the same `rounded-xl border border-slate-300 ...` styling as siblings
  - [x] 7.2 Update the workspace overview copy ("Available surfaces") to include payments so the home page stays honest about what ships

- [x] Task 8: Tests (AC: #1, #2, #3)
  - [x] 8.1 `spec/queries/payments/filtered_list_query_spec.rb`: ordering (earliest `due_date` first), eager loading of `loan` and `loan.borrower`, filtering by canonical `status` (pending/completed/overdue), filtering by view alias (`upcoming`, `overdue`, `completed`), due-window filter boundaries (today / this_week / next_7_days / this_month), search by loan number, search by borrower name, combined filters, invalid status/view/due_window returns unfiltered behaviour
  - [x] 8.2 `spec/requests/payments_spec.rb`: unauthenticated visitor redirected from `/payments` and `/payments/:id`; authenticated admin sees empty state when no payments; authenticated admin sees filtered results when filters applied; empty filtered state renders the "Clear filters" CTA; show page renders with loan/borrower context and without any completion button
  - [x] 8.3 `spec/requests/loans_spec.rb` (extend existing file): verify the loan show page now renders `Next payment due`, `Completed installments`, `Pending installments`, `Overdue installments` labels when a repayment schedule exists; verify the `Open payment` link points to `payment_path(payment, from: "loans")`
  - [x] 8.4 `spec/helpers/payments_helper_spec.rb` (new): deterministic scenarios for `payment_due_hint` covering today, future, past, and completed states (use `Date.new(2026, 5, 1)` style anchors, never `Date.current` inside expectations)
  - [x] 8.5 Run `bundle exec rspec` green; run `bundle exec rubocop` green before marking story done

### Review Findings

- [x] [Review][Patch] Add `Overdue by any` due-window chip — Extended `Payments::FilteredListQuery::DUE_WINDOWS` with `overdue_by_any`, mapped to `...Date.current` (strictly before today), added an `apply_due_window?` predicate that applies the chip regardless of status for this value while keeping pending-only gating for the other four, whitelisted it in `PaymentsController#normalized_due_window_filter`, added the chip to `app/views/payments/index.html.erb` and widened `show_due_window_filter` to all non-completed contexts. Added `applies due_window=overdue_by_any regardless of status` query spec.
- [x] [Review][Patch] Payment show `<dl>` — added `Due date` row after `Installment number` and moved `Repayment frequency` to after `Late fee` so the grid now follows Task 4.4 order exactly. [app/views/payments/show.html.erb:58-101]
- [x] [Review][Patch] `status_tones.fetch(status)` now falls back to `:neutral` if a future AASM state is ever added. [app/views/payments/index.html.erb:100]
- [x] [Review][Patch] Added `excludes a date-overdue pending payment from view=overdue and status=overdue (persisted status wins over date)` to `spec/queries/payments/filtered_list_query_spec.rb`, plus `overdue_by_any` coverage above.
- [x] [Review][Patch] Added `renders a constrained list when view=upcoming is applied and matching payments exist` to `spec/requests/payments_spec.rb` to cover the Task 8.2 "filtered results" scenario.
- [x] [Review][Defer] Payments index has no pagination — unbounded list with potential memory/response impact at scale. Deferred — matches the pre-existing loans/applications index pattern; would need to pair with a project-wide pagination story.

## Dev Notes

### Epic 5 Cross-Story Context

- **Epic 5** covers repayment servicing, overdue control, and loan closure (FR40–FR56, FR72).
- **Story 5.1 (done)** created `Payment` model + `Loans::GenerateRepaymentSchedule` + loan-show schedule section.
- **This story (5.2)** adds the operational **list** and **detail** surfaces for payments and upgrades the loan workspace with a current-repayment-state summary.
- **5.3** will add `Payments::MarkCompleted` guarded completion (payment detail gains a confirmation-guarded form).
- **5.4** will add payment invoices + `double_entry` payment postings.
- **5.5** will derive overdue payment and loan states from facts (flips AASM to `overdue`).
- **5.6** will apply late fees and auto-close loans.
- **Do NOT** implement completion, overdue derivation, invoicing, late fees, or closure logic in this story.

### Critical Architecture Constraints

- **Domain language is canonical.** The Payment AASM states are `pending`, `completed`, `overdue`. The UI MUST render these labels via `payment.status_label` ("Pending", "Completed", "Overdue"). Use the word "upcoming" as a **view label** (filter chip and page copy) that maps to `status = pending`; never replace "Pending" in the badge with "Upcoming". [Source: architecture.md — Anti-Patterns: "Using different status strings in UI than in domain enums"]
- **Reads go through queries.** Any non-trivial list query lives under `app/queries/*` and is called from the controller. Controllers must not assemble scopes. [Source: architecture.md — Structure Patterns]
- **Namespace mirrors directory.** New files: `app/queries/payments/filtered_list_query.rb`, `app/controllers/payments_controller.rb`, `app/views/payments/`. [Source: architecture.md — File Structure Patterns]
- **No workflow logic in helpers/components.** The due-date "Overdue by N days" helper is presentational only; it MUST NOT call `mark_overdue!`, MUST NOT persist, and MUST NOT be used to gate future actions. Overdue derivation is Story 5.5's responsibility. [Source: architecture.md — State Management Patterns; Anti-Patterns: "Reimplementing overdue logic inside a job or component"]
- **Shared UX primitives.** Status badges go through `Shared::StatusBadgeComponent` using `payment.status_tone` (`:neutral` for pending, `:success` for completed, `:warning` for overdue — already defined on the Payment model). Filter bars follow the loans/applications index pattern. [Source: ux-design-specification.md — Filter Bar / Data Table Wrapper / Lifecycle Status Badge]
- **Authentication gating.** All payment routes are admin-protected through the existing `Authentication` concern on `ApplicationController`. Do not override or relax it. [Source: `app/controllers/concerns/authentication.rb`]
- **No hard delete.** Payments are never destroyed. [Source: prd.md — FR70]
- **Paper trail.** Read-only views do not create paper_trail entries; no `PaperTrail.whodunnit` plumbing is needed for this story. [Source: existing services]
- **Money formatting.** Use `humanized_money_with_symbol` on all money columns, matching Story 5.1 and the invoice pattern. [Source: Gemfile — `money-rails ~> 3.0`; `app/views/loans/show.html.erb`]

### File Structure (Expected Touchpoints)

| Area | Files |
|------|--------|
| New | `app/controllers/payments_controller.rb` |
| New | `app/queries/payments/filtered_list_query.rb` |
| New | `app/views/payments/index.html.erb` |
| New | `app/views/payments/show.html.erb` |
| New | `app/helpers/payments_helper.rb` |
| New | `spec/queries/payments/filtered_list_query_spec.rb` |
| New | `spec/requests/payments_spec.rb` |
| New | `spec/helpers/payments_helper_spec.rb` |
| Modify | `config/routes.rb` — add `resources :payments, only: %i[index show]` with UUID constraint |
| Modify | `app/views/loans/show.html.erb` — add repayment-state summary + "Open payment" row action inside existing schedule section |
| Modify | `app/views/home/index.html.erb` — add "Payments" link to workspace header action group |
| Modify | `spec/requests/loans_spec.rb` — extend show-page expectations for the new summary + drill link |

### Files NOT to Create or Modify

- Do NOT create `app/services/payments/mark_completed.rb` — Story 5.3.
- Do NOT add a "Mark payment completed" button, form, or route — Story 5.3.
- Do NOT modify `app/models/payment.rb` state machine or add `mark_overdue` callers — Story 5.5.
- Do NOT create `app/jobs/overdue_recalculation_job.rb` — Story 5.5.
- Do NOT extend `Invoice::INVOICE_TYPES` or create payment invoices — Story 5.4.
- Do NOT add dashboard widgets or drill-in routes — Epic 6.
- Do NOT modify `config/initializers/double_entry.rb` — no money movement in this story.
- Do NOT add a Payment policy class — Pundit hasn't been introduced yet; continue using the shared authentication gate like other controllers.
- Do NOT rename the persisted `pending` state to `upcoming`; keep domain vocabulary intact.

### Existing Patterns to Follow

1. **Filtered list query pattern** — mirror `app/queries/loans/filtered_list_query.rb` and `app/queries/loan_applications/filtered_list_query.rb` exactly:
   ```ruby
   module Payments
     class FilteredListQuery < ApplicationQuery
       def self.call(...) = new(...).call

       def initialize(scope: Payment.all, status: nil, search: nil, view: nil, due_window: nil)
         @scope = scope
         @status = normalized_status(status) || view_to_status(view)
         @search = search.to_s.squish
         @due_window = normalized_due_window(due_window)
       end
       # ...
     end
   end
   ```

2. **Controller shape** — match `LoansController#index`:
   ```ruby
   def index
     @search_query = params[:q].to_s.squish
     @status_filter = normalized_status_filter
     @view_filter = normalized_view_filter
     @due_window_filter = normalized_due_window_filter
     @payments = Payments::FilteredListQuery.call(
       status: @status_filter,
       search: @search_query,
       view: @view_filter,
       due_window: @due_window_filter
     )
     @has_payments = Payment.exists?
   end
   ```

3. **View layout** — match `app/views/loans/index.html.erb` exactly for container (`mx-auto flex w-full max-w-6xl`), breadcrumb, hero card, filter bar (`rounded-2xl border border-slate-200 bg-slate-50 p-5`), and table styling (`min-w-full divide-y divide-slate-200`, `bg-slate-50` header, `px-5 py-4` cells).

4. **Empty state triad** — match loans index: neutral dashed card for true empty, amber card for filtered-empty, "Clear filters" CTA link.

5. **From parameter** — reuse the `from:` query-string pattern (used by `loans`, `loan_applications`) so breadcrumbs in the payment show page can point back to payments list or to the originating loan.

6. **Money display** — `humanized_money_with_symbol(payment.principal_amount)` etc. Use `Money.new(loan.total_scheduled_amount, "INR")` if you need a sum of cents — already established in 5.1.

7. **Eager loading** — in `Payments::FilteredListQuery#ordered_scope`, `includes(loan: :borrower)` prevents N+1 in the list. In `PaymentsController#show`, `Payment.includes(loan: :borrower)` is sufficient (no document/invoice loading needed for this story).

8. **Ordering** — payments index orders by `:due_date` ascending (earliest-first is the operational need for upcoming/overdue triage). The existing loan show table uses `Payment.ordered` (installment-number ascending) — do NOT change that scope; this story just reads from it.

### Canonical State / View Mapping

| View chip (URL param `view`) | Canonical `status` filter | Notes |
|------------------------------|----------------------------|-------|
| `upcoming` | `pending` | Shows all pending installments; due-window secondary filter enabled |
| `overdue` | `overdue` | In Story 5.2, this list is typically empty because AASM overdue is only set by Story 5.5's derivation. This is expected. UI copy in the empty state should clarify "No payments are currently marked overdue." |
| `completed` | `completed` | In Story 5.2, this list is typically empty because completion is Story 5.3. Same treatment — neutral empty state with honest copy. |
| *(absent)* | *(none — show all)* | Default |

**Status chip row** (secondary filters, underneath the view chips) uses raw canonical status values: `pending`, `completed`, `overdue`. When both `view` and explicit `status` are present, `status` wins (the query should short-circuit view→status translation in that case).

### Due-Window Filter Ranges

Anchor all ranges on `Date.current` at query-evaluation time so output is reproducible:

| Value | Range on `payments.due_date` |
|-------|------------------------------|
| `today` | `..Date.current` intersected with `Date.current..` → equality on `Date.current` |
| `this_week` | `Date.current.beginning_of_week..Date.current.end_of_week` (Rails default: Monday–Sunday) |
| `next_7_days` | `Date.current..(Date.current + 7.days)` |
| `this_month` | `Date.current.beginning_of_month..Date.current.end_of_month` |

Apply this filter only when the effective status filter is `pending` (i.e. view `upcoming` or explicit `status=pending`). For `overdue` / `completed` lists, ignore `due_window` to avoid confusing double-filtering.

### Derived Due-Date Hint (Presentation Only)

```ruby
module PaymentsHelper
  def payment_due_hint(payment, today: Date.current)
    return "Completed on #{l(payment.payment_date, format: :long)}" if payment.completed? && payment.payment_date
    return "Completed" if payment.completed?

    diff = (payment.due_date - today).to_i
    if diff.positive?
      "Due in #{pluralize(diff, 'day')}"
    elsif diff.zero?
      "Due today"
    else
      "Overdue by #{pluralize(diff.abs, 'day')}"
    end
  end
end
```

This is **read-only presentation**. It MUST NOT trigger any AASM transition. It MUST NOT be used to decide whether an action is allowed. Story 5.5 owns the canonical overdue derivation; the hint here is purely to help the admin orient on the screen.

### Loan Show — Current Repayment State Summary

Add immediately above the existing installments table inside the `has_repayment_schedule` section:

```erb
<dl class="mt-6 grid gap-5 rounded-2xl border border-slate-200 bg-white p-6 sm:grid-cols-2 lg:grid-cols-4">
  <div>
    <dt class="text-sm font-medium text-slate-500">Next payment due</dt>
    <dd class="mt-2 text-lg font-semibold text-slate-950">
      <%= next_pending = payments.find(&:pending?)
          next_pending ? "#{next_pending.due_date.to_fs(:long)} — #{payment_due_hint(next_pending)}" : "—" %>
    </dd>
  </div>
  <div>
    <dt class="text-sm font-medium text-slate-500">Completed installments</dt>
    <dd class="mt-2 text-lg font-semibold text-slate-950"><%= payments.count(&:completed?) %></dd>
  </div>
  <div>
    <dt class="text-sm font-medium text-slate-500">Pending installments</dt>
    <dd class="mt-2 text-lg font-semibold text-slate-950"><%= payments.count(&:pending?) %></dd>
  </div>
  <div>
    <dt class="text-sm font-medium text-slate-500">Overdue installments</dt>
    <dd class="mt-2 text-lg font-semibold text-slate-950"><%= payments.count(&:overdue?) %></dd>
  </div>
</dl>
```

Counts use in-memory iteration because `@payments = @loan.payments.ordered` is already loaded in `LoansController#show`. Do not add `.where(status: ...).count` calls that would re-query.

### UX Requirements

- **Shared patterns over novelty.** Payments list uses the same filter/table grammar as loans and applications — consistent operational scanning is more valuable than a bespoke layout. [Source: ux-design-specification.md — "repeatable table behavior... first-class system pattern"]
- **Filter clarity.** The active view (upcoming/overdue/completed/all) must be visually obvious via the selected chip state. Due-window and status chips stack below the primary view chips so the admin can read the list scope left-to-right. [Source: ux-design-specification.md — Filter Bar]
- **Empty states guide, not decorate.** Distinguish "no payments in the system yet" from "no payments match the current filter". Both cases ship in this story. [Source: ux-design-specification.md — Empty states]
- **Status badges are informational.** Badge tones already defined on the Payment model: pending → neutral, completed → success, overdue → warning. Do not invent a danger tone for overdue on the list; `warning` is the canonical tone (overdue is attention-worthy, not erroneous). [Source: `app/models/payment.rb#status_tone`]
- **Detail page is read-only in this story.** Wireframe 12 describes a verification-first completion page — that completion affordance ships in Story 5.3. The 5.2 detail page renders the informational scaffold (header, verification data, consequence summary copy) without the action button. [Source: `_bmad-output/planning-artifacts/ux-wireframes-pages/12-12-payment-detail-completion.html`]
- **Breadcrumbs communicate the investigative path.** If the admin drilled in from the payments list, the breadcrumb shows Payments. If they drilled in from a loan via the "Open payment" row action, the breadcrumb shows the Loan. Implement via the same `params[:from]` pattern used on the loan detail page. [Source: `app/views/loans/show.html.erb`]

### Library / Framework Requirements

- **Rails ~> 8.1** — routing, Active Record eager loading, form_with, search_field_tag
- **AASM ~> 5.5** — read `payment.aasm.current_state` / `payment.status_label` / `payment.status_tone` (no transitions in this story)
- **money-rails ~> 3.0** — `humanized_money_with_symbol` in both index and show views
- **paper_trail ~> 17.0** — no changes; reads are not audited
- **ViewComponent ~> 4.0** — `Shared::StatusBadgeComponent` is the only component used
- **FactoryBot ~> 6.5** — existing `:payment` factory (with `:pending`, `:completed`, `:overdue` traits) is sufficient; you MAY add a `:due_today` / `:due_in_future` / `:due_in_past` trait on top if it simplifies filter tests

### Previous Story Intelligence (5.1)

- **`Payment.ordered` scope** orders by `(installment_number, due_date, created_at)` — keep using it inside the loan show table. The new payments index, however, orders by `due_date` ASC for operational triage (earliest-due first); do this in `Payments::FilteredListQuery`, not as a new model scope, so the semantic stays "list view ordering" rather than a canonical record order. [Source: `app/models/payment.rb:28`]
- **`@payments` is preloaded** in `LoansController#show` (`set_loan` includes `:payments`). New loan-show summary counts should iterate this collection in memory — do NOT add `@loan.payments.where(...)` calls in the view. [Source: `app/controllers/loans_controller.rb:82`]
- **Idempotency of schedule generation** is already guarded by `Loans::GenerateRepaymentSchedule`; this story is pure read-side and does not touch that code path. [Source: `app/services/loans/generate_repayment_schedule.rb`]
- **Status label formatting.** `Payment#status_label` calls `status.to_s.humanize`, giving "Pending" / "Completed" / "Overdue". Reuse this as-is; don't add ad-hoc humanize calls in views. [Source: `app/models/payment.rb:49`]
- **Status tone mapping** (completed → success, overdue → warning, pending → neutral) is authoritative and already tested in `spec/models/payment_spec.rb`. Do not duplicate this mapping in views/helpers. [Source: `app/models/payment.rb:52-61`]
- **Review patches in 5.1** fixed rounding, negative-interest guarding, zero-value validation, and concurrent-schedule idempotency in the schedule service. Those are orthogonal to 5.2's read-side work but confirm that the schedule inputs your list reads are now robust. [Source: Story 5.1 Review Findings]

### Git Intelligence

Recent commits (last 5) and their relevance:

- `af4a085` **Add repayment schedule generation from loan disbursement.** — Directly upstream; installed the `Payment` model + schedule generation that this story reads from.
- `59e7827` Complete Epic 4 retrospective — planning only, no code.
- `af1d56d` Add guarded disbursement financial records and invoice handling — introduced the `DoubleEntry.lock_accounts` pattern that Story 5.4 will extend; 5.2 does not touch it.
- `d3fb90f` Add disbursement readiness evaluation before disbursement — shows the "readiness as a first-class domain concept" pattern; 5.2 mirrors it spiritually with a filtered-list pattern rather than a readiness object.
- `15d78cb` Add loan documentation management before disbursement — established the multi-section loan show page that 5.2 extends.

**Preferred commit style:** `"Add payment list, detail, and loan repayment-state visibility."`

### Epic 4 Retrospective Insights (Apply to This Story)

1. **"Keep loan work on shared list/detail/detail-workspace patterns"** — Action item from Epic 4. The payments list and detail MUST reuse the filter-bar / table / breadcrumb grammar established by loans and applications. [Source: Epic 4 Retro — Action items]
2. **"Canonical statuses and state transitions come from the domain layer"** — Do not invent an "upcoming" state on Payment; it is a view label only. [Source: Epic 4 Retro — Key insights; architecture.md — Anti-Patterns]
3. **"One vertical spine beats many mini-features"** — The loan detail page already carries schedule visibility; 5.2 adds a repayment-state summary on that same spine rather than creating a separate "repayment workspace" page. [Source: Epic 4 Retro — Key insights]
4. **"Facts not toggles"** — The overdue filter still reads a persisted fact (`status = "overdue"`); the derived "Overdue by N days" label is presentation-only sugar, not a parallel state system. [Source: Epic 4 Retro — Significant discoveries]
5. **"Test discipline"** — Run full `bundle exec rspec` before marking done; expected total examples should grow by roughly 15–25 (two new specs, two new request specs, minor additions to loans request spec). [Source: Epic 4 Retro]

### Calculation and Date-Range Edge Cases to Test

1. **Due today boundary.** Payment with `due_date = Date.current` must appear in `due_window=today`, `this_week`, `next_7_days`, and `this_month`.
2. **Overdue boundary.** Payment with `due_date = Date.current - 1.day` and `status = "pending"` does NOT appear in overdue-filter results (filter reads `status`, not date). The presentation helper still renders "Overdue by 1 day". This is by design — 5.5 will flip the persisted status.
3. **Week boundary.** `due_window=this_week` with `Date.current` on a Sunday — confirm the Monday–Sunday window uses Rails' default `beginning_of_week` (Monday).
4. **Search case insensitivity.** "ASHA" and "asha" both match "Asha Patel".
5. **Search by loan number substring.** "0123" matches "LOAN-0123" via `ILIKE '%0123%'`.
6. **Ordering tie-break.** Two payments same `due_date` different `installment_number` — installment ascending determines order (secondary sort in query).
7. **Combined filters.** `view=upcoming`, `due_window=this_week`, `q=asha` — all three applied together; result restricted to pending installments due this week belonging to loans of borrowers named "Asha".
8. **Empty filtered result.** Payments exist but no overdue ones — list renders the amber "Clear filters" empty card, not the neutral "No repayment records yet" card.
9. **No payments in system.** No loans disbursed yet — list renders the neutral empty card guiding to disburse a loan.
10. **Unauthenticated access.** Both `/payments` and `/payments/:id` redirect to sign-in (mirror `loans_spec.rb` auth tests).

### `double_entry` Notes (for Awareness, Not Action)

- Currently configured accounts: `loan_receivable` (positive-only, loan-scoped), `disbursement_clearing` (loan-scoped).
- Story 5.4 will add a payment-related clearing account + `repayment_received → loan_receivable` transfer.
- **This story does NOT post, read, or touch `DoubleEntry`.** Payments index/show render schedule facts, not ledger balances.

### Project Context Reference

- No `project-context.md` found in repo. This story, the PRD, architecture, UX specification, and Story 5.1 are the authoritative sources.

## Dev Agent Record

### Agent Model Used

Cursor AI (Opus 4.7)

### Debug Log References

- `bundle exec rspec` → 387 examples, 0 failures (full suite, 14.7s).
- `bundle exec rspec spec/queries/payments/filtered_list_query_spec.rb spec/helpers/payments_helper_spec.rb spec/requests/payments_spec.rb` → 31 examples, 0 failures (focused run).
- `bundle exec rubocop` on all touched Ruby/ERB-as-Ruby files → clean. (Existing unrelated `Layout/SpaceInsideArrayLiteralBrackets` offenses in `Gemfile`, `spec/models/invoice_spec.rb`, `spec/models/user_spec.rb` pre-date this story and were not touched.)

### Implementation Plan

1. **Routes + thin controller** (`PaymentsController#index/#show`) delegating all filtering to the new query. Status, view, and due_window are whitelisted in the controller and again in the query to keep the query safe when called from other contexts.
2. **`Payments::FilteredListQuery`** mirrors the keyword shape of `Loans::FilteredListQuery`, adds a view→status alias table and due-window date range mapping. Due window only applies when the effective status is `pending` to avoid double-filtering the overdue/completed lists.
3. **Index view** reuses the loans-index grammar (breadcrumb, hero, filter bar, table, triad of empty states). Primary "view" chips stack above secondary status chips, and the due-window chip row is only rendered when the effective filter is `upcoming` / `pending`.
4. **Show view** is read-only: hero + status badge + due-date banner (presentation helper) + full details grid + calm copy explaining that completion arrives in a later step. No form, no button, no `mark_completed` path.
5. **Loan show repayment summary** adds a second `<dl>` sibling card (next payment due + counts) above the existing installments table and an "Open payment" drill link per row. Counts are derived in memory from the already-preloaded collection — no new queries.
6. **`PaymentsHelper#payment_due_hint`** returns "Due today" / "Due in N days" / "Overdue by N days" / "Completed on <date>" / "Completed" — pure presentation, no AASM transitions, used in three call sites.
7. **Workspace header** adds a Payments link between Loans and Browse borrowers, and the overview copy is updated to mention payments.
8. **Tests**: new query spec uses `ActiveSupport::Testing::TimeHelpers` + deterministic anchor date to exercise boundary-based due-window logic; new helper spec; new request spec mirroring the existing loans/borrowers auth + empty/filtered patterns; existing loans request spec extended for the new summary + drill link.

### Completion Notes List

- All three acceptance criteria are satisfied by the new payments list and show screens, the loan show repayment-state summary, and the helper-driven due-date hints.
- Canonical domain vocabulary is preserved: the word "Upcoming" only appears as a view label; status badges always render `payment.status_label` ("Pending" / "Completed" / "Overdue") with the Payment model's tone mapping.
- No persisted state is changed by this story (no AASM transitions, no writes, no new migrations). Overdue derivation remains the responsibility of Story 5.5.
- The `Payments::FilteredListQuery` short-circuits view→status translation when an explicit `status` param is present, so status wins over view as specified.
- The due-window filter is intentionally inert on overdue/completed lists; invalid values are coerced to `nil` so the query stays an `ActiveRecord::Relation` at all call sites.
- Controller does not expose any write route; `/payments/:id` only renders read-only content and there is no `mark_completed` path in this story.

### File List

- New: `app/controllers/payments_controller.rb`
- New: `app/queries/payments/filtered_list_query.rb`
- New: `app/views/payments/index.html.erb`
- New: `app/views/payments/show.html.erb`
- New: `app/helpers/payments_helper.rb`
- New: `spec/queries/payments/filtered_list_query_spec.rb`
- New: `spec/requests/payments_spec.rb`
- New: `spec/helpers/payments_helper_spec.rb`
- Modified: `config/routes.rb`
- Modified: `app/views/loans/show.html.erb`
- Modified: `app/views/home/index.html.erb`
- Modified: `spec/requests/loans_spec.rb`

## Change Log

- 2026-04-18: Created story for payment list/detail visibility and loan-level repayment-state summary.
- 2026-04-18: Implemented payments list/detail surfaces, `Payments::FilteredListQuery` with view/status/due-window filters, `PaymentsHelper#payment_due_hint`, loan-show repayment-state summary with "Open payment" drill links, and workspace navigation entry. Added query, request, helper specs and extended loans request spec. `bundle exec rspec` (387 examples) and `bundle exec rubocop` on touched files green.
- 2026-04-18: Code review applied five patches — `Overdue by any` due-window chip (query + controller + view), payment show `<dl>` adds `Due date` row and reorders per Task 4.4, defensive `status_tones.fetch(:neutral)`, overdue-boundary + `overdue_by_any` query specs, and a non-empty filtered-result request spec. `bundle exec rspec` (390 examples, 0 failures) and `bundle exec rubocop` on touched Ruby files green.
