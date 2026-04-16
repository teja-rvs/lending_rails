# Story 4.5: Execute Guarded Disbursement, Create Financial Records, and Lock the Loan

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want loan disbursement to be explicit, auditable, and financially final,
So that the system activates servicing only when funds have truly been released.

## Acceptance Criteria

1. **Given** a loan has passed all disbursement readiness checks
   **When** the admin initiates disbursement
   **Then** the UI presents a guarded confirmation describing the consequence of the action
   **And** the admin must explicitly confirm before the money event is recorded

2. **Given** the admin confirms a valid disbursement
   **When** the domain service executes the disbursement
   **Then** the system records disbursement as the event that activates the loan
   **And** creates the disbursement invoice and any required accounting or audit records as part of the same business action

3. **Given** a loan has been disbursed
   **When** the admin returns to the loan
   **Then** the loan shows the correct active post-disbursement state
   **And** disbursement-locked loan fields are no longer editable

4. **Given** a disbursement has already been committed
   **When** an operator attempts to repeat or mutate that committed financial event through normal editing flows
   **Then** the system blocks the action
   **And** preserves the original committed financial history

## Tasks / Subtasks

- [ ] Task 1: Create `Invoice` model and migration (AC: #2)
  - [ ] 1.1 Create migration for `invoices` table: UUID PK (`gen_random_uuid()`), `loan_id` (UUID FK to loans, not null), `invoice_number` (string, not null, unique), `invoice_type` (string, not null — "disbursement" for this story), `amount_cents` (bigint, not null), `currency` (string, not null, default "INR"), `issued_on` (date, not null), `notes` (text, nullable), timestamps
  - [ ] 1.2 Add indexes: `loan_id`, `invoice_number` (unique), `invoice_type`, `issued_on`
  - [ ] 1.3 Add FK constraint: `loan_id` references `loans`
  - [ ] 1.4 Create `Invoice` model: `belongs_to :loan`, `has_paper_trail`, `monetize :amount_cents`
  - [ ] 1.5 Add validations: `invoice_number` presence + uniqueness, `invoice_type` presence + inclusion in `INVOICE_TYPES`, `amount_cents` presence + numericality (> 0), `issued_on` presence
  - [ ] 1.6 Add `INVOICE_TYPES = ["disbursement"].freeze` (extend with "payment" in Epic 5)
  - [ ] 1.7 Add scopes: `scope :disbursement, -> { where(invoice_type: "disbursement") }`, `scope :ordered, -> { order(issued_on: :desc, created_at: :desc) }`
  - [ ] 1.8 Add `self.next_invoice_number` class method following the same table-lock sequence pattern as `Loan.next_loan_number` — format: `INV-0001`
  - [ ] 1.9 Run migration in both dev and test
- [ ] Task 2: Add `has_many :invoices` to `Loan` model (AC: #2, #3)
  - [ ] 2.1 Add `has_many :invoices, dependent: :restrict_with_exception`
  - [ ] 2.2 Add `#disbursement_invoice` convenience: `invoices.disbursement.first`
  - [ ] 2.3 Add `#disbursed?` convenience: `active? || overdue? || closed?` (post-disbursement states)
- [ ] Task 3: Configure `double_entry` accounts and transfers (AC: #2)
  - [ ] 3.1 Update `config/initializers/double_entry.rb` — uncomment and configure:
    - Define loan-scoped accounts: `loan_receivable` (positive_only: true) and `disbursement_clearing`
    - Scope identifier: `->(loan) { loan.id }` (UUID scope)
    - Define transfer: `from: :disbursement_clearing, to: :loan_receivable, code: :disbursement`
  - [ ] 3.2 Add RSpec config for `double_entry` transactional fixture compatibility: `DoubleEntry::Locking.configuration.running_inside_transactional_fixtures = true` in `spec/support/` or `rails_helper.rb`
- [ ] Task 4: Create `Invoices::IssueDisbursementInvoice` service (AC: #2)
  - [ ] 4.1 Follow established `Result = Struct.new(:invoice, :error, keyword_init: true)` with `success?` / `blocked?` pattern
  - [ ] 4.2 Accept `loan:` parameter — derive amount from `loan.principal_amount`, issued_on from disbursement date
  - [ ] 4.3 Guard: return blocked if loan does not have `principal_amount` set
  - [ ] 4.4 Guard: return blocked if a disbursement invoice already exists for this loan (idempotency)
  - [ ] 4.5 Create `Invoice` with `invoice_type: "disbursement"`, auto-generated `invoice_number`, `amount_cents` from loan's principal
  - [ ] 4.6 Return the invoice on success
  - [ ] 4.7 This service is called from within `Loans::Disburse` — it does NOT need `with_lock` (caller provides the lock)
- [ ] Task 5: Create `Loans::Disburse` service (AC: #1, #2, #3, #4)
  - [ ] 5.1 Follow established `Result` struct pattern with `success?` / `blocked?`
  - [ ] 5.2 Accept `loan:`, `disbursed_by:` (current user for audit context)
  - [ ] 5.3 Use `loan.with_lock` for thread safety
  - [ ] 5.4 Guard: return blocked if `!loan.may_disburse?` (AASM eligibility — loan must be in `ready_for_disbursement`)
  - [ ] 5.5 Guard: return blocked if readiness checks fail — call `Loans::EvaluateDisbursementReadiness.call(loan: loan)` and verify `result.ready_for_disbursement_action?` (service created in Story 4.4)
  - [ ] 5.6 Guard: return blocked if `loan.principal_amount.blank?` (financial details must be complete)
  - [ ] 5.7 Wrap in `ActiveRecord::Base.transaction`:
    - Set `loan.disbursement_date = Date.current`
    - Call `loan.disburse!` (AASM transition `ready_for_disbursement → active`)
    - Call `Invoices::IssueDisbursementInvoice.call(loan: loan)` — propagate blocked result if it fails
    - Post `DoubleEntry.transfer`: `Money.new(loan.principal_amount_cents, "INR")` from `disbursement_clearing` to `loan_receivable` scoped to loan, code `:disbursement`, with metadata `{ loan_id: loan.id, invoice_id: invoice.id, disbursed_by: disbursed_by.id }`
  - [ ] 5.8 Return `Result.new(loan: loan, invoice: invoice)` on success
  - [ ] 5.9 Pure domain logic — no params, no HTTP — only loan and associations
- [ ] Task 6: Add `disburse` action to `LoansController` (AC: #1, #4)
  - [ ] 6.1 Add `disburse` as a member `PATCH` action following the `begin_documentation` / `complete_documentation` pattern
  - [ ] 6.2 Add to `before_action :set_loan` list
  - [ ] 6.3 Call `Loans::Disburse.call(loan: @loan, disbursed_by: Current.user)`
  - [ ] 6.4 Success: redirect with notice `"#{@loan.loan_number} has been disbursed. The loan is now active and repayment tracking begins."`
  - [ ] 6.5 Blocked: redirect with alert containing the `result.error` message
  - [ ] 6.6 Thin controller — find → service → redirect + flash
- [ ] Task 7: Add route for disbursement (AC: #1)
  - [ ] 7.1 Add `patch :disburse` to the loans member block alongside `begin_documentation` and `complete_documentation`
- [ ] Task 8: Update loan show page — disbursement section and post-disbursement state (AC: #1, #3, #4)
  - [ ] 8.1 Add a "Disbursement" section on `loans/show.html.erb` — placement: after the disbursement readiness section (added by Story 4.4), before "Pre-disbursement loan details"
  - [ ] 8.2 When loan is `ready_for_disbursement` AND readiness checks pass: show "Confirm disbursement" button
  - [ ] 8.3 Button must use a guarded confirmation pattern — `data-turbo-confirm` with a multi-line consequence summary: "You are about to disburse {loan_number}. This action records the disbursement date, creates the disbursement invoice, posts accounting entries, and locks the loan for active servicing. This action cannot be undone."
  - [ ] 8.4 When loan is post-disbursement (`active`, `overdue`, `closed`): show disbursement summary card with disbursement date, invoice number (linked), principal disbursed amount, and locked-state indicator
  - [ ] 8.5 Post-disbursement: ensure "Pre-disbursement loan details" section header changes to "Loan details (locked)" with the existing amber locked callout
  - [ ] 8.6 When loan is pre-`ready_for_disbursement` (created, documentation_in_progress): do NOT show disbursement section at all
  - [ ] 8.7 Expose `@disbursement_readiness` in controller `show` action when loan is `ready_for_disbursement` (reuse from 4.4)
  - [ ] 8.8 Preload `invoices` in `set_loan` includes for N+1 prevention
- [ ] Task 9: Create `spec/factories/invoices.rb` (AC: #2)
  - [ ] 9.1 Factory with proper loan association, auto-generated invoice_number sequence, `invoice_type: "disbursement"`, amount from loan principal or default
  - [ ] 9.2 Trait `:disbursement` (default), future extensibility for `:payment`
- [ ] Task 10: Write tests (AC: #1, #2, #3, #4)
  - [ ] 10.1 Model specs for `Invoice`: validations (invoice_number uniqueness, amount > 0, invoice_type inclusion, issued_on presence), associations, scopes, `next_invoice_number`
  - [ ] 10.2 Model specs for `Loan`: `has_many :invoices`, `disbursement_invoice`, `disbursed?`
  - [ ] 10.3 Service specs for `Invoices::IssueDisbursementInvoice`: successful creation, blocked when invoice already exists, blocked when principal missing
  - [ ] 10.4 Service specs for `Loans::Disburse`: successful disbursement (sets date, transitions state, creates invoice, posts ledger entries), blocked when not in `ready_for_disbursement`, blocked when readiness checks fail, blocked when already disbursed, idempotency (cannot disburse twice)
  - [ ] 10.5 Request specs for `PATCH /loans/:id/disburse`: success redirect + flash, blocked redirect + alert, auth guard, duplicate attempt blocked
  - [ ] 10.6 System spec: end-to-end flow — navigate to ready-for-disbursement loan → see disbursement section → click confirm disbursement → confirm dialog → verify loan shows active state → verify locked fields → verify disbursement date and invoice visible
  - [ ] 10.7 Run full `bundle exec rspec` before marking complete

## Dev Notes

### Epic 4 Cross-Story Context

- **4.1** created `Loan` model with full AASM lifecycle including `disburse` event (`ready_for_disbursement → active`). Added `Loans::CreateFromApplication` service and the `Result` struct pattern. [Source: `app/models/loan.rb`, `app/services/loans/create_from_application.rb`]
- **4.2** added `Loans::UpdateDetails` with `editable_details?` gate and `on: :details_update` validation context. Financial columns (`principal_amount_cents`, `tenure_in_months`, `repayment_frequency`, `interest_mode`, `interest_rate`, `total_interest_amount_cents`, `disbursement_date`) added to `loans` table. [Source: `app/services/loans/update_details.rb`, `app/models/loan.rb`]
- **4.3** (status: review) added `DocumentUpload` model, Active Storage, documentation stage actions (`begin_documentation`, `complete_documentation`), and the full loan documentation UI. Established `documentation_uploadable?` gate. [Source: `app/controllers/loans_controller.rb`, `app/views/loans/show.html.erb`]
- **4.4** (status: ready-for-dev, NOT YET IMPLEMENTED) will create `Loans::EvaluateDisbursementReadiness` service that returns a checklist result with `ready_for_disbursement_action?`. This story (4.5) depends on 4.4 being implemented first. [Source: `_bmad-output/implementation-artifacts/4-4-validate-disbursement-readiness.md`]

### Critical Architecture Constraints

- **Domain services own all money-critical mutations.** Disbursement belongs in `app/services/loans/disburse.rb` — the controller must NOT perform AASM transitions, invoice creation, or ledger postings directly. [Source: architecture.md — "Money-critical domain services"]
- **`double_entry` for bookkeeping.** Only money-moving domain services create `double_entry` postings. The architecture explicitly requires `double_entry` to separate operational records from accounting truth. [Source: architecture.md — "Only money-moving domain services should create double_entry postings"]
- **AASM for state transitions.** The `disburse` event is already defined: `transitions from: :ready_for_disbursement, to: :active`. Do NOT modify the AASM definition — it is correct. [Source: `app/models/loan.rb` lines 67-69]
- **`disbursement_date` column exists.** The `loans` table already has a `disbursement_date` (date) column — currently always `nil`. Set it to `Date.current` during disbursement. Do NOT create a new column. [Source: `db/schema.rb` line 138]
- **Service result pattern.** Follow the established `Result = Struct.new(:entity, :error, keyword_init: true)` with `success?` and `blocked?` methods. See `Loans::CreateFromApplication`, `Loans::UpdateDetails`, `Documents::Upload` for canonical examples. [Source: existing services]
- **`with_lock` for transitions.** All state-changing services acquire a pessimistic lock. [Source: architecture.md — Concurrency patterns; existing controller actions]
- **`paper_trail` for audit.** Add `has_paper_trail` to `Invoice`. PaperTrail whodunnit is already configured in `ApplicationController`. [Source: prd.md — FR68, FR69]
- **UUID primary keys.** The `invoices` table MUST use `id: :uuid`. All domain entities use UUID PKs. [Source: architecture.md — UUID identity strategy]
- **No hard delete.** Never destroy invoice records. [Source: prd.md — FR70]
- **`money-rails` for amounts.** Use `monetize :amount_cents` on `Invoice`. The gem is installed (`money-rails ~> 3.0`). [Source: `Gemfile` line 74]
- **Post-disbursement locking is already enforced.** `Loan#editable_details?` returns false for `active`, `overdue`, `closed` states. `Loans::UpdateDetails` returns a locked error for those states. `documentation_uploadable?` is gated the same way. No new locking code is required — the existing gates cover AC #3 and #4. [Source: `app/models/loan.rb` lines 126-128, `app/services/loans/update_details.rb`]

### `double_entry` Configuration — First Use in This Project

The `double_entry` gem is installed (`~> 2.0`) and tables exist (`double_entry_account_balances`, `double_entry_lines`, `double_entry_line_checks`) but accounts and transfers are NOT configured yet (initializer is commented out).

**Account design for disbursement:**

```ruby
DoubleEntry.configure do |config|
  config.json_metadata = true

  config.define_accounts do |accounts|
    loan_scope = ->(loan) do
      raise "not a Loan" unless loan.instance_of?(Loan)
      loan.id
    end
    accounts.define(identifier: :loan_receivable, scope_identifier: loan_scope, positive_only: true)
    accounts.define(identifier: :disbursement_clearing, scope_identifier: loan_scope)
  end

  config.define_transfers do |transfers|
    transfers.define(from: :disbursement_clearing, to: :loan_receivable, code: :disbursement)
  end
end
```

**Transfer call in the disburse service:**

```ruby
DoubleEntry.transfer(
  Money.new(loan.principal_amount_cents, "INR"),
  from: DoubleEntry.account(:disbursement_clearing, scope: loan),
  to:   DoubleEntry.account(:loan_receivable, scope: loan),
  code: :disbursement,
  metadata: { loan_id: loan.id, invoice_id: invoice.id, disbursed_by: disbursed_by.id }
)
```

**RSpec setup requirement:** Add to `spec/rails_helper.rb` or `spec/support/double_entry.rb`:

```ruby
DoubleEntry::Locking.configuration.running_inside_transactional_fixtures = true
```

Without this, tests using `DoubleEntry.transfer` will raise `DoubleEntry::Locking::LockMustBeOutermostTransaction` because RSpec wraps each test in a transaction.

### Invoice Model Design

| Column | Type | Nullable | Notes |
|--------|------|----------|-------|
| `id` | uuid | no | PK, `gen_random_uuid()` |
| `loan_id` | uuid | no | FK to loans |
| `invoice_number` | string | no | Unique, auto-generated `INV-0001` |
| `invoice_type` | string | no | "disbursement" (extend with "payment" in Epic 5) |
| `amount_cents` | bigint | no | Monetized via `money-rails` |
| `currency` | string | no | Default "INR" |
| `issued_on` | date | no | Date of disbursement |
| `notes` | text | yes | Optional notes |
| `created_at` | datetime | no | |
| `updated_at` | datetime | no | |

Follow `Loan.next_loan_number` pattern for `Invoice.next_invoice_number`:

```ruby
def self.next_invoice_number
  highest_sequence = where("invoice_number LIKE ?", "INV-%")
    .pluck(:invoice_number)
    .filter_map { |v| v.to_s.delete_prefix("INV-").to_i if v.to_s.match?(/\AINV-\d+\z/) }
    .max
  "INV-#{((highest_sequence || 0) + 1).to_s.rjust(4, "0")}"
end
```

### `Loans::Disburse` Service Design

The service orchestrates four atomic operations inside one `ActiveRecord::Base.transaction`:

1. Set `disbursement_date = Date.current`
2. Fire `loan.disburse!` (AASM: `ready_for_disbursement → active`)
3. Create disbursement invoice via `Invoices::IssueDisbursementInvoice`
4. Post `DoubleEntry.transfer` for the principal amount

If any step fails, the entire transaction rolls back. The `with_lock` must be the outermost call, wrapping the transaction.

**Dependency on Story 4.4:** The disburse service calls `Loans::EvaluateDisbursementReadiness` as a guard. If 4.4 is not yet implemented when you start this story, stub the readiness check and add a `TODO` — but prefer implementing 4.4 first.

### Guarded Confirmation UI Pattern

The UX spec defines a **Guarded Confirmation Dialog** for money-sensitive actions:
- **Action title:** "Confirm disbursement"
- **Consequence summary:** Explain what happens (disbursement date set, invoice created, accounting posted, loan becomes active and locked)
- **Locked-state explanation:** "Loan details will no longer be editable after disbursement."
- **Confirm/cancel actions:** Explicit "Confirm disbursement" / "Cancel" buttons

Implementation: Use `data-turbo-confirm` with a descriptive multi-line message on the `button_to` form. This matches the existing pattern used for `begin_documentation` and `complete_documentation` but with a stronger consequence message.

**Button placement:** Show the "Confirm disbursement" button in the disbursement section ONLY when:
- Loan is in `ready_for_disbursement` state
- `Loans::EvaluateDisbursementReadiness` returns `ready_for_disbursement_action?` as true

When readiness checks fail, show the blocked-state callout from Story 4.4 instead.

### Post-Disbursement UI Changes

After disbursement, the loan show page should display:

1. **Disbursement summary card** (replaces disbursement readiness section):
   - Disbursement date
   - Invoice number (linked if invoice detail view exists, otherwise plain text)
   - Disbursed amount (formatted via `money-rails`)
   - Status: "Disbursed — loan is now active"
   - Locked indicator icon/text

2. **Locked-state callout** (existing): The amber callout "These loan details can no longer be edited after disbursement" already renders when `editable_details?` returns false — no change needed.

3. **Document upload locked** (existing): The amber callout "Documents can no longer be uploaded after disbursement" already renders — no change needed.

### Library / Framework Requirements

- **Rails ~> 8.1** — use `button_to` with `data-turbo-confirm` for guarded confirmation
- **AASM ~> 5.5** — `loan.may_disburse?` for transition eligibility; do NOT redefine AASM events
- **money-rails ~> 3.0** — `monetize :amount_cents` on Invoice; use `Money.new(cents, "INR")` for `double_entry` transfers
- **double_entry ~> 2.0** — configure accounts/transfers in initializer; use `DoubleEntry.transfer` in service; handle `DoubleEntry::Locking::LockMustBeOutermostTransaction` in tests
- **paper_trail ~> 17.0** — add `has_paper_trail` to Invoice
- **Pundit ~> 2.5** — authorize the new `disburse` action consistently with existing loan actions

### File Structure (Expected Touchpoints)

| Area | Files |
|------|--------|
| New | `db/migrate/YYYYMMDDHHMMSS_create_invoices.rb` |
| New | `app/models/invoice.rb` |
| New | `app/services/loans/disburse.rb` |
| New | `app/services/invoices/issue_disbursement_invoice.rb` |
| New | `spec/factories/invoices.rb` |
| New | `spec/models/invoice_spec.rb` |
| New | `spec/services/loans/disburse_spec.rb` |
| New | `spec/services/invoices/issue_disbursement_invoice_spec.rb` |
| New | `spec/support/double_entry.rb` (or add to `rails_helper.rb`) |
| Modify | `config/initializers/double_entry.rb` — uncomment and configure accounts/transfers |
| Modify | `app/models/loan.rb` — add `has_many :invoices`, `disbursement_invoice`, `disbursed?` |
| Modify | `app/controllers/loans_controller.rb` — add `disburse` action, update `set_loan` includes |
| Modify | `config/routes.rb` — add `patch :disburse` member route |
| Modify | `app/views/loans/show.html.erb` — disbursement section, post-disbursement summary |
| Modify | `spec/models/loan_spec.rb` — invoice association, `disbursed?` |
| Modify | `spec/requests/loans_spec.rb` — disburse request specs |
| Modify | `spec/factories/loans.rb` — update `:active` trait to include `disbursement_date` |

### Files NOT to Create or Modify

- Do NOT create `app/models/disbursement.rb` — there is no separate Disbursement model in the architecture. Disbursement is an event on Loan, not a standalone entity.
- Do NOT create `app/controllers/disbursements_controller.rb` — the `disburse` action lives on `LoansController` as a member action, consistent with `begin_documentation` and `complete_documentation`.
- Do NOT modify `app/models/loan.rb` AASM definitions — the `disburse` event already exists and is correct.
- Do NOT create a `guarded_confirmation_controller.js` Stimulus controller — use `data-turbo-confirm` which is already supported by Turbo and matches existing patterns (`begin_documentation`, `complete_documentation` buttons).
- Do NOT generate repayment schedules — that belongs to Story 5.1.
- Do NOT create payment-related invoices — that belongs to Epic 5.
- Do NOT add dashboard or list changes — that belongs to Epic 6.

### Existing Patterns to Follow

1. **Controller action pattern** — match `begin_documentation` / `complete_documentation` exactly:
   ```ruby
   def disburse
     result = Loans::Disburse.call(loan: @loan, disbursed_by: Current.user)
     if result.success?
       redirect_to loan_redirect_path, notice: "..."
     else
       redirect_to loan_redirect_path, alert: result.error
     end
   end
   ```

2. **Service result pattern** — `Result = Struct.new(:loan, :invoice, :error, keyword_init: true)` with `success?` / `blocked?`

3. **Table-lock sequence numbering** — follow `Loan.create_with_next_loan_number!` for invoice number generation (serialize allocation with `LOCK TABLE ... IN EXCLUSIVE MODE` inside transaction)

4. **View section pattern** — rounded-3xl card with status badge, dl grid for data display, conditional button rendering

5. **Preloading pattern** — add `:invoices` to the `set_loan` includes chain alongside existing `:borrower`, `:loan_application`, `document_uploads`

6. **Flash message tone** — success: calm, informative, mentions loan number; alert: explains what is blocked and why

### UX Requirements

- **Guarded confirmation:** The disbursement button MUST use a consequence summary, not a casual yes/no. The message should describe what happens (invoice created, accounting posted, loan locked) and what cannot be undone. [Source: ux-design-specification.md — "Guarded Confirmation Dialog"]
- **Blocked-state callout:** If readiness checks fail, show the blocked explanation from Story 4.4's readiness view — do NOT show the disburse button. [Source: ux-design-specification.md — "Blocked-State Callout"]
- **Post-disbursement state:** The loan detail should unmistakably show the active state, disbursement date, and locked indicator. The admin should never feel uncertain about whether disbursement was recorded correctly. [Source: ux-design-specification.md — "Critical success moment"]
- **Button copy:** "Confirm disbursement" — explicit action label per UX spec. NOT "Submit", "Continue", or "Proceed". [Source: ux-design-specification.md — "Buttons"]
- **Accessibility:** Locked and active states must be distinguishable without color alone (icons + text). Use semantic borders. [Source: ux-design-specification.md — Accessibility]

### Previous Story Intelligence

- **Thin controllers:** All existing loan controller actions follow `find → service.call → redirect + flash`. The disburse action must follow the same pattern. [Source: `app/controllers/loans_controller.rb`]
- **`with_lock` in services:** `Loans::UpdateDetails`, `Documents::Upload`, and `Documents::ReplaceActiveVersion` all use `entity.with_lock`. The disburse service must do the same. [Source: existing services]
- **N+1 prevention:** `set_loan` eagerly loads `:borrower`, `:loan_application`, `document_uploads: [:uploaded_by, :superseded_by, { file_attachment: :blob }]`. Add `:invoices` to this list. [Source: `app/controllers/loans_controller.rb` lines 53-61]
- **View conditionals:** The show page uses AASM state checks (`may_begin_documentation?`, `may_complete_documentation?`, `editable_details?`, `documentation_uploadable?`) for conditional rendering. Use `may_disburse?` and readiness result for disbursement button visibility. [Source: `app/views/loans/show.html.erb`]
- **Test count:** Full suite was ~270 examples at 4.3 completion. Keep green after all additions. [Source: Story 4.3 Dev Agent Record]
- **Factory traits:** The `:active` loan factory trait currently only sets `status { "active" }` with no `disbursement_date`. Update it to include `disbursement_date { Date.current }` for realistic test data. [Source: `spec/factories/loans.rb` lines 30-32]

### Git Intelligence

Recent commits follow this pattern:
- `15d78cb` Add loan documentation management before disbursement.
- `f6eb7d0` Add loan preparation workflow before disbursement.
- `041a8c4` Add loan creation from approved applications.

Preferred commit style: `"Add guarded disbursement with financial records and loan locking."`

### Double Entry Testing Notes

When writing specs for `Loans::Disburse`:

1. After a successful disburse, verify ledger entries exist:
   ```ruby
   expect(DoubleEntry.account(:loan_receivable, scope: loan).balance).to eq(Money.new(principal_cents, "INR"))
   expect(DoubleEntry.account(:disbursement_clearing, scope: loan).balance).to eq(Money.new(-principal_cents, "INR"))
   ```

2. Use `DoubleEntry::Line.where(scope: loan.id)` to verify metadata on posted lines.

3. Ensure `DoubleEntry::Locking.configuration.running_inside_transactional_fixtures = true` is set, or specs will raise `LockMustBeOutermostTransaction`.

4. For request/system specs, the double_entry postings are a side effect — verify via model state (loan is active, invoice exists, disbursement_date set) rather than querying ledger tables directly.

### Project Context Reference

- No `project-context.md` found in repo; rely on PRD, architecture, epics, and this file.

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
