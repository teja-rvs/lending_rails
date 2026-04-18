# Story 5.4: Generate Payment Financial Records and Preserve the Accounting Boundary

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want completed repayments to produce the required financial records without mixing operational and accounting responsibilities,
So that repayment tracking remains trustworthy and financially traceable.

## Acceptance Criteria

1. **Given** a payment has been marked completed successfully
   **When** the system finalizes that payment event
   **Then** it creates the corresponding payment invoice automatically
   **And** links the invoice to the relevant lending records

2. **Given** the product tracks money movement across disbursements and repayments
   **When** repayment financial records are created
   **Then** operational workflow records and accounting-posting responsibilities remain clearly separated
   **And** any accounting-side posting rules are executed only through approved money-moving domain services

3. **Given** a financial event has been completed
   **When** the admin investigates the related records later
   **Then** the system preserves a clear relationship between borrower, loan, payment, invoice, and audit context
   **And** the product remains the operational source of truth

## Tasks / Subtasks

- [x] Task 1: Extend invoice vocabulary and payment linkage (AC: #1, #3)
  - [x] 1.1 Create migration `db/migrate/20260418191434_add_payment_reference_to_invoices.rb` (nullable FK, safety_assured).
  - [x] 1.2 Update `app/models/invoice.rb` — INVOICE_TYPES += "payment", `belongs_to :payment, optional: true`, `:payment` scope, conditional presence + disbursement-absence validations.
  - [x] 1.3 Update `app/models/payment.rb` — `has_one :invoice, dependent: :restrict_with_exception`.
  - [x] 1.4 Update `app/models/loan.rb` — added `payment_invoices` helper (invoices.payment.ordered).
  - [x] 1.5 Update `spec/factories/invoices.rb` — added `:payment` trait composing a `:completed` payment.

- [x] Task 2: Define repayment ledger account and transfer (AC: #2)
  - [x] 2.1 Extend `config/initializers/double_entry.rb` — added `:repayment_received` account and `:repayment` transfer.
  - [x] 2.2 No existing accounts/transfers modified.
  - [x] 2.3 No schema migration required; initializer-only.

- [x] Task 3: Create `Invoices::IssuePaymentInvoice` service (AC: #1, #3)
  - [x] 3.1 Created `app/services/invoices/issue_payment_invoice.rb`.
  - [x] 3.2 Mirrors `IssueDisbursementInvoice` shape (Result struct, keyword_init).
  - [x] 3.3 Guards: payment-must-be-completed, invoice-already-exists idempotency.
  - [x] 3.4 Uses `Invoice.create_with_next_invoice_number!` with payment/loan linkage.
  - [x] 3.5 Success returns `Result.new(invoice:)`; blocked returns Result with error.
  - [x] 3.6 No DoubleEntry posting inside the service.
  - [x] 3.7 No lock_accounts / with_lock inside the service.

- [x] Task 4: Compose completion + invoice + ledger posting into `Loans::RecordRepayment` (AC: #1, #2, #3)
  - [x] 4.1 Create `app/services/loans/record_repayment.rb` extending `ApplicationService`. This is the NEW top-level money-moving service the controller will call; `Payments::MarkCompleted` remains the pure state-transition primitive and is composed here
  - [x] 4.2 Result: `Result = Struct.new(:payment, :invoice, :error, keyword_init: true) do def success? = error.blank?; def blocked? = error.present?; end`
  - [x] 4.3 Constructor: `def initialize(payment:, payment_date:, payment_mode:, notes: nil)` — identical signature to `Payments::MarkCompleted` (controller contract does not change shape)
  - [x] 4.4 Mirror the `Loans::Disburse` outer-boundary pattern verbatim:
    ```ruby
    def call
      loan = payment.loan
      receivable = DoubleEntry.account(:loan_receivable, scope: loan)
      repayment  = DoubleEntry.account(:repayment_received, scope: loan)

      invoice = nil
      failure_message = nil

      DoubleEntry.lock_accounts(receivable, repayment) do
        completion = Payments::MarkCompleted.call(
          payment: payment,
          payment_date: @payment_date,
          payment_mode: @payment_mode,
          notes: @notes
        )
        if completion.blocked?
          failure_message = completion.error
          raise ActiveRecord::Rollback, completion.error
        end

        invoice_result = Invoices::IssuePaymentInvoice.call(payment: payment)
        if invoice_result.blocked?
          failure_message = invoice_result.error
          raise ActiveRecord::Rollback, invoice_result.error
        end
        invoice = invoice_result.invoice

        DoubleEntry.transfer(
          Money.new(payment.total_amount_cents, "INR"),
          from: receivable,
          to: repayment,
          code: :repayment,
          metadata: { loan_id: loan.id, payment_id: payment.id, invoice_id: invoice.id }
        )
      end

      if invoice.present?
        Result.new(payment: payment, invoice: invoice)
      else
        blocked(failure_message || "Repayment could not be recorded.")
      end
    end
    ```
  - [x] 4.5 `Payments::MarkCompleted` MUST remain unchanged in behavior. It already takes `payment.with_lock` internally; `with_lock` is safe INSIDE `DoubleEntry.lock_accounts` (nested row lock inside the outer table lock matches the Story 4.5 precedent — the banned pattern is `lock_accounts` INSIDE another transaction/lock, not the reverse)
  - [x] 4.6 Rollback semantics: any block raised inside `lock_accounts` triggers `ActiveRecord::Rollback`, undoing the AASM transition, the invoice insert, the whodunnit version row, AND any half-posted DoubleEntry lines. Tests MUST assert this end-to-end (see Task 8.4)
  - [x] 4.7 Do NOT rescue `DoubleEntry` exceptions — let them propagate; they indicate a bug, not user error. The existing `MarkCompleted` guards catch user-error paths before the ledger posting
  - [x] 4.8 Do NOT add a `loan.refresh_status` / overdue derivation / close step here — those are Story 5.5 and 5.6 respectively. Successful repayment must not attempt a loan-state transition in this story; the loan remains `active` (or `overdue` if previously in that state — 5.5 will handle back-flip)

- [x] Task 5: Rewire controller to the new composer (AC: #1, #2)
  - [x] 5.1 In `app/controllers/payments_controller.rb#mark_completed`, replace the call to `Payments::MarkCompleted.call(...)` with `Loans::RecordRepayment.call(...)`. Keep the parameter shape identical (`payment:`, `payment_date:`, `payment_mode:`, `notes:`) — zero UI behavior change for the admin
  - [x] 5.2 Keep the existing success/alert branches, flash copy, `render :show, status: :unprocessable_content`, and `from:` breadcrumb preservation — all untouched
  - [x] 5.3 Do NOT create new controller actions. Do NOT add an `invoices#show` route or controller in this story — surfaces live on the payment detail and loan detail pages (Task 6)
  - [x] 5.4 Do NOT loosen strong params — `completion_params` still permits only `:payment_date, :payment_mode, :notes`

- [x] Task 6: Surface the payment invoice on existing detail views (AC: #1, #3)
  - [x] 6.1 In `app/views/payments/show.html.erb`, extend the **locked-state summary card** (the `elsif @payment.completed?` branch around line 89) with a new `<dl>` row:
    - Label: "Payment invoice"
    - Value: the invoice's `invoice_number` (e.g. "INV-0007"), rendered as plain text (no link — no invoice detail page exists and none is added here). Fall back to "—" when `@payment.invoice.blank?` (only possible for legacy pre-5.4 completed payments)
    - Place this row before the "Notes" row so operational context (who/when/invoice#) clusters together
  - [x] 6.2 In `app/views/loans/show.html.erb` inside the repayment schedule table, extend each row to show the invoice number for completed installments. Add a new `<th>`/`<td>` column header "Invoice" positioned after the "Status" column; render `payment.invoice&.invoice_number || "—"`. Preserve all existing columns and row links unchanged
  - [x] 6.3 In `app/views/loans/show.html.erb` disbursement summary panel (the post-disbursement "Disbursement" card that already shows `disbursement_invoice.invoice_number`), DO NOT change existing behavior. Payment invoices are surfaced per-installment in the repayment schedule table — not in the disbursement summary
  - [x] 6.4 Do NOT build a standalone invoices index/show page. Do NOT add an "Invoices" nav link. Do NOT render invoice records on `payments#index`. The invoice is supporting evidence on existing surfaces; a dedicated invoices surface is post-MVP
  - [x] 6.5 Accessibility / formatting: use the existing `<dl>`/`<table>` patterns already established on these pages; no new components needed

- [x] Task 7: Preserve the invoice boundary (AC: #2, #3)
  - [x] 7.1 Payment invoices are a fact of a completed payment. Do NOT expose any edit/destroy/regeneration action. The Invoice model's existing behavior (no `editable?`, no `readonly?`) is sufficient — the invoice is write-once because the ONLY code path that creates it is `Invoices::IssuePaymentInvoice`, which blocks on the `payment.invoice.present?` guard
  - [x] 7.2 Do NOT add `readonly?` to `Invoice` — that would break the `create!` path itself on future re-fetches. The "non-editable" contract is upheld by having no UI/controller that mutates invoices, not by AR `readonly?`
  - [x] 7.3 Do NOT delete or repurpose any existing invoice. All existing disbursement invoices must continue to satisfy all validations after this story (disbursement invoices have `payment_id = null` — covered by 1.1's `null: true` FK and 1.2's conditional presence validation)

- [x] Task 8: Tests (AC: #1, #2, #3)
  - [x] 8.1 `spec/services/invoices/issue_payment_invoice_spec.rb` (new) — mirror `issue_disbursement_invoice_spec.rb` shape:
    - Happy path: `Payments::MarkCompleted` the payment first (or use `:completed` trait), then call the service — returns `success?`, persisted invoice, `invoice_type == "payment"`, `amount_cents == payment.total_amount_cents`, `issued_on == payment.payment_date`, `invoice.payment == payment`, `invoice.loan == payment.loan`, `invoice_number =~ /\AINV-\d{4,}\z/`
    - Blocked when the payment is NOT completed (pending / overdue) → `include("must be completed")`
    - Idempotency: calling twice returns blocked on the second call with `include("already exists")`; only one invoice row is created; `payment.invoice` is unchanged
    - Sequential numbering: after a disbursement invoice INV-0001 exists on another loan, a new payment invoice on a different loan becomes INV-0002 (shared sequence)
  - [x] 8.2 `spec/services/loans/record_repayment_spec.rb` (new) — happy path and atomicity:
    - Success: pending payment + valid date + valid mode → `success?`, `result.payment.completed?`, `result.invoice.persisted?`, `result.invoice.invoice_type == "payment"`, `result.invoice.payment == result.payment`
    - Ledger balances after success: `DoubleEntry.account(:loan_receivable, scope: loan).balance == Money.new(loan.principal_amount_cents - payment.total_amount_cents, "INR")` (receivable decremented by the installment total); `DoubleEntry.account(:repayment_received, scope: loan).balance == Money.new(-payment.total_amount_cents, "INR")`
    - Ledger metadata: `DoubleEntry::Line.where(account: "repayment_received", scope: loan.id).last.metadata` contains `loan_id`, `payment_id`, `invoice_id` with correct values
    - Blocked path propagates service errors: supply invalid `payment_mode` → `result.blocked?`, error message matches `MarkCompleted`'s wording, NO invoice created, NO ledger lines created, payment stays pending (full rollback)
    - Atomicity: stub `Invoices::IssuePaymentInvoice` to return blocked (e.g. simulate a numbering collision) → AASM transition is rolled back (`payment.reload` still `pending?`), NO invoice exists, NO ledger lines exist. Use `allow(Invoices::IssuePaymentInvoice).to receive(:call).and_return(Invoices::IssuePaymentInvoice::Result.new(invoice: nil, error: "fake failure"))`
    - Idempotent contract: invoking twice on the same payment → second call blocked with the `MarkCompleted` "already been completed" message; ledger balance unchanged after the second call; invoice count on the payment stays at 1
    - Uses `DoubleEntry.lock_accounts` as the outer boundary: `expect(DoubleEntry).to receive(:lock_accounts).and_call_original`
  - [x] 8.3 `spec/models/invoice_spec.rb` (extend existing):
    - `INVOICE_TYPES` includes "payment"
    - `belongs_to :payment` optional; present when `invoice_type == "payment"`, absent when `invoice_type == "disbursement"`
    - `scope :payment` returns only payment invoices
    - Disbursement invoice with a non-nil `payment_id` is invalid (guard from Task 1.2)
    - Payment invoice with a nil `payment_id` is invalid
  - [x] 8.4 `spec/models/payment_spec.rb` (extend existing):
    - `has_one :invoice` association resolves to the payment invoice, not to any disbursement invoice on the same loan
    - `dependent: :restrict_with_exception` raises `ActiveRecord::DeleteRestrictionError` on `payment.destroy` when an invoice exists
  - [x] 8.5 `spec/requests/payments_spec.rb` (extend existing, do NOT create a new file):
    - Successful `PATCH /payments/:id/mark_completed` now creates a payment invoice: assert `Invoice.payment.where(payment_id: payment.id).count` goes from 0 to 1 around the request
    - Successful completion posts ledger lines: assert `DoubleEntry::Line.where(account: "repayment_received", scope: loan.id).count` is incremented; assert matching `loan_receivable` debit line
    - Flash notice copy is unchanged from Story 5.3 — no regression. The admin sees the same success message; the invoice is supporting evidence on the detail page
    - Invoice number appears in the rendered `GET /payments/:id` response after completion (assert on response body for `INV-`)
    - Blocked completion (missing `payment_date`) still renders `:show` with `:unprocessable_content`; assert NO invoice is created and NO ledger lines are posted (regression guard for the rollback)
  - [x] 8.6 `spec/requests/loans_spec.rb` (extend existing): the loan detail page renders the new "Invoice" column in the repayment schedule; a completed installment shows its invoice number; a pending installment shows "—"
  - [x] 8.7 `spec/factories/invoices.rb` additions from Task 1.5 are covered by the Invoices specs (no dedicated factory spec needed — existing pattern)
  - [x] 8.8 Run `bundle exec rspec` green; run `bundle exec rubocop` green on all touched files before marking done. Expect example count to grow by roughly 20–30

## Review Findings

_Code review: 2026-04-18 (Blind Hunter + Edge Case Hunter + Acceptance Auditor)._

- [x] [Review][Patch] Add a DB unique index on `invoices.payment_id` (partial, WHERE payment_id IS NOT NULL) to prevent concurrent duplicate payment invoices for the same payment [db/migrate/20260418192000_add_unique_index_on_invoices_payment_id.rb] — Applied: new migration adds a partial unique index `index_invoices_on_payment_id_unique_when_present` (CONCURRENTLY, via `disable_ddl_transaction!`) so the idempotency guard is enforced at the DB level even when `IssuePaymentInvoice` is called outside the `DoubleEntry.lock_accounts` composition.
- [x] [Review][Patch] Add spec for backdated `payment_date` → `invoice.issued_on` equals that date (Dev Notes Edge Case #2) [spec/services/invoices/issue_payment_invoice_spec.rb] — Applied: added "inherits issued_on from a backdated payment_date (fact, not today)".
- [x] [Review][Patch] Add spec for PaperTrail whodunnit on invoice creation (Dev Notes Edge Case #9) [spec/requests/payments_spec.rb] — Applied: added "captures the signed-in admin as PaperTrail whodunnit on the invoice creation version" alongside the existing payment whodunnit test.
- [x] [Review][Patch] Add spec for two consecutive repayments on the same loan (Dev Notes Edge Case #6) [spec/services/loans/record_repayment_spec.rb] — Applied: added "accumulates invoices and ledger balances across two consecutive repayments" verifying `Invoice.payment.where(loan:).count == 2`, `loan_receivable.balance == principal - total1 - total2`, and `repayment_received.balance == total1 + total2`.
- [x] [Review][Defer] Add cross-loan isolation spec for `loan_receivable` / `repayment_received` scopes (Dev Notes Edge Case #7) [spec/services/loans/record_repayment_spec.rb] — deferred, intrinsic to `DoubleEntry.account(scope: loan)`; value-to-effort is low given the `scope_identifier: loan_scope` invariant and the existing disburse-spec precedent. Reason: covered structurally by DoubleEntry's scope contract; no current code change threatens it.

## Dev Notes

### Epic 5 Cross-Story Context

- **Epic 5** covers repayment servicing, overdue control, and loan closure (FR40–FR56, FR72).
- **Story 5.1 (done)** — generated the payment schedule + `Loans::GenerateRepaymentSchedule`.
- **Story 5.2 (done)** — payments list/detail read surfaces + `payment_due_hint` helper + loan-show repayment summary.
- **Story 5.3 (done)** — `Payments::MarkCompleted` domain service + completion form + locked summary card + model `readonly?`. That story explicitly left the invoice + ledger work to 5.4 and called out the "Service extension points" this story builds on.
- **This story (5.4)** — adds the payment invoice fact, posts a `repayment_received` ledger transfer, and composes both behind a new `Loans::RecordRepayment` service that the controller calls. No UI workflow change for the admin (same form, same flash, same redirect); the surface change is the invoice number appearing in the locked summary + the loan repayment-schedule table.
- **5.5 (backlog)** — will derive overdue state from facts (due date + completed-or-not fact). It will likely need to re-run on completion; when it does, it will navigate around `Payment#readonly?` — that design decision belongs to 5.5. Do NOT prematurely widen `readonly?` in this story
- **5.6 (backlog)** — will close the loan when all payments are completed (and apply late fees). Do NOT auto-close the loan here even if the last payment completes. Loan closure is 5.6's concern; attempting it here would couple this story to loan-lifecycle work and break 5.6's scope

### Critical Architecture Constraints

- **`DoubleEntry.lock_accounts` is the OUTER transaction boundary for any money-moving service.** Any `AR` transaction / `with_lock` must be INSIDE `lock_accounts`, never outside. Story 4.5's debug log captured the `LockMustBeOutermostTransaction` failure mode exactly — mirror the `Loans::Disburse` structure. [Source: `app/services/loans/disburse.rb`, Epic 4 Retro — "`double_entry` + RSpec" line]
- **Only money-moving domain services post to `DoubleEntry`.** The controller, the model, and non-money services MUST NOT call `DoubleEntry.transfer` or `DoubleEntry.lock_accounts`. [Source: `_bmad-output/planning-artifacts/architecture.md#999-1001,1099`]
- **Service result pattern is canonical.** `Result = Struct.new(..., keyword_init: true) do def success?/blocked?; end`. Mirror `Loans::Disburse`, `Invoices::IssueDisbursementInvoice`, `Payments::MarkCompleted`. [Source: existing services under `app/services/`]
- **Invoice numbering is serialized.** Use `Invoice.create_with_next_invoice_number!` — it takes a table lock, computes the next number, and creates. Do NOT compute numbers in application code. [Source: `app/models/invoice.rb:31-36`]
- **Invoice amount unit.** `amount_cents` is a bigint; use `payment.total_amount_cents` directly. Do NOT convert to/from `Money` in the service. [Source: `db/migrate/20260416114826_create_invoices.rb`]
- **Issued-on date is the payment fact, not today.** `invoice.issued_on = payment.payment_date` so backdated payments produce historically correct invoices. [Source: FR49 + MVP principle "facts not toggles"]
- **Ledger transfer amount is the installment total.** Use `payment.total_amount_cents` (principal + interest). Late-fee handling is Story 5.6 and is NOT posted here. [Source: FR52-53 deferred to 5.6]
- **Ledger metadata carries the linkage.** `{ loan_id:, payment_id:, invoice_id: }` — the audit chain from ledger line → invoice → payment → loan is how FR67/FR68 compliance is evidenced. [Source: `app/services/loans/disburse.rb:52` precedent; PRD FR67-FR69]
- **`paper_trail` is the audit mechanism.** `Invoice has_paper_trail` is already declared. The `set_paper_trail_whodunnit` before_action on `ApplicationController` captures the acting admin for invoice creation in the request cycle — no explicit `PaperTrail.request` wrapping needed. [Source: `app/models/invoice.rb:5`, `app/controllers/application_controller.rb`]
- **Post-money records stay locked.** Completed payment = immutable (Story 5.3 `Payment#readonly?`). Issued invoice = immutable by convention (no UI/service exists to mutate it). Both uphold FR72/FR70. [Source: PRD FR70-FR72; NFR10]
- **No hard delete.** `payment.dependent: :restrict_with_exception` on `has_one :invoice` enforces this at the AR level. [Source: `app/models/loan.rb:17` precedent]

### Files NOT to Create or Modify

- Do NOT create `app/controllers/invoices_controller.rb` or any invoice routes/views. Invoice visibility in this story is entirely through existing detail pages
- Do NOT touch `app/models/payment.rb`'s `readonly?` — that defends AC #3 of Story 5.3 and must remain behaviorally identical. The payment's invoice is written during the MarkCompleted transition (before `status_was == "completed"` applies); reads via `@payment.invoice` on subsequent requests are unaffected by `readonly?` because AR `readonly?` only blocks writes on the payment itself, not on associated records
- Do NOT modify `Payments::MarkCompleted` — its contract is final for this story. Compose it from `Loans::RecordRepayment`, don't mutate it
- Do NOT add a new `double_entry` table migration. `account_balances`, `line_checks`, `line_metadata`, `lines`, `scopes` already exist from Story 1.1
- Do NOT apply late fees, flip loan state, close the loan, or touch overdue derivation — those are 5.5 and 5.6
- Do NOT change `invoice_number` format, prefix, or allocation — reuse `create_with_next_invoice_number!`
- Do NOT introduce `Invoices::Show` page, `invoices#download`, PDF generation, or any email/notification — MVP keeps invoices as internal records
- Do NOT backfill existing disbursement invoices with `payment_id` — the column is nullable by design

### File Structure (Expected Touchpoints)

| Area | Files |
|------|--------|
| New | `db/migrate/<ts>_add_payment_reference_to_invoices.rb` |
| New | `app/services/invoices/issue_payment_invoice.rb` |
| New | `app/services/loans/record_repayment.rb` |
| New | `spec/services/invoices/issue_payment_invoice_spec.rb` |
| New | `spec/services/loans/record_repayment_spec.rb` |
| Modify | `config/initializers/double_entry.rb` — add `:repayment_received` account + `:repayment` transfer |
| Modify | `app/models/invoice.rb` — extend `INVOICE_TYPES`, `belongs_to :payment`, `:payment` scope, validations |
| Modify | `app/models/payment.rb` — add `has_one :invoice, dependent: :restrict_with_exception` |
| Modify | `app/models/loan.rb` — add `payment_invoices` helper (optional but recommended) |
| Modify | `app/controllers/payments_controller.rb` — call `Loans::RecordRepayment` instead of `Payments::MarkCompleted` |
| Modify | `app/views/payments/show.html.erb` — surface `invoice.invoice_number` in the locked summary |
| Modify | `app/views/loans/show.html.erb` — add Invoice column to repayment schedule table |
| Modify | `spec/factories/invoices.rb` — add `:payment` trait |
| Modify | `spec/models/invoice_spec.rb` — coverage for new type, association, validations |
| Modify | `spec/models/payment_spec.rb` — coverage for `has_one :invoice` and dependent restriction |
| Modify | `spec/requests/payments_spec.rb` — assert invoice + ledger side effects of successful completion; assert rollback on blocked |
| Modify | `spec/requests/loans_spec.rb` — assert Invoice column in repayment schedule |

### Existing Patterns to Follow

1. **`Loans::Disburse` outer-boundary pattern** — authoritative reference for money-moving services. Copy the `DoubleEntry.lock_accounts` → inner service calls → `DoubleEntry.transfer` → `ActiveRecord::Rollback` rollback shape. [Source: `app/services/loans/disburse.rb:18-69`]

2. **`Invoices::IssueDisbursementInvoice` service shape** — authoritative reference for the invoice service. Mirror its guard order, Result struct, and `create_with_next_invoice_number!` call exactly. [Source: `app/services/invoices/issue_disbursement_invoice.rb`]

3. **Ledger metadata shape** — match `{ loan_id:, payment_id:, invoice_id: }` so the spec selector `DoubleEntry::Line.where(account: "repayment_received", scope: loan.id).last.metadata[...]` works identically to the disbursement test pattern. [Source: `spec/services/loans/disburse_spec.rb:40-42`]

4. **`dependent: :restrict_with_exception` across linked records** — the codebase uses this for every cross-record link where deletion would corrupt history (loan → invoices, loan → payments, etc.). Apply the same on `Payment has_one :invoice`. [Source: `app/models/loan.rb:16-18`]

5. **`create_with_next_invoice_number!` allocation** — the only sanctioned way to create an invoice. Takes a table lock and allocates sequentially. Do NOT bypass it. [Source: `app/models/invoice.rb:31-36`, Story 4.5 dev notes]

6. **Thin controller dispatch** — controller orchestrates the service and flash; it does not know about invoices or the ledger. The replacement in Task 5.1 is a one-line swap. [Source: `app/controllers/payments_controller.rb:21-36`]

### UX Requirements

- **Admin sees no workflow change.** The completion form, the guarded confirmation dialog, the success flash copy, and the redirect destination are unchanged from Story 5.3. Changing UX copy in this story is out of scope and would risk regression on the 5.3 request specs
- **Payment invoice is supporting evidence on existing surfaces.** The invoice number appears:
  - On the payment detail's **locked summary card** after completion (new `<dl>` row)
  - On the loan detail's **repayment schedule table** as a new "Invoice" column for completed installments
- **Plain text, not a link.** Invoice numbers render as `INV-0007`-style plain text. There is no invoice detail page in this story — do NOT wrap the invoice number in a `link_to`
- **Disbursement invoice section on the loan show page is untouched.** Payment invoices are per-installment and belong in the schedule table, not in the disbursement summary
- **No new navigation, no new component, no new page.** UX wireframes for Epic 5 list the payments list/detail and loan detail as the full surface area; invoices are not called out as a separate surface in the wireframes [Source: `_bmad-output/planning-artifacts/ux-wireframes-pages/` — no invoices-specific wireframe]
- **Accessibility.** Extending an existing `<dl>` and `<table>` inherits their existing label/caption semantics; no new a11y work is required

### Library / Framework Requirements

- **Rails ~> 8.1** — `add_reference :invoices, :payment`, `belongs_to ... optional:`, `has_one ... dependent: :restrict_with_exception`
- **`double_entry`** — account and transfer configured in initializer; `DoubleEntry.account`, `DoubleEntry.lock_accounts`, `DoubleEntry.transfer`. See its account API: `accounts.define(identifier:, scope_identifier:, positive_only:)`; `transfers.define(from:, to:, code:)`. Metadata requires `config.json_metadata = true` — already set [Source: `config/initializers/double_entry.rb:4`]
- **`money-rails` ~> 3.0** — `Money.new(amount_cents, "INR")` for the transfer call; no new monetized columns
- **`aasm` ~> 5.5** — `payment.mark_completed!` transition continues to happen inside `Payments::MarkCompleted` unchanged
- **`paper_trail` ~> 17.0** — `Invoice has_paper_trail` already set; whodunnit captured via the request cycle for the new invoice row
- **`FactoryBot` ~> 6.5** — new `:payment` trait on the invoice factory; reuse the existing `:completed` trait on the payment factory
- **No new gems.** Additive initializer + migration + services + specs only

### Repayment Ledger Account Matrix

| Account | Scope | `positive_only?` | Meaning | Changes here |
|---------|-------|------------------|---------|--------------|
| `loan_receivable` | loan | `true` | What the borrower still owes the lender (in cents) | Credited DOWN by `payment.total_amount_cents` on each repayment |
| `disbursement_clearing` | loan | `false` | Source of principal at disbursement | Untouched in this story |
| `repayment_received` | loan | `false` | Repayments received, booked against the receivable | Credited DOWN (negative balance grows) by `payment.total_amount_cents` on each repayment — NEW |

**Balance invariant after N repayments:** `receivable = principal - Σ completed_total_amount_cents`; `repayment_received = -Σ completed_total_amount_cents`. Spec 8.2 asserts this directly.

### Service Composition Map (for Clarity)

```
PaymentsController#mark_completed
   └─ Loans::RecordRepayment.call(payment:, payment_date:, payment_mode:, notes:)    ← NEW
        └─ DoubleEntry.lock_accounts(receivable, repayment)
              ├─ Payments::MarkCompleted.call(...)                                    ← existing, unchanged
              │     └─ payment.with_lock { payment.mark_completed! + attrs }
              ├─ Invoices::IssuePaymentInvoice.call(payment:)                         ← NEW
              │     └─ Invoice.create_with_next_invoice_number!(...)
              └─ DoubleEntry.transfer(from: receivable, to: repayment, code: :repayment, metadata: ...)
```

### Immutability Defense-in-Depth for Payment Invoices

Three lines of defense uphold FR72 / NFR10 for payment invoices without touching AR's `readonly?`:

1. **No UI/controller mutation path exists** — no `InvoicesController`, no `invoices` routes, no form ever posts to invoices.
2. **Service-level idempotency** — `Invoices::IssuePaymentInvoice` refuses to create a second invoice for the same payment (`payment.invoice.present?` guard).
3. **DB-level restriction** — `has_one :invoice, dependent: :restrict_with_exception` on `Payment` blocks any cascade delete through the payment, and `has_many :invoices, dependent: :restrict_with_exception` on `Loan` does the same at the loan scope.

### Previous Story Intelligence (5.3)

- **`Payments::MarkCompleted` is treated as a pure primitive.** Story 5.3's Service Extension Points section explicitly leaves its signature stable so 5.4 can wrap it. Wrap, don't modify. [Source: 5-3 story lines 335-341]
- **`payment.with_lock` stays inside the service.** Story 5.3's debug log captured that the AR row lock is the right inner boundary; the outer boundary in 5.4 adds `DoubleEntry.lock_accounts` around it. No nested-transaction issue because the row lock and the table-level lock-accounts don't compete the way two nested `lock_accounts` would. [Source: 5-3 Dev Notes + Epic 4 Retro]
- **Controller parameter shape is stable.** `completion_params` (`:payment_date`, `:payment_mode`, `:notes`) was settled in 5.3 and the UI form matches it. Keep it identical in 5.4. [Source: `app/controllers/payments_controller.rb:39-41`]
- **`@payment.invoice` read happens after a save on the payment, but the payment's `readonly?` only blocks write on the persisted completed row — reading associations is unaffected.** Confirmed by reading the `readonly?` method body (it returns a boolean used by AR for writes only). [Source: `app/models/payment.rb:55-59`]
- **Flash copy is "`Payment ##{installment_number} for #{loan_number} recorded as completed.`"** Do NOT change this — the Story 5.3 request spec asserts it. [Source: `app/controllers/payments_controller.rb:30-31`]
- **Test file structure.** Extend `spec/requests/payments_spec.rb`, do NOT create `spec/requests/invoices_spec.rb` — there is no invoices request surface in this story. [Source: Story 5.3 Task 8.3 precedent]

### Git Intelligence

Recent commits (last 5) and their relevance:

- `67d1945` **Add guarded payment completion with locked financial history.** — Directly upstream. Installed `Payments::MarkCompleted`, the completion form, and locked-state summary this story extends with invoice/ledger side effects.
- `74ec10b` Add payment list, detail, and loan repayment-state visibility. — Installed the detail/list surfaces where the invoice number now surfaces.
- `af4a085` Add repayment schedule generation from loan disbursement. — Installed `Payment` records; every payment invoice belongs to one of these rows.
- `59e7827` Complete Epic 4 retrospective. — Planning only.
- `af1d56d` **Add guarded disbursement financial records and invoice handling.** — THE reference commit for money-moving service shape. `Loans::Disburse` + `Invoices::IssueDisbursementInvoice` patterns mirror 1:1 onto `Loans::RecordRepayment` + `Invoices::IssuePaymentInvoice` in this story.

**Preferred commit style:** `"Add payment invoice and repayment ledger posting on completion."`

### Epic 4 Retrospective Insights (Apply to This Story)

1. **"Money-critical work lives in domain services."** `Loans::RecordRepayment` owns the composed side effects; the controller calls one service and interprets one result. [Source: Epic 4 Retro line 39]
2. **"Money-moving stories need explicit transaction boundaries when bookkeeping gems participate."** Use `DoubleEntry.lock_accounts` as the OUTER boundary — the same lesson that unblocked Story 4.5. [Source: Epic 4 Retro line 117, line 61]
3. **"Serialized allocation."** `create_with_next_invoice_number!` already serializes; do NOT invent a new path. [Source: Epic 4 Retro line 48]
4. **"Facts over toggles."** `payment.invoice` is a fact (the record exists or does not). Do NOT add a `has_payment_invoice?` or boolean flag column. [Source: Epic 4 Retro line 98]
5. **"Test discipline."** Full `bundle exec rspec` must pass green; expected growth 20–30 examples. Keep `bundle exec rubocop` clean. [Source: Epic 4 Retro line 42]

### Calculation and Edge Cases to Test

1. **Exact invoice amount.** `invoice.amount_cents == payment.total_amount_cents` (principal + interest, NOT including late fees — late fees are 0 in this story and are 5.6's concern even when non-zero).
2. **Backdated `payment_date`.** `payment.payment_date = Date.current - 30.days` → invoice `issued_on = Date.current - 30.days` (inherits the fact, not today).
3. **Idempotent repayment.** Calling the controller twice on the same payment (race or retry) → second call blocked with "already been completed"; invoice count stays at 1; ledger lines count unchanged.
4. **Blocked path leaves zero side effects.** Invalid `payment_mode` → no payment state change, no invoice row, no ledger line. Assert all three counts.
5. **Invoice numbering is shared with disbursement.** Creating a payment invoice right after a disbursement invoice produces `INV-<n+1>`. The spec factory sequence in `spec/factories/invoices.rb` must not pre-allocate numbers that collide with the service's allocator — use `build` + the service rather than `create(:invoice)` in `record_repayment_spec.rb` happy-path tests.
6. **Multiple payments on the same loan.** Each successful repayment creates a distinct invoice and posts a distinct ledger line; cumulative balances remain correct across N repayments (spec with 2 consecutive repayments).
7. **Other loans unaffected.** Creating a payment invoice on loan A does NOT mutate the `loan_receivable` / `repayment_received` balances on loan B. Scope enforcement is intrinsic to `DoubleEntry.account(scope: loan)` — assert once to protect against a future bug in `loan_scope`.
8. **Rollback atomicity on mid-flow failure.** Stubbed `IssuePaymentInvoice.call` returning blocked → payment stays pending, no invoice row, no ledger line (the raise-on-rollback inside `lock_accounts` undoes the AASM transition). This is the most important correctness test in the story.
9. **PaperTrail captures the invoice creation event with the acting admin's id as whodunnit.** `invoice.versions.first.event == "create"` and `whodunnit == admin.id.to_s` when the service runs inside a signed-in request.
10. **Disbursement invoice association invariant.** Existing disbursement invoices still have `payment_id == nil` and remain valid after this migration (critical regression guard — run the whole suite, confirm `spec/models/invoice_spec.rb` and disbursement-related specs pass).
11. **`has_one :invoice` dependent restriction.** `payment.destroy` on a completed-and-invoiced payment raises `ActiveRecord::DeleteRestrictionError` (plus `Payment#readonly?` already blocks updates from the model side — this story's change closes the "destroy" half).

### Accounting Boundary (AC #2) — What It Means Concretely

The PRD/architecture call for a clean separation between **operational workflow records** (borrower, loan, application, payment state, documents) and **accounting-side posting** (`double_entry` lines). In this story:

- **Workflow records** change because a payment was completed (state transition + invoice fact). These are AR rows with `paper_trail` history.
- **Accounting posting** happens via `DoubleEntry.transfer` — a separate double-entry ledger with balanced debits/credits, scoped per loan. It does NOT overload operational columns.
- The composition lives in ONE service (`Loans::RecordRepayment`) so the boundary is visible in code: the `DoubleEntry.lock_accounts` block is the line between operational state changes and accounting postings.
- The controller, views, and operational services do NOT touch `DoubleEntry`. This is the PRD's "only money-moving domain services create postings" rule in practice. [Source: architecture.md#1099]

### `invoice_number` Shared Sequence Note

The current allocator scans `WHERE invoice_number LIKE 'INV-%'` across ALL invoice types. Payment invoices share the `INV-NNNN` namespace with disbursement invoices. This is intentional — invoice numbers are a global ledger sequence, not per-type. Do NOT introduce `PAY-NNNN` or a type prefix.

### Project Context Reference

- No `project-context.md` found in repo. The PRD (`_bmad-output/planning-artifacts/prd.md`), architecture (`_bmad-output/planning-artifacts/architecture.md`), UX spec (`_bmad-output/planning-artifacts/ux-design-specification.md`), and Stories 5.1–5.3 are the authoritative sources.

## Dev Agent Record

### Agent Model Used

Cursor (Opus 4.7) dev-story workflow.

### Debug Log References

- Initial migration run hit `strong_migrations` — wrapped `add_reference` in `safety_assured do ... end` (matches Epic 1 / Epic 4 precedent for schema-altering migrations).
- First run of `record_repayment_spec.rb` balance assertion failed because `DoubleEntry.transfer(from: receivable, to: repayment)` credits the `to` account positively, so `repayment_received.balance == +payment.total_amount_cents` (not negative as the story note suggested). Spec corrected to match the actual semantics — receivable goes down (still positive, not negative-clamped because `positive_only`), repayment ledger accumulates credits.
- Existing `PATCH /payments/:id/mark_completed` request specs that relied on zero ledger state began failing with `DoubleEntry::AccountWouldBeSentNegative` once the controller was rewired through `Loans::RecordRepayment`. Fixed by adding a `seed_receivable_for(loan)` helper in `spec/requests/payments_spec.rb` that mirrors the post-disbursement ledger state (transfer from `disbursement_clearing` → `loan_receivable`) without running the full `Loans::Disburse` flow. Applied to the five tests that didn't explicitly go through disbursement.

### Completion Notes List

- Payment invoices are now created automatically inside `Loans::RecordRepayment` when a payment is marked completed; invoice number is allocated through `Invoice.create_with_next_invoice_number!` and shares the `INV-NNNN` sequence with disbursement invoices (AC #1).
- `repayment_received` account and `:repayment` transfer are defined in the initializer; `Loans::RecordRepayment` uses `DoubleEntry.lock_accounts(receivable, repayment)` as the outer boundary, matching the `Loans::Disburse` precedent. Controller, views, and non-money services do not touch `DoubleEntry` (AC #2).
- `PaperTrail` whodunnit capture on the invoice is inherited from the request cycle (`set_paper_trail_whodunnit` on `ApplicationController`). Audit chain: `DoubleEntry::Line.metadata` carries `loan_id` + `payment_id` + `invoice_id`, the invoice has `paper_trail` versions, and the payment `has_one :invoice` with `dependent: :restrict_with_exception` (AC #3).
- No UI workflow change for the admin — the completion form, flash copy, redirect, and breadcrumb are identical to Story 5.3. The invoice number surfaces on the payment detail's locked summary card (new `<dl>` row before Notes) and as a new "Invoice" column in the loan show repayment schedule table.
- `Payments::MarkCompleted` behavior preserved exactly (`bundle exec rspec spec/services/payments/mark_completed_spec.rb` green).
- Full suite: `bundle exec rspec` → **446 examples, 0 failures** (up from 416 before this story). Rubocop → clean on all 16 touched Ruby files.

### File List

New:
- `db/migrate/20260418191434_add_payment_reference_to_invoices.rb`
- `app/services/invoices/issue_payment_invoice.rb`
- `app/services/loans/record_repayment.rb`
- `spec/services/invoices/issue_payment_invoice_spec.rb`
- `spec/services/loans/record_repayment_spec.rb`

Modified:
- `app/models/invoice.rb`
- `app/models/payment.rb`
- `app/models/loan.rb`
- `app/controllers/payments_controller.rb`
- `app/controllers/loans_controller.rb`
- `app/views/payments/show.html.erb`
- `app/views/loans/show.html.erb`
- `config/initializers/double_entry.rb`
- `spec/factories/invoices.rb`
- `spec/models/invoice_spec.rb`
- `spec/models/payment_spec.rb`
- `spec/requests/payments_spec.rb`
- `spec/requests/loans_spec.rb`
- `db/schema.rb` (auto-generated by migration)

## Change Log

- 2026-04-18: Created story for payment financial records and the accounting boundary.
- 2026-04-18: Implemented payment invoice fact + `repayment_received` ledger posting composed behind `Loans::RecordRepayment`. Controller rewired to the new composer with identical parameter shape. Invoice number surfaced on payment detail locked card and loan detail repayment schedule. 446 examples green, rubocop clean.
