# Story 4.2: Prepare and Review Loan Details Before Disbursement

Status: done

## Story

As an admin operator,
I want to prepare and review loan details before money is released,
So that the loan is complete and accurate before entering the money-sensitive stage.

## Acceptance Criteria

1. **Given** a pre-disbursement loan exists
   **When** the admin opens the loan detail and edit flow
   **Then** they can prepare and finalize the loan details allowed before disbursement
   **And** the interface clearly distinguishes editable pre-money information from later locked states

2. **Given** the admin is working across multiple loans
   **When** they open the loan list
   **Then** they can browse loans by lifecycle state and operational need
   **And** the loan list follows the shared table, filter, and status UX patterns

3. **Given** the admin is reviewing a specific loan
   **When** the detail page loads
   **Then** it shows the current lifecycle state clearly
   **And** the next valid action is visible without ambiguity

## Tasks / Subtasks

- [x] Task 1: Add loan financial columns via migration (AC: #1)
  - [x] 1.1 Create migration to add `principal_amount_cents` (bigint), `tenure_in_months` (integer), `repayment_frequency` (string), `interest_mode` (string), `interest_rate` (decimal, precision 8 scale 4), `total_interest_amount_cents` (bigint), `disbursement_date` (date, nullable), and `notes` (text) to `loans`
  - [x] 1.2 Add indexes on `repayment_frequency` and `interest_mode` for filtering
  - [x] 1.3 Run migration in both development and test environments; verify `db/schema.rb` is updated
- [x] Task 2: Extend Loan model with financial validations and display helpers (AC: #1, #3)
  - [x] 2.1 Add `monetize :principal_amount_cents, allow_nil: true` and `monetize :total_interest_amount_cents, allow_nil: true`
  - [x] 2.2 Add constants: `REPAYMENT_FREQUENCIES = ["weekly", "bi-weekly", "monthly"].freeze` and `INTEREST_MODES = ["rate", "total_interest_amount"].freeze`
  - [x] 2.3 Add normalizers for `repayment_frequency`, `interest_mode`, and `notes` (same squish/presence/downcase pattern as existing model fields)
  - [x] 2.4 Add conditional validations on a `:details_update` context (matching `LoanApplication` pattern): principal_amount > 0, tenure_in_months > 0 integer, repayment_frequency inclusion, interest_mode inclusion
  - [x] 2.5 Add mutual-exclusivity validation: if `interest_mode == "rate"` then `interest_rate` must be present and `total_interest_amount` must be nil, and vice versa — enforce on `:details_update` context
  - [x] 2.6 Add `#editable_details?` → true when loan is in a pre-disbursement AASM state (`:created`, `:documentation_in_progress`, `:ready_for_disbursement`)
  - [x] 2.7 Add display helpers: `principal_amount_display`, `tenure_display`, `repayment_frequency_label`, `interest_mode_label`, `interest_display`, `notes_display` — follow the same "Not provided yet" pattern from `LoanApplication`
- [x] Task 3: Create `Loans::UpdateDetails` service (AC: #1)
  - [x] 3.1 Implement service following the established `Result` struct pattern with `success?`, `blocked?`, and `locked?` methods
  - [x] 3.2 Guard: return blocked result if loan is not in a pre-disbursement state (`!loan.editable_details?`)
  - [x] 3.3 Use `with_lock` on the loan, update with `:details_update` validation context
  - [x] 3.4 Return the loan on success; return validation errors for form re-render on failure
- [x] Task 4: Add `Loans::FilteredListQuery` query object (AC: #2)
  - [x] 4.1 Create `app/queries/loans/filtered_list_query.rb` following the exact pattern from `LoanApplications::FilteredListQuery`
  - [x] 4.2 Accept optional `status:` (whitelisted against AASM state names) and `search:` (ILIKE on `loan_number` and `borrowers.full_name`)
  - [x] 4.3 Default ordering: `created_at: :desc, id: :desc`, with `includes(:borrower)`
- [x] Task 5: Expand `LoansController` with `index`, `update`, and `begin_documentation` actions (AC: #1, #2, #3)
  - [x] 5.1 Add `index` action: use `Loans::FilteredListQuery`, expose `@search_query`, `@status_filter`, `@loans`, `@has_loans`
  - [x] 5.2 Add `update` action: call `Loans::UpdateDetails`, redirect on success, re-render show on validation failure, redirect with alert on blocked/locked
  - [x] 5.3 Add `begin_documentation` member action: call `loan.begin_documentation!` inside `with_lock`, redirect with flash. Guard with `loan.may_begin_documentation?`; redirect with alert if invalid
  - [x] 5.4 Follow the existing thin-controller pattern: find → service.call → redirect + flash
- [x] Task 6: Update routes for loans (AC: #1, #2, #3)
  - [x] 6.1 Expand `resources :loans, only: :show` to `resources :loans, only: [:index, :show, :update]` with the UUID constraint
  - [x] 6.2 Add `member { patch :begin_documentation }` inside the loans resource block
- [x] Task 7: Create loan list view (AC: #2)
  - [x] 7.1 Create `app/views/loans/index.html.erb` following the exact visual pattern of `app/views/loan_applications/index.html.erb`: page title, status filter tabs, search bar, data table with loan number, borrower name, lifecycle state badge, created date
  - [x] 7.2 Include an empty state ("No loans found") matching the applications list empty state
  - [x] 7.3 Each table row links to `loan_path(loan, from: "loans")` to support breadcrumb context
  - [x] 7.4 Status filter tabs: "All", plus one per AASM state using `Loan.aasm.states.map(&:name)`
- [x] Task 8: Expand loan show page with editable details form (AC: #1, #3)
  - [x] 8.1 Add a "Pre-disbursement loan details" section below the existing loan summary, following the same form pattern as `loan_applications/show.html.erb` (form with labels, inputs, disabled when locked)
  - [x] 8.2 Form fields: principal amount, tenure in months, repayment frequency (select), interest mode (select), interest rate (shown when mode is "rate"), total interest amount (shown when mode is "total_interest_amount"), notes (textarea)
  - [x] 8.3 Show a locked callout ("These loan details can no longer be edited after disbursement.") when `!@loan.editable_details?`
  - [x] 8.4 Show validation error summary matching the application workspace pattern
  - [x] 8.5 Add "Begin documentation" button when `@loan.may_begin_documentation?`, with a Turbo confirm dialog explaining the consequence
  - [x] 8.6 Update breadcrumb to include a "Loans" link when `params[:from] == "loans"`
  - [x] 8.7 Add a "Current loan summary" read-only section showing all finalized details, matching the "Current request summary" section on applications
- [x] Task 9: Add "Loans" link to workspace navigation (AC: #2)
  - [x] 9.1 Add a "Loans" link to the home/workspace page (same pattern as "Applications" and "Browse borrowers")
- [x] Task 10: Write tests (AC: #1, #2, #3)
  - [x] 10.1 Model specs: new validations on `:details_update` context, `editable_details?`, mutual-exclusivity of interest fields, display helpers, `monetize` declarations
  - [x] 10.2 Service specs for `Loans::UpdateDetails`: successful update in pre-disbursement state, blocked update in post-disbursement state, validation failure returns errors
  - [x] 10.3 Query specs for `Loans::FilteredListQuery`: filters by status, searches by loan number and borrower name, default ordering
  - [x] 10.4 Request specs: `GET /loans` renders loan list with filters; `PATCH /loans/:id` updates details and redirects; `PATCH /loans/:id/begin_documentation` transitions state; auth guards on all new endpoints
  - [x] 10.5 System specs: end-to-end flow — navigate to loan list → filter by state → open loan → edit details → save → verify summary → begin documentation → verify state change

### Review Findings

- [x] [Review][Patch] Switching interest modes leaves the previously saved opposing value in place, so valid edits can fail with mutual-exclusivity errors [app/views/loans/show.html.erb:191-213]

## Dev Notes

### Critical Architecture Constraints

- **Domain services own all mutations.** `Loans::UpdateDetails` handles the detail edit — controllers must not write loan attributes directly. [Source: architecture.md — "Domain logic boundaries"]
- **AASM for state machines.** The loan AASM is already fully defined in Story 4.1. This story uses `may_begin_documentation?` and `begin_documentation!` for the lifecycle transition. Do NOT modify the AASM definition. [Source: architecture.md — Core Architectural Decisions]
- **Service result pattern.** Follow the established `Result = Struct.new(:loan, :error, keyword_init: true)` with `success?` and `blocked?` methods. Add `locked?` for the pre/post-disbursement guard (matching `LoanApplications::UpdateDetails`). [Source: architecture.md — Service boundaries]
- **`with_lock` for transitions.** All state-changing services must acquire a pessimistic lock. [Source: architecture.md — Concurrency patterns]
- **`paper_trail` for audit.** `Loan` already has `has_paper_trail` from Story 4.1. Edits will be tracked automatically. [Source: prd.md — FR68, FR69]
- **Pre-disbursement = editable window.** Per FR32 and FR71: loan details (principal, tenure, frequency, interest, notes) are editable while the loan is in `created`, `documentation_in_progress`, or `ready_for_disbursement`. After disbursement (state `active` or later), they become locked. [Source: prd.md — FR32, FR71]
- **Interest mode mutual exclusivity.** Per FR42: a loan uses either an interest rate OR a total interest amount, never both. [Source: prd.md — FR42]
- **`money-rails` for currency.** Use `monetize :principal_amount_cents, allow_nil: true` — same pattern as `LoanApplication.requested_amount_cents`. Store cents in `bigint`. [Source: architecture.md — Data Architecture; existing pattern in `LoanApplication`]
- **No hard delete.** Never destroy loan records. [Source: prd.md — FR70]
- **No `double_entry` postings.** This story does NOT touch double-entry accounting. That belongs to Story 4.5 (disbursement). [Source: architecture.md — "Only money-moving domain services should create double_entry postings"]

### Loan Details Fields (New Columns)

| Column | Type | Nullable | Notes |
|--------|------|----------|-------|
| `principal_amount_cents` | bigint | yes | Monetized via `money-rails` |
| `tenure_in_months` | integer | yes | Positive integer when provided |
| `repayment_frequency` | string | yes | weekly, bi-weekly, monthly |
| `interest_mode` | string | yes | rate, total_interest_amount |
| `interest_rate` | decimal(8,4) | yes | Present only when mode=rate |
| `total_interest_amount_cents` | bigint | yes | Present only when mode=total_interest_amount |
| `disbursement_date` | date | yes | Set by Story 4.5 at disbursement time |
| `notes` | text | yes | Admin operational notes |

All columns are nullable because a newly created loan starts with no details filled in. Validation enforces presence only on the `:details_update` context (when the admin submits the form).

### Editability Logic

```ruby
def editable_details?
  %i[created documentation_in_progress ready_for_disbursement].include?(aasm.current_state)
end
```

This mirrors the `LoanApplication#editable_pre_decision_details?` pattern.

### Service: `Loans::UpdateDetails`

File: `app/services/loans/update_details.rb`

Follow the same structure as `LoanApplications::UpdateDetails`:

```ruby
module Loans
  class UpdateDetails < ApplicationService
    Result = Struct.new(:loan, :error, keyword_init: true) do
      def success? = error.blank? && loan&.errors&.none?
      def blocked? = error.present?
      def locked? = error == "locked"
    end

    def initialize(loan:, attributes:)
      @loan = loan
      @attributes = attributes
    end

    def call
      loan.with_lock do
        unless loan.editable_details?
          loan.errors.add(:base, "These loan details can no longer be edited after disbursement.")
          return Result.new(loan:, error: "locked")
        end

        loan.assign_attributes(attributes)
        loan.save(context: :details_update)
        Result.new(loan:)
      end
    end

    private
      attr_reader :loan, :attributes
  end
end
```

### Query: `Loans::FilteredListQuery`

File: `app/queries/loans/filtered_list_query.rb`

Mirror `LoanApplications::FilteredListQuery` exactly. Whitelist status against AASM state names. Search on `loans.loan_number ILIKE :query OR borrowers.full_name ILIKE :query`.

### Controller Pattern

The `approve` action in `LoanApplicationsController` shows the manual redirect pattern. Use the same approach for `begin_documentation`:

```ruby
def begin_documentation
  @loan = Loan.find(params[:id])
  @loan.with_lock do
    if @loan.may_begin_documentation?
      @loan.begin_documentation!
      redirect_to loan_redirect_path, notice: "Documentation stage started for #{@loan.loan_number}."
    else
      redirect_to loan_redirect_path, alert: "This loan cannot begin documentation from its current state."
    end
  end
end
```

The `update` action follows the pattern from `LoanApplicationsController#update`: service call → redirect on success → re-render on validation failure → redirect on locked.

### Loan List View

Follow the same structure as `app/views/loan_applications/index.html.erb`:
- Page title: "Loans"
- Filter tabs across the top: All + one per AASM state
- Search bar: "Search by loan number or borrower name"
- Table columns: Loan number (linked), Borrower, Lifecycle state (badge), Created
- Empty state: "No loans found" card with guidance text
- Each row links to `loan_path(loan, from: "loans")`

### Loan Show Expansion

The existing `loans/show.html.erb` from Story 4.1 shows the loan header, borrower snapshot, linked application, and lifecycle guidance. This story adds below those sections:

1. **Pre-disbursement loan details form** — editable fields for principal, tenure, frequency, interest mode/rate/amount, notes. Disabled when `!@loan.editable_details?`. Locked callout when post-disbursement.
2. **Current loan summary** — read-only display of all current details (matching the "Current request summary" pattern on application show).
3. **Begin documentation button** — visible when `@loan.may_begin_documentation?`, styled as primary action with Turbo confirm.

### Workspace Navigation

Add a "Loans" card/link to the home page (`app/views/home/index.html.erb`) matching the existing "Applications" and "Browse borrowers" entries.

### Form Fields — Interest Mode Conditional Display

When `interest_mode == "rate"`: show `interest_rate` input, hide `total_interest_amount`.
When `interest_mode == "total_interest_amount"`: show `total_interest_amount` input, hide `interest_rate`.
When neither is selected: show both as disabled placeholders.

Use a Stimulus controller (e.g., `interest-mode-toggle`) to handle the conditional show/hide on the client side, keeping it purely cosmetic — the server-side mutual-exclusivity validation is the source of truth.

### Previous Story Intelligence

From Story 4.1 (create loan from approved application):
- **Pattern:** The `Loan` model already has AASM, `paper_trail`, borrower snapshots, `status_tone`, `status_label`, `next_lifecycle_stage_label`, `next_lifecycle_stage_guidance`, `create_with_next_loan_number!`. Do NOT duplicate or modify these.
- **Review finding applied:** `Loan.next_loan_number` was serialized with table-level locking in `create_with_next_loan_number!`. This story does not create new loans, so no interaction with that code.
- **Review finding applied:** `Loan#next_lifecycle_stage_label` was fixed for `:overdue` state. No further changes needed.
- **Controller pattern:** `LoansController` currently has only `show`. Expand it in place — do NOT create a separate controller.
- **Factory:** The loan factory defaults to `status: "created"` with traits for all lifecycle states. Extend it with new optional attributes but do NOT change existing defaults.
- **Testing:** 197 examples passing after Story 4.1. Do not break existing tests.
- **SimpleCov:** The repo enforces 80% minimum coverage per run. Focused spec runs exit non-zero under SimpleCov; validate with the full suite.
- **PostgreSQL/Docker:** Ensure DB is running before test suite.

### Git Intelligence

Recent commits follow the pattern: `Add <feature description>.` with focused, single-story changes. The last commit (`041a8c4`) touched 19 files. Keep changes focused on this story's scope.

### Project Structure Notes

Files to create:
- `db/migrate/YYYYMMDDHHMMSS_add_financial_details_to_loans.rb`
- `app/services/loans/update_details.rb`
- `app/queries/loans/filtered_list_query.rb`
- `app/views/loans/index.html.erb`
- `spec/services/loans/update_details_spec.rb`
- `spec/queries/loans/filtered_list_query_spec.rb`

Files to modify:
- `app/models/loan.rb` — monetize, constants, validations, editability, display helpers
- `app/controllers/loans_controller.rb` — index, update, begin_documentation actions
- `config/routes.rb` — expand loans resource
- `app/views/loans/show.html.erb` — add details form, summary section, begin_documentation button
- `app/views/home/index.html.erb` — add "Loans" navigation entry
- `db/schema.rb` — auto-updated by migration
- `spec/factories/loans.rb` — add financial detail attributes and traits
- `spec/models/loan_spec.rb` — extend with new validations and helpers
- `spec/requests/loans_spec.rb` — loan list, update, begin_documentation
- `spec/system/loan_detail_flow_spec.rb` — end-to-end loan preparation flow

Files NOT to touch:
- Do not modify `Loans::CreateFromApplication` or `LoanApplications::Approve`
- Do not add document upload logic (that's Story 4.3)
- Do not add disbursement readiness checks (that's Story 4.4)
- Do not add disbursement execution or `double_entry` postings (that's Story 4.5)
- Do not modify the AASM state/event definitions (fully defined in Story 4.1)

### Testing Requirements

- **Model specs:** `monetize` declarations, `:details_update` validation context, `editable_details?` returns true/false based on AASM state, interest mutual-exclusivity, display helpers
- **Service specs for `Loans::UpdateDetails`:** Successful update in `created` state; successful update in `documentation_in_progress` state; blocked update in `active` state; validation failure on missing fields; interest mode exclusivity enforcement
- **Query specs for `Loans::FilteredListQuery`:** Default ordering; status filter returns matching loans; search matches loan number; search matches borrower name; combined filter + search
- **Request specs:** `GET /loans` renders list; `GET /loans?status=created` filters; `PATCH /loans/:id` saves details; `PATCH /loans/:id/begin_documentation` transitions state; auth guards on all new endpoints
- **System specs:** Navigate from workspace → loans list → filter → open loan → fill details → save → verify summary → begin documentation → verify state transition → navigate back to list

### References

- [Source: architecture.md — Loan lifecycle states: FR34, FR35]
- [Source: architecture.md — Service boundaries and `Loans::UpdateDetails`]
- [Source: architecture.md — `Loans::FilteredListQuery` pattern from `LoanApplications::FilteredListQuery`]
- [Source: architecture.md — `money-rails` for currency, `monetize` pattern]
- [Source: architecture.md — Pre-disbursement editable vs post-disbursement locked]
- [Source: prd.md — FR32: Prepare and finalize loan details before disbursement]
- [Source: prd.md — FR36: View current lifecycle state on loan records]
- [Source: prd.md — FR37: Filter loan lists by lifecycle state]
- [Source: prd.md — FR42: Interest rate OR total interest amount, not both]
- [Source: prd.md — FR71: Prevent editing of loan records after disbursement]
- [Source: epics.md — Epic 4, Story 4.2 acceptance criteria]
- [Source: ux-design-specification.md — Lifecycle Status Badge, Entity Header, Form Patterns, Button Hierarchy]

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- `bin/rails db:migrate`
- `RAILS_ENV=test bin/rails db:migrate`
- `bundle exec rspec`

### Completion Notes List

- Added loan financial detail persistence, domain rules, pre-disbursement editability checks, and display helpers on `Loan`.
- Implemented `Loans::UpdateDetails`, `Loans::FilteredListQuery`, expanded `LoansController`, updated routes, and added the new loans list/detail workflows with interest-mode UI toggling.
- Added coverage across model, service, query, request, and system specs; full RSpec suite passed (`226 examples, 0 failures`).
- During manual browser verification, removed the broken unused `shadcn` controller bootstrap so Stimulus could load cleanly and the interest-mode toggle could run in a real browser.

### File List

- `_bmad-output/implementation-artifacts/4-2-prepare-and-review-loan-details-before-disbursement.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/controllers/loans_controller.rb`
- `app/javascript/controllers/application.js`
- `app/javascript/controllers/interest_mode_toggle_controller.js`
- `app/models/loan.rb`
- `app/queries/loans/filtered_list_query.rb`
- `app/services/loans/update_details.rb`
- `app/views/home/index.html.erb`
- `app/views/loans/index.html.erb`
- `app/views/loans/show.html.erb`
- `config/routes.rb`
- `db/migrate/20260415161146_add_financial_details_to_loans.rb`
- `db/schema.rb`
- `spec/factories/loans.rb`
- `spec/models/loan_spec.rb`
- `spec/queries/loans/filtered_list_query_spec.rb`
- `spec/requests/loans_spec.rb`
- `spec/services/loans/update_details_spec.rb`
- `spec/system/loan_detail_flow_spec.rb`

### Change Log

- 2026-04-15: Implemented Story 4.2 loan preparation, review, navigation, and testing flow; validated with full RSpec suite.
- 2026-04-15: Completed manual browser verification for the loan preparation flow and fixed the broken unused `shadcn` controller bootstrap that blocked Stimulus runtime behavior.
