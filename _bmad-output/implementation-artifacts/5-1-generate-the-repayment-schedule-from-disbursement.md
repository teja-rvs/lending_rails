# Story 5.1: Generate the Repayment Schedule from Disbursement

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want repayment schedules generated automatically when a loan is disbursed,
So that servicing begins from system-calculated facts instead of manual tracking.

## Acceptance Criteria

1. **Given** a loan has just been disbursed
   **When** the system activates repayment servicing
   **Then** it generates the repayment schedule automatically
   **And** the generated payment records are linked to the loan

2. **Given** the admin defines repayment rules
   **When** the schedule is generated
   **Then** the system supports weekly, bi-weekly, and monthly frequencies
   **And** it allows interest input by rate or total interest amount, but not both together

3. **Given** the MVP repayment rules are enforced
   **When** the schedule is created
   **Then** the system supports full-payment-only handling for MVP
   **And** the repayment output remains internally consistent with the loan terms

## Tasks / Subtasks

- [x] Task 1: Create `Payment` model and migration (AC: #1, #2, #3)
  - [x] 1.1 Create migration for `payments` table: UUID PK (`gen_random_uuid()`), `loan_id` (UUID FK to loans, not null), `installment_number` (integer, not null), `due_date` (date, not null), `principal_amount_cents` (bigint, not null), `interest_amount_cents` (bigint, not null), `total_amount_cents` (bigint, not null), `status` (string, not null, default "pending"), `payment_date` (date, nullable), `payment_mode` (string, nullable), `late_fee_cents` (bigint, not null, default 0), `completed_at` (datetime, nullable), `notes` (text, nullable), timestamps
  - [x] 1.2 Add indexes: `loan_id`, `status`, `due_date`, composite unique on `[loan_id, installment_number]`
  - [x] 1.3 Add FK constraint: `loan_id` references `loans`
  - [x] 1.4 Create `Payment` model with AASM, validations, scopes, associations, `has_paper_trail`, `monetize` on money columns
  - [x] 1.5 Run migration in both dev and test
- [x] Task 2: Add `has_many :payments` to `Loan` model (AC: #1)
  - [x] 2.1 Add `has_many :payments, dependent: :restrict_with_exception`
  - [x] 2.2 Add `#has_repayment_schedule?` convenience: `payments.exists?`
  - [x] 2.3 Add `#total_scheduled_amount` convenience: `payments.sum(:total_amount_cents)` (returns cents)
- [x] Task 3: Create `Loans::GenerateRepaymentSchedule` service (AC: #1, #2, #3)
  - [x] 3.1 Follow established `Result = Struct.new(:loan, :payments, :error, keyword_init: true)` with `success?` / `blocked?` pattern
  - [x] 3.2 Accept `loan:` parameter
  - [x] 3.3 Guard: return blocked if loan is not in `active` state
  - [x] 3.4 Guard: return blocked if loan already has payments (idempotency)
  - [x] 3.5 Guard: return blocked if loan financial details are incomplete (principal, tenure, frequency, interest)
  - [x] 3.6 Calculate total interest based on `interest_mode` (rate → simple interest; total_interest_amount → direct value)
  - [x] 3.7 Calculate installment count and due dates based on `repayment_frequency` and `tenure_in_months` starting from `disbursement_date`
  - [x] 3.8 Split total repayment (principal + interest) into equal installments with last installment absorbing rounding remainder
  - [x] 3.9 Create Payment records inside `Payment.transaction { }` (nested savepoint when called from Disburse; standalone transaction otherwise), all with status "pending"
  - [x] 3.10 Return `Result.new(loan:, payments:)` on success
- [x] Task 4: Integrate schedule generation into `Loans::Disburse` (AC: #1)
  - [x] 4.1 After invoice creation and ledger posting inside the `DoubleEntry.lock_accounts` block, call `Loans::GenerateRepaymentSchedule.call(loan: loan)`
  - [x] 4.2 If schedule generation returns blocked, raise `ActiveRecord::Rollback` with the error message (rolls back entire disbursement)
  - [x] 4.3 Extend the `Result` struct to include `payments` field
  - [x] 4.4 Update the success return to include generated payments
- [x] Task 5: Update loan show page — repayment schedule section (AC: #1)
  - [x] 5.1 Add a "Repayment Schedule" section on `loans/show.html.erb` — placement: after the disbursement summary section, visible only when loan has payments
  - [x] 5.2 Show schedule summary: number of installments, frequency, first/last due dates, total scheduled amount
  - [x] 5.3 Show installment table: installment #, due date, principal portion, interest portion, total amount, status badge
  - [x] 5.4 Preload `:payments` in controller `set_loan` includes for N+1 prevention
- [x] Task 6: Update route and controller for schedule visibility (AC: #1)
  - [x] 6.1 No new routes needed — schedule is visible on existing `loans#show`
  - [x] 6.2 Expose `@loan.payments.ordered` for the view
- [x] Task 7: Create `spec/factories/payments.rb` (AC: #1, #2, #3)
  - [x] 7.1 Factory with proper loan association, auto-incrementing installment_number, realistic defaults
  - [x] 7.2 Trait `:pending` (default), `:completed`, `:overdue` for state variants
- [x] Task 8: Write tests (AC: #1, #2, #3)
  - [x] 8.1 Model specs for `Payment`: validations, associations, scopes, AASM states and allowed transitions, `editable?`
  - [x] 8.2 Model specs for `Loan`: `has_many :payments`, `has_repayment_schedule?`, `total_scheduled_amount`
  - [x] 8.3 Service specs for `Loans::GenerateRepaymentSchedule`: successful generation with monthly frequency, bi-weekly frequency, weekly frequency; rate-based interest calculation; total-interest-amount-based calculation; installment amounts sum to total; last installment absorbs rounding; blocked when not active; blocked when schedule already exists; blocked when details incomplete
  - [x] 8.4 Service specs for `Loans::Disburse` (updated): verify payments are created as part of disbursement; verify rollback if schedule generation fails
  - [x] 8.5 Request specs for `loans#show`: verify schedule section visible for active loans with payments; verify schedule section absent for pre-disbursement loans
  - [x] 8.6 Run full `bundle exec rspec` before marking complete

### Review Findings

- [x] [Review][Patch] Installment totals do not follow the specified equal-total split when both principal and interest have remainders [`app/services/loans/generate_repayment_schedule.rb:99`]
- [x] [Review][Patch] Negative interest inputs can raise during schedule generation instead of returning a blocked result [`app/services/loans/generate_repayment_schedule.rb:62`]
- [x] [Review][Patch] Tiny repayment amounts can generate zero-value installments that fail validation and abort the schedule with an exception [`app/services/loans/generate_repayment_schedule.rb:99`]
- [x] [Review][Patch] Concurrent schedule generation can hit the unique index and raise instead of behaving idempotently [`app/services/loans/generate_repayment_schedule.rb:17`]

## Dev Notes

### Epic 5 Cross-Story Context

- **Epic 5** covers repayment servicing, overdue control, and loan closure (FR40–FR56, FR72).
- **Story 5.1** is the foundation — it creates the `Payment` model and schedule generation that ALL subsequent stories depend on.
- **5.2** will add filtered list views (upcoming/overdue payments, repayment state on loan detail).
- **5.3** will add `mark_completed` with guarded confirmation, payment date/mode, and locking.
- **5.4** will add payment invoices and `double_entry` postings for completed payments.
- **5.5** will add overdue derivation (automatic state changes based on due dates).
- **5.6** will add late fees and automatic loan closure.
- **Do NOT** implement payment completion, overdue logic, late fees, or loan closure in this story.

### Critical Architecture Constraints

- **Domain services own all financial calculations.** Schedule generation belongs in `app/services/loans/generate_repayment_schedule.rb` — the controller must NOT perform installment calculations directly. [Source: architecture.md — "Domain logic boundaries"]
- **Anti-pattern:** "Calculating repayment schedules inside a controller action." [Source: architecture.md — Pattern Examples]
- **AASM for Payment lifecycle.** Payment is a lifecycle-driven entity with states: pending → completed, pending → overdue, overdue → completed. Use AASM consistent with `Loan` model. [Source: architecture.md — "aasm for canonical workflow state transitions"]
- **Service result pattern.** Follow the established `Result = Struct.new(:fields, :error, keyword_init: true)` with `success?` / `blocked?`. See `Loans::Disburse`, `Invoices::IssueDisbursementInvoice` for canonical examples. [Source: existing services]
- **UUID primary keys.** The `payments` table MUST use `id: :uuid`. All domain entities use UUID PKs. [Source: architecture.md — UUID identity strategy]
- **`money-rails` for amounts.** Use `monetize` on `principal_amount_cents`, `interest_amount_cents`, `total_amount_cents`, `late_fee_cents`. Follow the `Loan` pattern (no explicit `currency` column — use app default INR), NOT the `Invoice` pattern (which has a `currency` column). [Source: Gemfile line 74 — `money-rails ~> 3.0`]
- **`paper_trail` for audit.** Add `has_paper_trail` to `Payment`. PaperTrail whodunnit is already configured. [Source: prd.md — FR68, FR69]
- **No hard delete.** Never destroy payment records. [Source: prd.md — FR70]
- **Deterministic, testable calculation.** "Repayment generation... should be implemented in deterministic, independently testable domain services rather than being distributed across UI logic or incidental persistence hooks." [Source: architecture.md — Cross-Cutting Concerns]
- **Financial consistency NFR.** "Principal, charges, late fees, scheduled repayment, completed payments, overdue status, and closure status shall remain internally consistent with zero unreconciled mismatches." [Source: prd.md — Non-Functional Requirements]

### Payment Model Design

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | uuid | no | `gen_random_uuid()` | PK |
| `loan_id` | uuid | no | — | FK to loans |
| `installment_number` | integer | no | — | 1-based position within loan |
| `due_date` | date | no | — | Calculated from disbursement_date + frequency |
| `principal_amount_cents` | bigint | no | — | Principal portion of this installment |
| `interest_amount_cents` | bigint | no | — | Interest portion of this installment |
| `total_amount_cents` | bigint | no | — | = principal + interest (scheduled payment) |
| `status` | string | no | "pending" | AASM: pending, completed, overdue |
| `payment_date` | date | yes | nil | Actual payment date (set in Story 5.3) |
| `payment_mode` | string | yes | nil | How payment was received (Story 5.3) |
| `late_fee_cents` | bigint | no | 0 | Late fee applied (Story 5.6) |
| `completed_at` | datetime | yes | nil | When marked completed (Story 5.3) |
| `notes` | text | yes | nil | Optional notes |
| `created_at` | datetime | no | — | |
| `updated_at` | datetime | no | — | |

Indexes: `loan_id`, `status`, `due_date`, unique composite `[loan_id, installment_number]`.

### Payment AASM Design

```ruby
aasm column: :status, whiny_transitions: true do
  state :pending, initial: true
  state :completed
  state :overdue

  event :mark_completed do
    transitions from: [:pending, :overdue], to: :completed
  end

  event :mark_overdue do
    transitions from: :pending, to: :overdue
  end
end
```

Only the `pending` initial state is exercised in this story. The `mark_completed` event (Story 5.3) and `mark_overdue` event (Story 5.5) are defined now to avoid AASM migration later but are NOT used yet.

### Schedule Generation Algorithm

**Interest calculation:**
- If `interest_mode == "rate"`: `total_interest_cents = (principal_amount_cents * interest_rate * tenure_in_months / (100 * 12)).round` (simple interest, annual rate)
- If `interest_mode == "total_interest_amount"`: `total_interest_cents = total_interest_amount_cents`
- The mutual exclusivity of rate vs total_interest_amount is already enforced by `Loan#validate_interest_details` — do NOT re-validate in the schedule service.
- **Precision:** `interest_rate` is `decimal(8,4)` (BigDecimal in Ruby). Multiply numerator terms first before dividing to minimize intermediate rounding: `(cents * rate * months) / (100 * 12)` then `.round` for the final integer cents value.

**Installment count:**
- Monthly: `tenure_in_months` installments
- Bi-weekly / Weekly: Count payment dates from `disbursement_date + period` to `disbursement_date + tenure_in_months.months` (inclusive)

**Due date generation:**
- Monthly: `disbursement_date + n.months` for n = 1..tenure_in_months
- Bi-weekly: Start at `disbursement_date + 2.weeks`, increment by `2.weeks`, stop at `disbursement_date + tenure_in_months.months`
- Weekly: Start at `disbursement_date + 1.week`, increment by `1.week`, stop at `disbursement_date + tenure_in_months.months`

**Amount splitting (per installment):**
```
total_repayment_cents = principal_amount_cents + total_interest_cents
base_total_per = total_repayment_cents / num_installments
base_principal_per = principal_amount_cents / num_installments
base_interest_per = total_interest_cents / num_installments

# Last installment absorbs rounding remainders
last_total = total_repayment_cents - (base_total_per * (num_installments - 1))
last_principal = principal_amount_cents - (base_principal_per * (num_installments - 1))
last_interest = total_interest_cents - (base_interest_per * (num_installments - 1))
```

**Consistency invariant:** Sum of all `total_amount_cents` across installments MUST equal `principal_amount_cents + total_interest_cents`. Sum of all `principal_amount_cents` MUST equal `loan.principal_amount_cents`. Sum of all `interest_amount_cents` MUST equal calculated `total_interest_cents`. Test this explicitly.

### Integration with `Loans::Disburse`

The existing `Loans::Disburse` service currently:
1. Locks accounts + loan row
2. Validates state and readiness
3. Sets `disbursement_date`, fires `disburse!` (AASM)
4. Creates disbursement invoice
5. Posts `DoubleEntry.transfer`

**Modification:** After step 5 (inside the `DoubleEntry.lock_accounts` block), add:
```ruby
schedule_result = Loans::GenerateRepaymentSchedule.call(loan: loan)
if schedule_result.blocked?
  raise ActiveRecord::Rollback, schedule_result.error
end
payments = schedule_result.payments
```

If schedule generation fails, the `ActiveRecord::Rollback` rolls back the entire disbursement (AASM state, invoice, ledger entries, payments). This matches the existing pattern used for invoice failure.

**Result struct update:** Extend to `Result = Struct.new(:loan, :invoice, :payments, :error, keyword_init: true)`. The controller only uses `success?` and `error`, so adding `payments` is backward-compatible.

**Important:** The schedule service runs inside `DoubleEntry.lock_accounts` but does not itself post ledger entries. This is correct — schedule generation is not a money movement. The lock scope provides the transaction boundary. Repayment-related ledger postings happen in Story 5.4.

### Loan Show Page — Repayment Schedule Section

**Placement:** After the disbursement summary card, before "Loan details (locked)". Visible only when `loan.has_repayment_schedule?`.

**Schedule summary card:**
- Repayment frequency (e.g., "Monthly")
- Number of installments
- First payment due date
- Last payment due date
- Total scheduled amount (formatted with `humanized_money_with_symbol`)

**Installment table:**
| # | Due Date | Principal | Interest | Total | Status |
|---|----------|-----------|----------|-------|--------|
| 1 | 2026-05-16 | ₹3,750.00 | ₹468.75 | ₹4,218.75 | Pending |
| ... | ... | ... | ... | ... | ... |
| 12 | 2026-04-16 | ₹3,750.00 | ₹468.75 | ₹4,218.75 | Pending |

Follow the existing loan show page section pattern: `<section>` with rounded-3xl card, heading, content.

### Library / Framework Requirements

- **Rails ~> 8.1** — migrations, Active Record, `button_to`, view rendering
- **AASM ~> 5.5** — `Payment` state machine with `pending`, `completed`, `overdue` states
- **money-rails ~> 3.0** — `monetize` on four cents columns; use `humanized_money_with_symbol` in views
- **paper_trail ~> 17.0** — add `has_paper_trail` to Payment
- **double_entry ~> 2.0** — no NEW accounts or transfers in this story; schedule generation runs inside existing `DoubleEntry.lock_accounts` block but does not post entries
- **FactoryBot ~> 6.5** — payment factory with loan association and state traits

### File Structure (Expected Touchpoints)

| Area | Files |
|------|--------|
| New | `db/migrate/YYYYMMDDHHMMSS_create_payments.rb` |
| New | `app/models/payment.rb` |
| New | `app/services/loans/generate_repayment_schedule.rb` |
| New | `spec/factories/payments.rb` |
| New | `spec/models/payment_spec.rb` |
| New | `spec/services/loans/generate_repayment_schedule_spec.rb` |
| Modify | `app/models/loan.rb` — add `has_many :payments`, `has_repayment_schedule?`, `total_scheduled_amount` |
| Modify | `app/services/loans/disburse.rb` — call schedule generation, extend Result struct |
| Modify | `app/controllers/loans_controller.rb` — update `set_loan` includes to preload `:payments` |
| Modify | `app/views/loans/show.html.erb` — add repayment schedule section |
| Modify | `spec/models/loan_spec.rb` — payment association, convenience methods |
| Modify | `spec/services/loans/disburse_spec.rb` — verify schedule generation in disbursement |
| Modify | `spec/requests/loans_spec.rb` — verify schedule section in show response |
| Modify | `spec/factories/loans.rb` — ensure `:active` + `:with_details` trait combination works for schedule tests |

### Files NOT to Create or Modify

- Do NOT create `app/controllers/payments_controller.rb` — payment list/detail views belong to Story 5.2.
- Do NOT create `app/services/payments/mark_completed.rb` — belongs to Story 5.3.
- Do NOT create `app/services/invoices/issue_payment_invoice.rb` — belongs to Story 5.4.
- Do NOT modify `config/initializers/double_entry.rb` — no new accounts or transfers needed for schedule generation.
- Do NOT add payment completion, overdue detection, late fee, or closure logic.
- Do NOT add dashboard widgets or payment list views — belongs to Stories 5.2 and 6.1.
- Do NOT create `app/jobs/overdue_recalculation_job.rb` — belongs to Story 5.5.
- Do NOT extend `Invoice::INVOICE_TYPES` with "payment" — belongs to Story 5.4.

### Existing Patterns to Follow

1. **Service result pattern** — match `Loans::Disburse` and `Invoices::IssueDisbursementInvoice`:
   ```ruby
   Result = Struct.new(:loan, :payments, :error, keyword_init: true) do
     def success?
       error.blank?
     end

     def blocked?
       error.present?
     end
   end
   ```

2. **AASM pattern** — match `Loan` model exactly: `include AASM`, `aasm column: :status, whiny_transitions: true`, states as symbols

3. **Money columns** — match `Invoice` and `Loan`: `monetize :*_cents`, bigint storage, "INR" currency. Use `humanized_money_with_symbol` in views.

4. **Table-lock numbering** — NOT needed for payments (installment_number is deterministic from calculation, not a global sequence)

5. **View section pattern** — match existing loan show sections: `<section>` with Tailwind `rounded-3xl` card, heading, `dl` grid or `table` for data

6. **Preloading pattern** — add `:payments` to `set_loan` includes chain alongside existing `:borrower`, `:loan_application`, `:invoices`, `document_uploads`

7. **Flash message tone** — the existing disbursement success flash already says "repayment tracking begins" — no change needed

8. **Controller thin** — no new controller actions. Schedule is created by service; visible on existing `loans#show`.

### UX Requirements

- **Repayment schedule section** should follow the "entity detail section" pattern: clean heading, structured data, readable table. [Source: ux-design-specification.md — Entity Header / Summary Block, Data Table Wrapper]
- **Status badges** for installment status (all "Pending" in this story) should use the lifecycle status badge component with muted/default tone. [Source: ux-design-specification.md — Lifecycle Status Badge]
- **Money formatting** must be consistent with existing loan views — use `humanized_money_with_symbol`. [Source: existing `loans/show.html.erb` patterns]
- **No guarded confirmations needed** in this story — schedule is generated automatically. Guarded confirmations appear in Story 5.3 for payment completion.
- **Section visibility** — only show schedule section when `loan.has_repayment_schedule?`. Pre-disbursement loans must NOT show an empty schedule section.

### Previous Story Intelligence

- **`DoubleEntry.lock_accounts` as outermost boundary:** Story 4.5 discovered that `with_lock` inside `DoubleEntry.lock_accounts` causes nested transaction issues. The current `Loans::Disburse` uses `DoubleEntry.lock_accounts` + `loan.lock!` (not `with_lock`). The schedule generation service runs inside this same block — do NOT introduce a new `with_lock` or `ActiveRecord::Base.transaction` inside the schedule service. Let the outer `DoubleEntry.lock_accounts` provide the transaction. [Source: Story 4.5 Debug Log]
- **Rollback on sub-service failure:** Story 4.5 established the pattern of `raise ActiveRecord::Rollback, message` when a sub-service fails inside the lock block, then checking the result outside to return a blocked Result. Follow this exact pattern for schedule generation failure. [Source: `app/services/loans/disburse.rb` lines 38-40]
- **N+1 in `set_loan`:** Each story adds to the includes chain. Current: `:borrower, :loan_application, :invoices, document_uploads: [...]`. Add `:payments` to this. [Source: `app/controllers/loans_controller.rb`]
- **Factory trait composition:** Tests should use `create(:loan, :active, :with_details)` to get a loan with both active status and financial details needed for schedule generation. Verify this trait combination works. [Source: `spec/factories/loans.rb`]
- **Test count:** Full suite was 312 examples at 4.5 completion. Keep green after all additions. [Source: Story 4.5 Completion Notes]

### Git Intelligence

Recent commits follow this pattern:
- `af1d56d` Add guarded disbursement financial records and invoice handling.
- `d3fb90f` Add disbursement readiness evaluation before disbursement.
- `15d78cb` Add loan documentation management before disbursement.

Preferred commit style: `"Add repayment schedule generation from loan disbursement."`

### Epic 4 Retrospective Insights (Apply to This Story)

1. **"Money-moving stories need explicit transaction boundaries"** — Schedule generation is inside the Disburse lock block. Not money-moving itself, but must be atomic with disbursement. [Source: Epic 4 Retro — Key insights]
2. **"Facts not toggles"** — The schedule is generated from loan facts (principal, tenure, frequency, interest). Installment amounts are calculated deterministically, not set manually. [Source: Epic 4 Retro — Significant discoveries]
3. **"Review patches are part of delivery"** — Expect review to surface rounding edge cases, frequency boundary conditions, or interest calculation precision issues. Plan for them. [Source: Epic 4 Retro — Key insights]
4. **"Keep loan work on shared list/detail/detail-workspace patterns"** — The schedule section lives on the existing loan show page, extending the single-workspace pattern. [Source: Epic 4 Retro — Action items]
5. **"Ledger conventions for Epic 5"** — This story does NOT post ledger entries. Payment-related postings come in Story 5.4. Keep DoubleEntry config unchanged. [Source: Epic 4 Retro — Preparation tasks]

### Calculation Edge Cases to Test

1. **Rate-based interest, monthly:** 45000 principal, 12.5% annual rate, 12 months → interest = 5625, total = 50625, 12 installments of 4218.75 (no remainder)
2. **Rate-based interest, rounding:** 50000 principal, 10% rate, 6 months → interest = 2500, total = 52500, 6 installments. 52500/6 = 8750.0 (clean division)
3. **Total-interest-amount mode:** 45000 principal, 8000 total interest, 12 months → total = 53000, 12 installments. 53000/12 = 4416.666... → 11 installments of 4416 cents + 1 of 4424 cents
4. **Bi-weekly frequency:** 12-month tenure from 2026-04-16 → end date 2027-04-16. First due: 2026-04-30, every 2 weeks → count dates to verify ~26 installments
5. **Weekly frequency:** Same tenure → ~52 installments
6. **Single installment:** 1-month tenure, monthly → 1 installment with full amount
7. **Idempotency:** Calling generate twice returns blocked (schedule already exists)
8. **Incomplete details:** Loan without principal/tenure/frequency returns blocked

### `double_entry` Account Expectations (for Future Stories)

Currently configured accounts (from Story 4.5):
- `loan_receivable` (positive_only, loan-scoped): What the borrower owes
- `disbursement_clearing` (loan-scoped): Clearing account for funds out

Story 5.4 will need:
- `repayment_received` or `payment_clearing` (loan-scoped): For incoming payment postings
- Transfer: from `repayment_received` to `loan_receivable` (reducing the receivable)

This story does NOT add these accounts. Mentioned here so the developer understands the future integration point.

### Project Context Reference

- No `project-context.md` found in repo; rely on PRD, architecture, epics, and this file.

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

### Implementation Plan

- Add focused failing specs first for the new payment domain model, repayment schedule service, disbursement integration, and loan show visibility.
- Introduce the `payments` table with UUID identity, repayment scheduling fields, indexes, and foreign key constraints, then implement the `Payment` model with AASM, PaperTrail, money columns, scopes, and editability helpers.
- Extend `Loan` with payment associations and summary helpers, then build `Loans::GenerateRepaymentSchedule` to deterministically calculate installment dates and amounts from disbursement facts without adding ledger movement.
- Integrate repayment schedule creation into `Loans::Disburse` inside the existing lock boundary so invoice creation, accounting entries, activation, and payment creation remain atomic.
- Expose ordered payments on the existing loan detail page, render a repayment schedule summary and table only for loans that already have generated payments, and finish with migrations plus full spec validation.

### Completion Notes List

- Added the `payments` persistence layer with UUID identity, repayment scheduling fields, database indexes, foreign key enforcement, money-rails columns, PaperTrail tracking, and AASM lifecycle support.
- Added `Loan#has_repayment_schedule?` and `Loan#total_scheduled_amount`, then implemented `Loans::GenerateRepaymentSchedule` to build deterministic monthly, bi-weekly, and weekly schedules from disbursement facts.
- Integrated repayment schedule generation into `Loans::Disburse` so loan activation, invoice creation, ledger posting, and payment creation now succeed or roll back together.
- Extended the loan detail workspace to preload ordered payments and render a repayment schedule summary plus installment table only when generated payments exist.
- Added factories and automated coverage for the payment model, loan helpers, schedule generator, disbursement integration, and loan show visibility; verified with full RSpec and RuboCop.

### File List

- `app/controllers/loans_controller.rb`
- `app/models/loan.rb`
- `app/models/payment.rb`
- `app/services/loans/disburse.rb`
- `app/services/loans/generate_repayment_schedule.rb`
- `app/views/loans/show.html.erb`
- `db/migrate/20260416215225_create_payments.rb`
- `db/schema.rb`
- `spec/factories/payments.rb`
- `spec/models/loan_spec.rb`
- `spec/models/payment_spec.rb`
- `spec/requests/loans_spec.rb`
- `spec/services/loans/disburse_spec.rb`
- `spec/services/loans/generate_repayment_schedule_spec.rb`

## Change Log

- 2026-04-16: Added repayment schedule generation from loan disbursement, including the new payment model, loan workspace visibility, and regression coverage.
