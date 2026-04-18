# Story 5.6: Apply Late Fees and Close Loans from Completed Repayment Facts

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want late-fee impact and final loan closure handled from servicing facts,
so that repayment outcomes remain financially correct and operationally clear.

## Acceptance Criteria

1. **Given** an overdue condition meets MVP late-fee rules
   **When** the system applies overdue consequences
   **Then** it applies the flat late fee according to policy
   **And** the admin can see the late-fee impact within the repayment context

2. **Given** all generated loan payments have been completed
   **When** the system refreshes the loan lifecycle state
   **Then** the loan closes automatically
   **And** closure is derived from completed repayment facts rather than manual toggles

3. **Given** a loan has closed automatically
   **When** the admin inspects the final loan state
   **Then** the closed status is visible and historically consistent
   **And** the record remains available for later operational review

## Tasks / Subtasks

- [x] Task 1: Define the MVP flat late-fee policy constant and document the contract (AC: #1)
  - [x] 1.1 Add a single source of truth for the flat late-fee amount. Define `Payments::LateFeePolicy` in a new file `app/services/payments/late_fee_policy.rb` (NOT an initializer — this is business logic, not framework config). Contract: `MVP_FLAT_LATE_FEE_CENTS = 25_00` (₹25.00, stored as `Integer` cents; matches the `Money.new(cents, "INR")` pattern used throughout the repo — see `app/services/loans/disburse.rb:48`). Expose `Payments::LateFeePolicy.flat_fee_cents` returning the constant so the service and specs never hard-code the number.
  - [x] 1.2 Freeze the contract in the file-level comment: "Applied exactly once per installment, at the moment it first becomes overdue. FR52." Do NOT add configurability by loan, borrower, or tenant — MVP is a single flat amount.
  - [x] 1.3 Do NOT add a `Rails.application.config.x.late_fee_cents` hook. A module constant is sufficient and avoids a configuration indirection that would complicate specs.
  - [x] 1.4 Do NOT introduce a DB-backed `LateFeePolicy` model. Story 5.6 scope explicitly holds the MVP at a single flat value; a policy table is future work.

- [x] Task 2: Introduce `Payments::ApplyLateFee` domain service (AC: #1)
  - [x] 2.1 Create `app/services/payments/apply_late_fee.rb` extending `ApplicationService`. Mirror the canonical `Result = Struct.new(:payment, :error, keyword_init: true) do def success? = error.blank?; def blocked? = error.present?; end` shape used by `Payments::MarkOverdue` and `Payments::MarkCompleted`. Add a `def applied? = payment.present? && payment.late_fee_cents.to_i.positive? && error.blank?` helper for specs (optional; do NOT expose a separate boolean on the struct — derive from `payment`).
  - [x] 2.2 Constructor: `def initialize(payment:)`. No `today:` kwarg — this service does NOT make date comparisons; eligibility is purely state-based ("payment transitioned into overdue, late fee not yet applied"). The caller (`Loans::RefreshStatus`) is responsible for the date logic.
  - [x] 2.3 Idempotency / no-op guards (return `Result.new(payment: payment)` success, NOT blocked — callers must be able to invoke this after every `Payments::MarkOverdue` without branching):
    - If `payment.late_fee_cents.to_i.positive?` → no-op success (already applied; FR52 "exactly once").
    - If `!payment.overdue?` → no-op success (late fee is ONLY for the `:overdue` payment state; `:pending` is not yet overdue, `:completed` is settled).
    - If `payment.readonly?` → no-op success. This is a defensive guard: if `Payment#readonly?` ever returns true here it is a bug elsewhere (overdue-state payments are never readonly — `status_was == "overdue"`, not `"completed"`), but a silent no-op is safer than a raised `ActiveRecord::ReadOnlyRecord` swallowing a whole refresh.
  - [x] 2.4 Mutation: wrap in `payment.with_lock` (matches the Story 5.5 pattern). Inside the lock, `payment.reload`, re-check the no-op guards, then `payment.update!(late_fee_cents: Payments::LateFeePolicy.flat_fee_cents)`.
  - [x] 2.5 The `update!` MUST NOT touch `total_amount_cents`. The scheduled total (`principal + interest`) is an invariant established by Story 5.1. The late fee is intentionally a SEPARATE charge, shown separately in the UI (Story 5.6 AC #1 "And the admin can see the late-fee impact"; PRD line 159: "shows the late fee as a separate charge"). Changing `total_amount_cents` would break the `total_matches_components` validator on `Payment` and retroactively alter the `DoubleEntry` posting amount in `Loans::RecordRepayment`, which is forbidden by Story 5.4's accounting boundary.
  - [x] 2.6 The `update!` MUST NOT change `status`. Late-fee application is orthogonal to the AASM state; a payment stays `:overdue` after its fee is assessed, and the subsequent `mark_completed!` transition still fires from `:overdue → :completed`.
  - [x] 2.7 Do NOT post anything to `DoubleEntry`. The late fee is not a disbursement or a repayment — it is a charge recorded on the payment row, settled when the payment is ultimately completed (the settlement is out of scope for MVP; FR52 covers assessment only, not remittance).
  - [x] 2.8 Rescue `ActiveRecord::RecordInvalid` and return `blocked("Late fee could not be applied.")` — do NOT leak AR exceptions. `Rails.logger.warn` with payment id and message, matching the Story 5.5 rescue pattern (`Loans::RefreshStatus` line 50).
  - [x] 2.9 Do NOT rescue `ActiveRecord::ReadOnlyRecord`. The 2.3 guard prevents the call path; if it ever triggers it is a regression worth surfacing as a 500 in tests.
  - [x] 2.10 PaperTrail: `Payment has_paper_trail` is already configured. The `update!` fires a `PaperTrail::Version` with `event: "update"`; the `late_fee_cents` change is captured automatically. Do NOT add custom whodunnit handling — the request cycle's `set_paper_trail_whodunnit` already applies.

- [x] Task 3: Extend `Loans::RefreshStatus` to apply late fees and to fire loan closure (AC: #1, #2, #3)
  - [x] 3.1 In `app/services/loans/refresh_status.rb`, after the payment loop that invokes `Payments::MarkOverdue`, add a second pass within the same `loan.with_lock` block that invokes `Payments::ApplyLateFee.call(payment: p)` for every `p` in `loan.payments.reload.ordered` where `p.overdue?` and `p.late_fee_cents.to_i.zero?`. The two-pass structure (overdue first, then fee) is deliberate: `ApplyLateFee` requires the AASM state to already be `:overdue`, and `MarkOverdue` is the only thing that transitions into that state here.
  - [x] 3.2 Extend the `Result` struct: `Result = Struct.new(:loan, :transitioned, :late_fees_applied, :error, keyword_init: true)`. `late_fees_applied` is an integer count of payments that received a first-time late fee on this invocation. Default to `0`. `success?`, `blocked?`, and `changed?` helpers remain; consider `changed?` to return `transitioned.present? || late_fees_applied.to_i.positive?` so controllers and `DeriveOverdueStates` can treat "fee applied but no lifecycle transition" as a meaningful change.
  - [x] 3.3 Extend the derivation rules (apply in order, short-circuit as noted):
    - `MarkOverdue` pass over pending-past-due payments (existing behaviour — keep).
    - `ApplyLateFee` pass over newly-overdue payments without a fee (new).
    - `loan.payments.reload`.
    - If `loan.active?` and `loan.payments.any?(&:overdue?)` → `loan.mark_overdue!` → `transitioned = :mark_overdue`. (existing)
    - If `loan.overdue?` and `loan.payments.none? { |p| p.overdue? || (p.pending? && p.due_date < @today) }` → `loan.resolve_overdue!` → `transitioned = :resolve_overdue`. (existing)
    - **NEW** If (loan is `:active` OR `:overdue`) AND `loan.payments.any?` AND `loan.payments.all?(&:completed?)` → `loan.close!` → `transitioned = :close`. This replaces neither `resolve_overdue` nor `mark_overdue` — closure is checked AFTER them so that a back-flip to `:active` can still fire `close` in the same refresh when the last completion drained the last overdue AND all payments happen to be completed. Short-circuit: if `close` fires, skip the other loan arms (a closed loan is terminal).
    - For a `:overdue` loan with all payments completed, the resolve_overdue branch will NOT fire because `loan.payments.any?(&:completed?)` is irrelevant — what matters is there are no overdue and no pending-past-due rows left, which is true. Either order works, but resolve THEN close would double-transition; pick a single rule: check closure FIRST when all payments are completed (AC #2 "all generated payments have been completed"), else try resolve, else try mark_overdue. See the decision table in Dev Notes "Derivation Rules (Updated)" for the exact ordering.
  - [x] 3.4 Closure requires AT LEAST ONE payment. `loan.payments.any?` must be true before firing `close!`. Rationale: a `:active`/`:overdue` loan by definition has been disbursed, and `Loans::Disburse` always produces a repayment schedule (Story 5.1). But a defensive guard against empty-schedule edge cases (test fixtures, corrupted data) keeps the service honest.
  - [x] 3.5 Closure fires the existing AASM `close` event: `transitions from: [:active, :overdue], to: :closed` (see `app/models/loan.rb:81-83`). No AASM change required. No new state.
  - [x] 3.6 No `DoubleEntry` postings on closure. Closure is a lifecycle transition, not a money event. All money moved during the loan's life (disbursement + repayments) has already been posted by `Loans::Disburse` and `Loans::RecordRepayment`.
  - [x] 3.7 Rescue `AASM::InvalidTransition` and `ActiveRecord::RecordInvalid` at the loan boundary (widen the existing rescues to include the new `close!` event). Log and return `blocked(BLOCKED_INVALID_STATE)`. The `:closed` short-circuit at the top of `call` still applies — an already-closed loan no-ops before any pass runs.
  - [x] 3.8 Keep the `loan.with_lock` boundary. Both the fee pass and the close transition must happen under the same row lock as the existing logic so two concurrent refreshes cannot double-assess a fee or fire `close` twice.
  - [x] 3.9 Do NOT introduce a separate `Loans::Close` service. The Epic 5 architecture file tree [Source: `_bmad-output/planning-artifacts/architecture.md:693`] shows `loans/close.rb` as a placeholder, but closure in this story is purely a derived lifecycle transition — not a user action — and `Loans::RefreshStatus` already owns all derived lifecycle transitions on the loan. Creating a separate service would split the lock boundary and invite race conditions between "refresh overdue" and "close".
  - [x] 3.10 Do NOT add a controller action for manual loan closure. Closure is derived-only for MVP (PRD line 187: "When all generated payments are paid, the loan is automatically closed for MVP. There is no separate manual closure workflow.").

- [x] Task 4: Wire the extended refresh into existing read surfaces (no new hooks) (AC: #2, #3, NFR8)
  - [x] 4.1 `LoansController#show` already calls `Loans::RefreshStatus.call(loan: @loan)`. No code change — the added closure and late-fee behavior piggybacks on the existing hook. Confirm via request spec (Task 7.5) that opening a loan whose last payment has just been completed renders with `:closed` status.
  - [x] 4.2 `PaymentsController#show` already calls `Loans::RefreshStatus.call(loan: @payment.loan)`. No code change. The existing `@payment.reload` after the refresh surfaces any newly-applied `late_fee_cents` on the payment.
  - [x] 4.3 `PaymentsController#mark_completed` already calls `Loans::RefreshStatus.call(loan: result.payment.loan)` in the success branch. No code change. When the last repayment completes the loan, this hook fires `close!` and the subsequent redirect renders the loan as closed on the next page the admin visits. The flash string is unchanged — Story 5.4/5.5 assertions remain green.
  - [x] 4.4 `Payments::DeriveOverdueStates` already delegates per-loan to `Loans::RefreshStatus`. No code change required for late-fee / closure propagation. Update the `Result` struct observability to also include `late_fees_applied` and `closed_loans` counts (derived from the per-loan `RefreshStatus` result) — see Task 4.5.
  - [x] 4.5 In `app/services/payments/derive_overdue_states.rb`:
    - Extend the `Result` struct: `Result = Struct.new(:transitioned_payments, :transitioned_loans, :late_fees_applied, :closed_loans, :failed_loans, :error, keyword_init: true)`.
    - Aggregate from each per-loan `Loans::RefreshStatus` result: `late_fees_applied += result.late_fees_applied.to_i`; `closed_loans += 1 if result.transitioned == :close`.
    - Keep the rescue around the per-loan iteration (Story 5.5 review patch) so a single loan's closure failure does not abort the sweep.
    - The `Loan.where(id: loan_ids, status: %w[active overdue]).find_each` scope is unchanged: closure transitions the loan to `:closed`, so it will not be picked up by the next sweep; that is correct.
  - [x] 4.6 `LoansController#index` is still NOT called with refresh. Story 5.5 Task 4.5 rationale holds (O(loans) cost on every dashboard hit). Closure visibility on the index page relies on natural navigation: admins drill in via the payment or loan detail, which triggers refresh, which flips the loan to `:closed`.
  - [x] 4.7 Do NOT hook refresh into any other controller. No `DashboardController` (Story 6.1). No `InvoicesController`. No `BorrowersController`.

- [x] Task 5: Surface the late-fee impact and closed state in existing UI (AC: #1, #3)
  - [x] 5.1 `app/views/payments/show.html.erb` already renders the Late fee row (line 183-188 shows `humanized_money_with_symbol(@payment.late_fee)` when `late_fee_cents > 0`, else `"—"`). Confirm the label remains "Late fee" and the value becomes visible automatically once the fee is applied. NO change to this file.
  - [x] 5.2 `app/views/payments/index.html.erb` — the existing table may not currently render a dedicated Late fee column. If it does NOT (confirm by reading the file before editing), DO NOT add one in this story. The payment detail page is the canonical surface for per-installment late-fee visibility (PRD line 159: "shown ... in the overdue payment detail view and the related loan repayment summary"). The payments index is an operational scanning surface; keeping it stable avoids a re-layout that Story 5.2 already designed for.
  - [x] 5.3 `app/views/loans/show.html.erb` — add a "Total late fees assessed" line item within the existing repayment summary dl grid (near line 462 where `total_scheduled_amount` is rendered). Read `@loan.total_late_fees_cents` (new helper — see Task 5.4) and render via `humanized_money_with_symbol(Money.new(@loan.total_late_fees_cents, "INR"))`. If zero, render `"—"` matching the payment show pattern. This satisfies the "admin can see the late-fee impact ... within the repayment context" half of AC #1 and the FR56 / PRD line 159 "related loan repayment summary" requirement.
  - [x] 5.4 Add a `Loan#total_late_fees_cents` helper in `app/models/loan.rb` returning `payments.sum(:late_fee_cents)`. Mirror the existing `total_scheduled_amount` method shape. Keep it a single `sum` query — no in-Ruby iteration.
  - [x] 5.5 `app/views/loans/show.html.erb` — the existing `@loan.status_label` / `status_tone` path already handles `:closed` (returns "Closed" label, `:neutral` tone). Confirm the status badge renders "Closed" as expected. NO change required.
  - [x] 5.6 `Loan#next_lifecycle_stage_label` and `#next_lifecycle_stage_guidance` (`app/models/loan.rb:210-242`) already handle `:closed` with the message "This loan has completed its lifecycle and no further transition is expected." NO change required.
  - [x] 5.7 `Loan#editable_details?` returns `false` from `:closed` (the method whitelists only pre-disbursement states). Confirm this implicitly locks the loan edit form on a closed loan. NO change required; add a targeted spec (Task 7.2).
  - [x] 5.8 Do NOT add a "Close loan" button, menu item, or confirmation dialog anywhere. Closure is derived.
  - [x] 5.9 Do NOT add a "Reopen loan" affordance. `:closed` is terminal for MVP.
  - [x] 5.10 Do NOT add late-fee display on any list view (`loans#index`, `payments#index`, `borrowers/:id/loans` if present). The detail-page surfaces are sufficient for MVP.
  - [x] 5.11 Do NOT change `PaymentsHelper#payment_due_hint`. The helper already emits "Overdue by N days" and is unchanged by this story.

- [x] Task 6: Preserve the Story 5.3 / 5.4 accounting boundary (AC: #1, #2, #3)
  - [x] 6.1 Do NOT modify `Payments::MarkCompleted`. When a payment transitions `:overdue → :completed`, the `late_fee_cents` column on that payment is preserved (it is a separate column, not computed from `status`). The existing `Payment#readonly?` guard fires on the NEXT save after completion — which is exactly what locks the late-fee value in amber post-completion.
  - [x] 6.2 Do NOT modify `Loans::RecordRepayment`. The `DoubleEntry.transfer` amount is `Money.new(payment.total_amount_cents, "INR")` (receivable → repayment_received). The late fee is NOT part of this transfer — it is a separate charge that is not posted to DoubleEntry in MVP (PRD scope: assessment only, not remittance).
  - [x] 6.3 Do NOT modify `Invoices::IssuePaymentInvoice`. The payment invoice `amount_cents` is `payment.total_amount_cents`, which EXCLUDES the late fee. This is correct for MVP — the invoice reflects the scheduled repayment amount; the late fee is a separate line item on the payment detail view.
  - [x] 6.4 Do NOT modify `DoubleEntry` initializer. No new accounts (no `late_fee_income`, no `late_fee_receivable`). The accounting-boundary story for late fees is explicitly deferred beyond MVP.
  - [x] 6.5 Do NOT modify the `Payment` model's `total_matches_components` validator. The validator ignores `late_fee_cents` by design; the validator's contract is strictly `total_amount_cents == principal_amount_cents + interest_amount_cents`. Adding `late_fee_cents` into that sum would break every existing seeded payment.
  - [x] 6.6 Do NOT widen `Payment#readonly?`. It must continue to return `true` iff `status_was == "completed"`. Late-fee application must happen BEFORE completion, which is already the case because `ApplyLateFee` no-ops unless `overdue?`.

- [x] Task 7: Tests (AC: #1, #2, #3)
  - [x] 7.1 `spec/services/payments/apply_late_fee_spec.rb` (new):
    - Happy path: an `:overdue` payment with `late_fee_cents == 0` → service returns `success?`, `payment.reload.late_fee_cents == Payments::LateFeePolicy.flat_fee_cents`.
    - Idempotency: an `:overdue` payment with `late_fee_cents > 0` → `success?` with no state change; `payment.versions.count` unchanged post-call (confirms `update!` did not fire).
    - No-op on `:pending`: a `:pending` payment → `success?`, fee stays `0`.
    - No-op on `:completed`: a `:completed` payment → `success?`, fee stays at whatever was pre-completion (usually `0`); MUST NOT raise `ActiveRecord::ReadOnlyRecord`.
    - Row lock is acquired: `expect(payment).to receive(:with_lock).and_call_original` on the happy path.
    - Does NOT modify `status`: pre and post AASM state identical (`:overdue → :overdue`).
    - Does NOT modify `total_amount_cents`: value unchanged.
    - Does NOT modify `principal_amount_cents` or `interest_amount_cents`.
    - Blocked branch: stub `payment.update!` to raise `ActiveRecord::RecordInvalid` → service returns `blocked?` with `"Late fee could not be applied."`; `Rails.logger` receives `:warn`.
    - PaperTrail: after happy path, `payment.versions.last.event == "update"`.
    - Constant contract: `Payments::LateFeePolicy.flat_fee_cents` returns an `Integer > 0`; spec is deterministic (no `rand`).
  - [x] 7.2 `spec/services/loans/refresh_status_spec.rb` (extend):
    - Late-fee pass fires AFTER overdue transition: a loan with one pending-past-due payment and `late_fee_cents == 0` → after `RefreshStatus`: payment is `:overdue`, `late_fee_cents == Payments::LateFeePolicy.flat_fee_cents`, `result.late_fees_applied == 1`, `result.transitioned == :mark_overdue`.
    - Idempotency on late fee: call `RefreshStatus` twice → second call has `result.late_fees_applied == 0`, `payment.reload.late_fee_cents` unchanged.
    - Two overdue installments, one already assessed: loan with installment A (`:overdue`, fee already applied) and installment B (`:pending`, past-due, fee zero) → after refresh: A unchanged, B is `:overdue` with fee applied, `result.late_fees_applied == 1`.
    - Closure happy path: loan with all payments completed (setup via `Loans::RecordRepayment` for every installment) → `RefreshStatus` fires `close!`, `result.transitioned == :close`, `loan.reload.closed?` true.
    - Closure from `:overdue`: loan is `:overdue` with the last overdue payment just completed → refresh completes closure in a single call, `result.transitioned == :close` (NOT `:resolve_overdue`). Rule: when all payments are completed, closure wins over resolve.
    - Closure requires ≥1 payment: an `:active` loan with `payments.count == 0` (pathological; force via direct DB insert in spec setup) → no transition, `result.transitioned` nil, no exception.
    - `:closed` loan is inert: calling refresh on an already-closed loan → no transition, no mutation, no exception. (Existing coverage; confirm no regression.)
    - Closure does NOT touch `DoubleEntry`: stub `DoubleEntry.transfer` to receive `:call` zero times across the closure flow.
    - Rescue widens: stub `loan.close!` to raise `ActiveRecord::RecordInvalid` → `result.blocked?` true, error message matches, `Rails.logger` receives `:warn`.
    - Row lock: `expect(loan).to receive(:with_lock).and_call_original` on the closure path.
    - `result.changed?` returns true when only a late fee was applied (no lifecycle transition): loan with one newly-overdue payment, no closure → `changed? == true`.
  - [x] 7.3 `spec/services/payments/derive_overdue_states_spec.rb` (extend):
    - Aggregate counts: two loans each with one pending-past-due payment → result `late_fees_applied == 2`, `transitioned_payments == 2`, `transitioned_loans == 2`, `closed_loans == 0`.
    - Closure aggregate: a loan where every payment is one operation away from completion (set up via helper) → drive the final completion via `Loans::RecordRepayment` in the spec, then call `DeriveOverdueStates` → `closed_loans == 1` (or verify via a dedicated scenario that closure flows through the sweep).
    - Rescue isolation: stub `Loans::RefreshStatus.call` to raise for one loan but succeed for another → `failed_loans == 1`, the healthy loan still transitions.
    - Already-closed loans are not visited: a `:closed` loan with historic pending payments (pathological) is not in the `status: %w[active overdue]` scope → `RefreshStatus` not called for it.
  - [x] 7.4 `spec/models/loan_spec.rb` (extend):
    - `Loan#total_late_fees_cents` returns the sum of `payments.late_fee_cents`; `0` when no fees applied.
    - `Loan#may_close?` is true from `:active` and `:overdue`, false from `:created`, `:documentation_in_progress`, `:ready_for_disbursement`, `:closed`.
    - `Loan#editable_details?` remains `false` for `:closed` loans (regression guard for Story 4.2 contract against the new state).
    - `Loan#next_lifecycle_stage_label` for `:closed` returns "Closed".
  - [x] 7.5 `spec/requests/loans_spec.rb` (extend):
    - Late-fee visibility: a disbursed loan with one newly-past-due payment → `GET /loans/:id` renders the loan show, the new "Total late fees assessed" row shows `humanized_money_with_symbol(Money.new(Payments::LateFeePolicy.flat_fee_cents, "INR"))`, and the payment detail link is present.
    - Closure freshness: a disbursed loan with all payments completed (set up via `Loans::RecordRepayment` for every installment) → `GET /loans/:id` renders with status badge "Closed" (assert the badge text). This validates AC #2 and AC #3 "closed status is visible".
    - Already-closed loan: `loan.update_columns(status: "closed")` stub → `GET /loans/:id` renders successfully (no 500, no state change on re-open).
    - Loan show still renders for `:ready_for_disbursement` (regression, existing Story 5.5 guard).
  - [x] 7.6 `spec/requests/payments_spec.rb` (extend):
    - `GET /payments/:id` on a pending-past-due payment → after the request, `payment.reload.overdue?` is true AND `payment.late_fee_cents == Payments::LateFeePolicy.flat_fee_cents` (freshness + fee applied by the read-surface refresh hook).
    - Closure via `mark_completed`: loan with exactly one remaining pending payment (all prior installments already completed) → `PATCH /payments/:id/mark_completed` with valid data → after the request, `loan.reload.closed?` is true. The flash string is UNCHANGED byte-for-byte (Story 5.4 contract).
    - `GET /payments/:id` on a fully-completed loan's last payment → the page renders with the payment `:completed` and the loan now `:closed` (assert via reload + status label presence).
  - [x] 7.7 `spec/factories/payments.rb` (extend):
    - Add a `:with_late_fee` trait that sets `late_fee_cents { Payments::LateFeePolicy.flat_fee_cents }`. Used in spec setup for the "idempotent late fee" and "already-assessed installment" scenarios. Do NOT change the default factory (`late_fee_cents { 0 }` remains).
  - [x] 7.8 Run `bundle exec rspec` green — expect roughly 18–25 new examples. Run `bundle exec rubocop` green on all touched files. No new linters, no new gems.

### Review Findings

- [x] [Review][Patch] Prefer `result.applied?` over extra `payment.reload` for late-fee counter [`app/services/loans/refresh_status.rb:44`] — fixed: replaced `payment.reload.late_fee_cents.to_i.positive?` with `result.applied?`.
- [x] [Review][Defer] `DeriveOverdueStates` query scope misses loans with only already-overdue, unassessed payments [`app/services/payments/derive_overdue_states.rb:14`] — deferred, pre-existing Story 5.5 design; per-request `RefreshStatus` hooks cover this gap interactively.
- [x] [Review][Defer] `DeriveOverdueStates` bare `rescue => e` swallows all exception types including programming errors [`app/services/payments/derive_overdue_states.rb:30`] — deferred, pre-existing Story 5.5 pattern; isolation is intentional but hides regressions in batch sweeps.
- [x] [Review][Defer] No model-level validation preventing negative `late_fee_cents` on Payment [`app/models/payment.rb`] — deferred, pre-existing; only writer is `ApplyLateFee` which always sets the positive constant, so no current path produces a negative value.

## Dev Notes

### Epic 5 Cross-Story Context

- **Epic 5** covers repayment servicing, overdue control, and loan closure (FR40–FR56, FR72).
- **Stories 5.1–5.4 (done)** — repayment schedule, read surfaces, locked completion, and payment financial records are all in place.
- **Story 5.5 (done)** — `Payments::MarkOverdue`, `Loans::RefreshStatus`, `Payments::DeriveOverdueStates` installed the overdue derivation chain. Wired into `LoansController#show`, `PaymentsController#show`, `PaymentsController#index`, `PaymentsController#mark_completed`. Dev Notes explicitly deferred late fees and closure to this story.
- **This story (5.6)** — adds `Payments::ApplyLateFee` + `Payments::LateFeePolicy`; extends `Loans::RefreshStatus` with a late-fee pass and the `close!` transition. No new controllers, no new routes, no new UI surfaces (only one dl row addition on the existing `loans#show`).
- **Epic 5 retrospective (optional)** — follows this story.

### Critical Architecture Constraints

- **Derivation and lifecycle transitions live in domain services, never in views or controllers.** [Source: `_bmad-output/planning-artifacts/architecture.md:46,250,813`] Late-fee application and loan closure are both derived lifecycle events and MUST stay inside `app/services/payments/` and `app/services/loans/`.
- **Facts over toggles.** Late fee is a recorded consequence of a recorded fact (payment transitioned into `:overdue`). Do NOT add `late_fee_applied?` boolean columns, `late_fee_applied_at` timestamps, or admin-facing "Apply late fee" buttons. `late_fee_cents > 0` IS the fact.
- **Closure is derived from completed repayment facts.** [Source: `_bmad-output/planning-artifacts/epics.md:870-878`; PRD line 261] Do NOT add a manual "Close loan" button or action. `loan.close!` is fired ONLY by `Loans::RefreshStatus` under its row lock.
- **Money-critical correctness.** [Source: PRD line 257-261] `total_amount_cents` is invariant (Story 5.1); the late fee is a separate column (`late_fee_cents`) and a separate visual line item. The `DoubleEntry.transfer` in `Loans::RecordRepayment` continues to move only `total_amount_cents`; late fees are assessed but not settled via DoubleEntry in MVP (accounting-boundary decision).
- **Accounting boundary preserved.** [Source: `_bmad-output/implementation-artifacts/5-4-generate-payment-financial-records-and-preserve-the-accounting-boundary.md`] No new `DoubleEntry` accounts, no new transfers. Closure is a workflow transition, not a ledger event.
- **`Payment#readonly?` invariant holds.** Late-fee application happens on `:overdue` (not `:completed`) payments, so `status_was == "overdue"` and `readonly?` returns `false`. Story 5.3 contract is unaffected.
- **Page loads reflect the latest committed system state (NFR8).** [Source: `_bmad-output/planning-artifacts/epics.md:111`] The existing `RefreshStatus` hooks from Story 5.5 carry both the fee pass and the closure transition — no new hooks required.
- **No new gems.** Service + extension + specs.
- **No new migrations.** `Payment.late_fee_cents` column exists. `Loan.status` AASM `:closed` state exists. `loan.close!` event exists.
- **No new routes.** Closure is not a user action. Late fee is not a user action.
- **Row-level locks, not advisory locks.** `payment.with_lock` and `loan.with_lock` inside `Loans::RefreshStatus` serialize concurrent application. Do NOT add `DoubleEntry.lock_accounts` around the fee / closure passes — no ledger posting occurs.

### Files NOT to Create or Modify

- Do NOT create `app/services/loans/close.rb` — closure is a single-line transition inside `Loans::RefreshStatus`. The architecture file tree [Source: `_bmad-output/planning-artifacts/architecture.md:693`] listed it as a placeholder; reality after Story 5.5 is that all derived loan lifecycle transitions live in `RefreshStatus`.
- Do NOT create `app/jobs/apply_late_fees_job.rb` or any background job. Inline derivation on read (Story 5.5 pattern) is sufficient for MVP.
- Do NOT create `app/controllers/loan_closures_controller.rb` or any similar surface.
- Do NOT create a `LateFee` model or a `late_fees` table. The fee is a column on `Payment`.
- Do NOT add new `DoubleEntry` accounts.
- Do NOT modify `Payments::MarkCompleted`, `Payments::MarkOverdue`, `Loans::RecordRepayment`, `Invoices::IssuePaymentInvoice`, `Loans::Disburse`, `Loans::GenerateRepaymentSchedule`, the `double_entry.rb` initializer, or the `Payment#readonly?` method.
- Do NOT modify `Payment#total_matches_components` validator.
- Do NOT add a route, controller action, or view partial for manual closure or manual fee application.
- Do NOT add a "Reopen loan" flow.
- Do NOT change the `payments#mark_completed` flash string (Story 5.4 spec asserts it byte-for-byte).
- Do NOT add late-fee columns to any list-view table (payments index, loans index) in this story. Detail-page visibility is sufficient for MVP (PRD line 159).
- Do NOT introduce a configurable `LateFeePolicy` (per-borrower, per-loan, per-tenant, DB-backed). A single module constant suffices for MVP.

### File Structure (Expected Touchpoints)

| Area | Files |
|------|--------|
| New | `app/services/payments/late_fee_policy.rb` |
| New | `app/services/payments/apply_late_fee.rb` |
| New | `spec/services/payments/apply_late_fee_spec.rb` |
| Modify | `app/services/loans/refresh_status.rb` — add late-fee pass, add `close!` arm, extend `Result` struct |
| Modify | `app/services/payments/derive_overdue_states.rb` — extend `Result` struct with `late_fees_applied` and `closed_loans` |
| Modify | `app/models/loan.rb` — add `total_late_fees_cents` helper |
| Modify | `app/views/loans/show.html.erb` — add "Total late fees assessed" row |
| Modify | `spec/factories/payments.rb` — add `:with_late_fee` trait |
| Modify | `spec/services/loans/refresh_status_spec.rb` — late-fee + closure scenarios |
| Modify | `spec/services/payments/derive_overdue_states_spec.rb` — aggregate counts |
| Modify | `spec/models/loan_spec.rb` — `total_late_fees_cents`, `may_close?`, closed-state editability |
| Modify | `spec/requests/loans_spec.rb` — late-fee visibility + closure freshness |
| Modify | `spec/requests/payments_spec.rb` — late-fee on detail page, closure via mark_completed |

### Existing Patterns to Follow

1. **`Payments::MarkOverdue` service shape** — authoritative reference for `Payments::ApplyLateFee`. Copy the `Result` struct, `blocked(...)` helper, `payment.with_lock { payment.reload; re-check; mutate }` pattern, and the `rescue` + `Rails.logger.warn` pattern. [Source: `app/services/payments/mark_overdue.rb`]
2. **`Loans::RefreshStatus` composition** — the existing pattern of "run payment-level service per payment, then evaluate loan-level arms under `loan.with_lock`" is exactly the pattern to extend. The late-fee pass is a second payment-level loop identical in shape to the overdue loop. [Source: `app/services/loans/refresh_status.rb:30-46`]
3. **`Payments::DeriveOverdueStates` observability counts** — the `Result.new(transitioned_payments:, transitioned_loans:, failed_loans:)` shape already demonstrates how to roll per-loan `RefreshStatus` results into a sweep-level observability struct. Extend it with `late_fees_applied` and `closed_loans` using the same pattern. [Source: `app/services/payments/derive_overdue_states.rb`]
4. **`Money.new(cents, "INR")` rendering** — used consistently for currency display. Late-fee totals on `loans#show` must use the same pattern. [Source: `app/views/loans/show.html.erb:462`; `app/services/loans/disburse.rb:48`]
5. **`has_paper_trail` automatic whodunnit** — `ApplicationController` already sets `Current.user` via `set_paper_trail_whodunnit`. Every `update!` inside the request cycle is attributed to the acting admin without extra wiring. [Source: `app/controllers/application_controller.rb`; Story 5.5 Dev Notes]
6. **Thin controller dispatch** — no controller changes required in this story; every wiring point is already in place from Story 5.5. [Source: `app/controllers/payments_controller.rb`; `app/controllers/loans_controller.rb`]

### Derivation Rules (Updated)

Order of evaluation inside `Loans::RefreshStatus#call`, within `loan.with_lock`:

| Step | Condition | Action |
|---|---|---|
| A | `!loan.disbursed? || loan.closed?` | Early return, `transitioned: nil`, `late_fees_applied: 0` |
| B | For each `p in loan.payments.ordered` where `p.pending? && p.due_date < @today` | `Payments::MarkOverdue.call(payment: p, today: @today)` |
| C | For each `p in loan.payments.reload.ordered` where `p.overdue? && p.late_fee_cents.to_i.zero?` | `Payments::ApplyLateFee.call(payment: p)`; increment `late_fees_applied` |
| D | `loan.payments.reload` | — |
| E | `loan.payments.any? && loan.payments.all?(&:completed?) && (loan.active? || loan.overdue?)` | `loan.close!` → `transitioned = :close`, short-circuit |
| F | `loan.active? && loan.payments.any?(&:overdue?)` | `loan.mark_overdue!` → `transitioned = :mark_overdue` |
| G | `loan.overdue? && loan.payments.none? { \|p\| p.overdue? \|\| (p.pending? && p.due_date < @today) }` | `loan.resolve_overdue!` → `transitioned = :resolve_overdue` |
| H | else | no-op, `transitioned: nil` |

Note: step E is checked BEFORE F/G so that a completion that happens to also be the final payment closes the loan in one pass rather than cycling `:overdue → :active → :closed` across two requests.

### Calculation and Edge Cases to Test

1. **Late fee fires once, at first overdue.** First `RefreshStatus` after the due date → fee applied. Second call → no-op. Third → no-op. (FR52 "exactly once".)
2. **Late fee does not change `total_amount_cents`.** Verify the ledger posting amount in `Loans::RecordRepayment` continues to be `total_amount_cents` and NOT `total_amount_cents + late_fee_cents`.
3. **Late fee is independent of payment completion.** A payment that transitions `:pending → :overdue → :completed` keeps its `late_fee_cents` post-completion (readonly guard locks further changes).
4. **Pending-today payment does not receive a late fee.** (Overdue boundary from Story 5.5 Calculation #1.)
5. **Late fee does NOT block completion.** `Payments::MarkCompleted` transitions from `:overdue` to `:completed` regardless of `late_fee_cents > 0`. Confirm via `spec/services/payments/mark_completed_spec.rb` regression (no new spec needed; existing pass).
6. **Closure requires completion of ALL payments.** Partial completion (N-1 complete, 1 pending) → no closure. Completion of all → closure.
7. **Closure short-circuits resolve_overdue.** A loan that is `:overdue`, the last overdue payment was just completed, and all other payments are also completed → `close` wins. Do NOT double-transition `overdue → active → closed` in one call; the single `close!` event handles it (AASM `close` event allows `:overdue → :closed` directly — see `app/models/loan.rb:81-83`).
8. **Closure is inert on already-closed loan.** Second `RefreshStatus` call → no-op, no exception.
9. **Closure on empty-schedule loan is suppressed.** Defensive guard — if `payments.none?`, closure does not fire.
10. **Idempotent sweep.** `Payments::DeriveOverdueStates` called twice consecutively → second run `late_fees_applied == 0`, `closed_loans == 0` (assuming no state drift between calls).
11. **Concurrent completion + refresh.** Two requests: one `mark_completed` the last payment, the other `GET /loans/:id`. `loan.with_lock` in `RefreshStatus` serializes; closure fires exactly once.
12. **PaperTrail coverage.** Both the `late_fee_cents` update and the `loan.status` `close` transition create `PaperTrail::Version` rows with the request's admin as whodunnit.
13. **Closed loan is read-only for details.** `Loan#editable_details?` returns false for `:closed` → loan edit form locks.
14. **Closed loan's payments remain visible and historically consistent** (AC #3 "record remains available for later operational review"). `loans#show` continues to render the repayment schedule, the disbursement invoice, the document list, and the borrower history for closed loans.
15. **Request freshness.** `GET /loans/:id` immediately after the last `mark_completed` renders `:closed` status on the very first load (no background job; Story 5.5 pattern).

### UX Requirements

- **No new UI surfaces, no new routes, no new components.** The late-fee row on `payments#show` already exists (line 183-188). Add ONE new row on `loans#show` for "Total late fees assessed" in the existing repayment summary grid. Do NOT add it as a new section.
- **Closed status rendering.** `status_tone` for `:closed` is `:neutral`, `status_label` is "Closed". The existing `Shared::StatusBadgeComponent` renders both; no component change needed.
- **No new flashes.** Derivation on read is silent. Closure happens without an alert; the admin sees the new state on the next page load.
- **Empty-state copy.** No changes required — the payments index empty states were already finalized in Story 5.5 (`view=overdue` copy) and Story 5.2.
- **Accessibility.** No new interactive elements; a11y surface unchanged. The new `<dt>`/`<dd>` row on `loans#show` follows the existing semantic pattern.
- **Semantic state distinguishable without color alone (UX-DR16).** Confirmed: status label text "Closed" is present alongside the neutral tone; no color-only distinction.
- **Dashboard, late-fee analytics, and closed-loan summary widgets are out of scope.** Story 6.1 owns the dashboard.

### Library / Framework Requirements

- **Rails ~> 8.1** — `with_lock`, `reload`, `update!`, `Current`, `ApplicationService`.
- **`aasm` ~> 5.5** — `loan.close!` and the `close` event already defined (`app/models/loan.rb:81-83`). No AASM config changes.
- **`paper_trail` ~> 17.0** — `Payment has_paper_trail` + `Loan has_paper_trail` already capture the late-fee update and the closure transition.
- **`money-rails`** — `monetize :late_fee_cents` already active (`app/models/payment.rb:13`); `humanized_money_with_symbol` already in use (`app/views/payments/show.html.erb:186`).
- **`factory_bot` ~> 6.5** — new `:with_late_fee` trait; default factory unchanged.
- **No new gems, no new DoubleEntry accounts, no new initializers.**

### Previous Story Intelligence (5.5)

- **`Loans::RefreshStatus` is the single ownership point for derived loan lifecycle transitions.** Story 5.5 deliberately composed the payment-level overdue loop + loan-level AASM arms inside one `loan.with_lock`. This story extends that exact boundary; do NOT split the service.
- **Read-surface hooks are already wired.** `LoansController#show`, `PaymentsController#show`, `PaymentsController#mark_completed`, and `PaymentsController#index` (via `Payments::DeriveOverdueStates`) all invoke `RefreshStatus`. Adding the late-fee pass and the `close!` arm to the existing service makes them active on every read surface automatically. Do NOT add new controller hooks.
- **`RefreshStatus` Result struct is the observability surface.** Story 5.5 added `transitioned:` and `changed?`; this story adds `late_fees_applied:`. Keep the same keyword-init struct pattern.
- **Rescue pattern is established.** Story 5.5 widened rescues to `AASM::InvalidTransition` and `ActiveRecord::RecordInvalid` with `Rails.logger.warn`. Reuse exactly; do NOT add bespoke error classes.
- **`Payment#readonly?` path is pre-validated.** Late-fee application fires from `:overdue`, where `status_was == "overdue"` (not `"completed"`); `readonly?` returns `false`, `update!` succeeds. The critical Story 5.3 invariant is untouched.
- **Deferred-work note from Story 5.3 line 12** — "future legitimate after-completion callbacks" — remains deferred. This story does NOT trigger any post-completion callbacks; the closure arm fires from the refresh service at the boundary of the `mark_completed` request, not from inside `Payments::MarkCompleted`.
- **Out-of-order installment completion is allowed (Story 5.3 deferred-work #15).** Closure rule E ("all payments completed") handles this naturally because it evaluates `all?(&:completed?)` without caring about installment order.

### Git Intelligence

Recent commits (last 5) and their relevance:

- `<recent>` **Derive overdue payment and loan states from recorded facts.** (Story 5.5) — Directly upstream. Installed `Payments::MarkOverdue`, `Loans::RefreshStatus`, `Payments::DeriveOverdueStates` and the read-surface hooks this story extends.
- `<recent-1>` **Generate payment invoice + repayment ledger posting on completion.** (Story 5.4) — Established the accounting boundary this story must not cross. The `DoubleEntry.transfer` amount remains `total_amount_cents` only.
- `67d1945` **Add guarded payment completion with locked financial history.** (Story 5.3) — Installed `Payment#readonly?`. This story's late-fee path lives strictly before completion, so `readonly?` stays intact.
- `74ec10b` **Add payment list, detail, and loan repayment-state visibility.** (Story 5.2) — Installed the `payments#show` Late fee row + the `payments#index` filter layout. Reused as-is here.
- `af4a085` **Add repayment schedule generation from loan disbursement.** (Story 5.1) — Established the `total_amount_cents = principal + interest` invariant. Late fee is a separate column; this invariant is unchanged.

**Preferred commit style:** `"Apply flat late fees and close loans from completed repayment facts."`

### Epic 4 and Epic 5 Retrospective Insights (Apply to This Story)

1. **"Money-critical work lives in domain services."** `Payments::ApplyLateFee` and the closure arm in `Loans::RefreshStatus` own the logic; controllers remain untouched.
2. **"Facts over toggles."** `late_fee_cents > 0` IS the late-fee fact; no `late_fee_applied?` flag. `status == "closed"` IS the closure fact; no `closed_at` or `auto_closed?` boolean.
3. **"Test discipline."** Full `bundle exec rspec` green. Expected new examples 18–25. `rubocop` clean.
4. **"Serialized writes on the same record."** `loan.with_lock` now spans three operations (overdue pass + fee pass + lifecycle arm). Under contention, this is the correct single-lock boundary; do NOT introduce a nested lock.
5. **"Scope every mutation."** `DeriveOverdueStates` continues to scope to loans with `status: %w[active overdue]` — closed loans are never visited, preventing wasted work and eliminating a re-close regression risk.

### Non-Goals (Explicit Scope Boundaries)

- **No late-fee remittance via DoubleEntry.** Assessment only (FR52). Settlement through the ledger is future work.
- **No tiered late-fee structure.** Single flat MVP amount (PRD line 159, FR52).
- **No admin-facing "Apply late fee" control.** Derivation only.
- **No admin-facing "Close loan" control.** Derivation only (PRD line 187).
- **No admin-facing "Reopen loan" control.** `:closed` is terminal for MVP.
- **No dashboard or portfolio widgets.** Story 6.1 owns that.
- **No late-fee reporting, aggregate view, or CSV export.**
- **No per-borrower or per-loan late-fee configuration.** One constant, one file.
- **No changes to `Payments::MarkCompleted`, `Loans::RecordRepayment`, `Invoices::IssuePaymentInvoice`, `Payment#readonly?`, `Payment#total_matches_components`, or the `DoubleEntry` initializer.**
- **No background jobs, schedulers, or cron entries.**
- **No new routes, controllers, or ViewComponents.**

### Project Context Reference

- No `project-context.md` found in repo. The PRD (`_bmad-output/planning-artifacts/prd.md`), architecture (`_bmad-output/planning-artifacts/architecture.md`), UX spec (`_bmad-output/planning-artifacts/ux-design-specification.md`), and Stories 5.1–5.5 are the authoritative sources.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md:857-878` — Story 5.6 BDD]
- [Source: `_bmad-output/planning-artifacts/epics.md:75-78` — FR52 late-fee application; FR55 loan closure]
- [Source: `_bmad-output/planning-artifacts/prd.md:159` — "single MVP flat late fee exactly once per installment; shown as a separate charge"]
- [Source: `_bmad-output/planning-artifacts/prd.md:183-189` — Loan Completion Journey; automatic closure when all payments complete]
- [Source: `_bmad-output/planning-artifacts/prd.md:261` — "derived lifecycle states ... system-controlled wherever possible"]
- [Source: `_bmad-output/planning-artifacts/prd.md:490-494` — FR52, FR55, FR56]
- [Source: `_bmad-output/planning-artifacts/architecture.md:46,250,813-815` — service boundaries for late fees + closure logic]
- [Source: `_bmad-output/planning-artifacts/architecture.md:693,697` — `loans/close.rb` and `payments/apply_late_fee.rb` placeholders (note: this story consolidates closure into `Loans::RefreshStatus` rather than a dedicated `Loans::Close` service)]
- [Source: `app/models/payment.rb:13,27,56-60` — `late_fee_cents` column, validation, `readonly?` contract]
- [Source: `app/models/loan.rb:53-84` — AASM `close` event from `:active, :overdue` to `:closed`]
- [Source: `app/services/loans/refresh_status.rb` — service to extend]
- [Source: `app/services/payments/mark_overdue.rb` — reference service shape for `ApplyLateFee`]
- [Source: `app/services/payments/derive_overdue_states.rb` — aggregate Result struct to extend]
- [Source: `app/views/payments/show.html.erb:183-188` — existing Late fee dt/dd pair (no change)]
- [Source: `app/views/loans/show.html.erb:462` — existing total_scheduled_amount row (add new row adjacent)]
- [Source: `_bmad-output/implementation-artifacts/5-5-derive-overdue-payment-and-loan-states.md` — Story 5.5 Dev Notes for the extension pattern]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:22-31` — Story 5.5 deferred items still deferred (not re-opened by this story)]

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- `bundle exec rspec spec/services/payments/apply_late_fee_spec.rb`
- `bundle exec rspec spec/services/loans/refresh_status_spec.rb spec/services/payments/derive_overdue_states_spec.rb`
- `bundle exec rspec spec/services/payments/apply_late_fee_spec.rb spec/services/loans/refresh_status_spec.rb spec/services/payments/derive_overdue_states_spec.rb spec/models/loan_spec.rb spec/requests/loans_spec.rb spec/requests/payments_spec.rb`
- `bundle exec rspec`
- `bundle exec rubocop app/models/loan.rb app/services/payments/late_fee_policy.rb app/services/payments/apply_late_fee.rb app/services/loans/refresh_status.rb app/services/payments/derive_overdue_states.rb spec/factories/payments.rb spec/services/payments/apply_late_fee_spec.rb spec/services/loans/refresh_status_spec.rb spec/services/payments/derive_overdue_states_spec.rb spec/models/loan_spec.rb spec/requests/loans_spec.rb spec/requests/payments_spec.rb`

### Completion Notes List

- Added `Payments::LateFeePolicy` and `Payments::ApplyLateFee` to assess a single flat late fee exactly once for overdue installments without changing scheduled totals, status, or ledger postings.
- Extended `Loans::RefreshStatus` and `Payments::DeriveOverdueStates` so overdue derivation now applies late fees, reports `late_fees_applied`, and closes loans automatically when every generated payment is completed.
- Added `Loan#total_late_fees_cents` and surfaced the aggregate on `loans#show`; kept payment detail late-fee visibility and existing controller refresh hooks unchanged.
- Added targeted service, model, factory, and request coverage for late-fee application, idempotency, read-surface freshness, and derived loan closure. Full `bundle exec rspec` and targeted `bundle exec rubocop` passed.

### File List

- `app/models/loan.rb`
- `app/services/loans/refresh_status.rb`
- `app/services/payments/apply_late_fee.rb`
- `app/services/payments/derive_overdue_states.rb`
- `app/services/payments/late_fee_policy.rb`
- `app/views/loans/show.html.erb`
- `spec/factories/payments.rb`
- `spec/models/loan_spec.rb`
- `spec/requests/loans_spec.rb`
- `spec/requests/payments_spec.rb`
- `spec/services/loans/refresh_status_spec.rb`
- `spec/services/payments/apply_late_fee_spec.rb`
- `spec/services/payments/derive_overdue_states_spec.rb`

## Change Log

- 2026-04-18: Created story for flat late-fee application and derived loan closure. Scope held to a single late-fee policy constant, a new `Payments::ApplyLateFee` service, an extension of `Loans::RefreshStatus` to run the fee pass and the `close!` arm, one new helper on `Loan`, and one new line on `loans#show`. No new migrations, no new gems, no new routes, no new controllers.
- 2026-04-19: Implemented the flat late-fee policy and assessment service, extended the overdue/closure derivation flow to apply first-time fees and automatically close fully completed loans, added the aggregate late-fee repayment-summary row, and expanded the service/model/request test coverage. Verified with full `bundle exec rspec` and targeted `bundle exec rubocop`.
