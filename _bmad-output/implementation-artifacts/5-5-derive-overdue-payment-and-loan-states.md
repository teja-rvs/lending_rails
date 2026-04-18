# Story 5.5: Derive Overdue Payment and Loan States

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want overdue repayment and overdue loan states derived automatically from recorded facts,
So that servicing status stays accurate without manual intervention.

## Acceptance Criteria

1. **Given** a payment passes its due date without completion
   **When** the system evaluates repayment state
   **Then** it marks the payment overdue automatically
   **And** the overdue state is derived from due dates and recorded payment facts rather than manual toggles

2. **Given** one or more loan payments are overdue
   **When** the system refreshes the related loan state
   **Then** the loan is marked overdue automatically
   **And** the loan status remains consistent with the underlying payment facts

3. **Given** overdue logic is implemented
   **When** the behavior is tested
   **Then** the derivation can be validated at the service level with deterministic date-based scenarios
   **And** dashboard or list visibility depends on that same canonical derived state

## Tasks / Subtasks

- [x] Task 1: Introduce `Payments::MarkOverdue` domain service (AC: #1, #3)
  - [x] 1.1 Create `app/services/payments/mark_overdue.rb` extending `ApplicationService`. Mirror the canonical `Result = Struct.new(:payment, :error, keyword_init: true) do def success? / def blocked?; end` shape used by `Payments::MarkCompleted` and `Loans::Disburse`.
  - [x] 1.2 Constructor: `def initialize(payment:, today: Date.current)`. The `today:` keyword MUST be injectable so specs can assert deterministic date scenarios without `travel_to`. Internally pass through as `@today = today.to_date`.
  - [x] 1.3 No-op guards (return `Result.new(payment: payment)` as success, NOT blocked, so callers can iterate a loan's full schedule without branching on "not applicable"):
    - If `payment.completed?` → no-op success (completed payments are permanently settled; see Story 5.3 readonly contract).
    - If `payment.overdue?` → no-op success (idempotent; allows repeated calls across page loads).
    - If `payment.due_date > @today` → no-op success (not yet due).
  - [x] 1.4 Transition guard: return `blocked("Payment is not in a state that can transition to overdue.")` unless `payment.may_mark_overdue?`. The current AASM config (`pending → overdue`) means this guard primarily defends against future states being added without a matching transition.
  - [x] 1.5 Transition: wrap the mutation in `payment.with_lock` (matches Story 5.3 pattern). Inside the lock, `payment.reload` then re-check the no-op guards (handles the race where another request completed the payment between check and lock). Call `payment.mark_overdue!` to fire the AASM transition.
  - [x] 1.6 Rescue `AASM::InvalidTransition` and return `blocked("Payment is not in a state that can transition to overdue.")` — never leak AASM exceptions to callers (matches `Payments::MarkCompleted` pattern).
  - [x] 1.7 Do NOT apply late fees here. Late fees are Story 5.6. Do NOT post anything to `DoubleEntry`. Overdue is a workflow fact, not a money event.
  - [x] 1.8 Do NOT update `updated_at` semantics or touch any column other than `status`. The AASM transition is the only side effect.

- [x] Task 2: Relax `Payment#readonly?` to allow the `pending → overdue` and `overdue → completed` transitions (AC: #1, #2)
  - [x] 2.1 In `app/models/payment.rb`, the current `readonly?` returns true whenever `status_was == "completed"`. That contract stays unchanged (Story 5.3 AC #3). The `pending → overdue` transition is already not blocked because `status_was == "pending"` when the transition fires. Verify this with a targeted spec (Task 6.3) — do NOT widen `readonly?` beyond its current shape.
  - [x] 2.2 Confirmed via Story 5.4 Dev Notes (line 105) and the deferred-work entry from Story 5.3: the `readonly?` guard already permits `mark_overdue!` because `status_was` is `"pending"` at mutation time. This task is a verification task, NOT a code change to `readonly?`. If the spec in 6.3 fails, do NOT modify `readonly?` — instead investigate the actual call path because widening `readonly?` would break Story 5.3 AC #3.
  - [x] 2.3 Do NOT add a `mark_overdue` reverse event or any `overdue → pending` transition. Overdue is a derived forward-only state until completion (back to `:completed` is already the AASM `mark_completed` event path — see `Payment` AASM `:pending, :overdue → :completed`).

- [x] Task 3: Introduce `Loans::RefreshStatus` domain service (AC: #2, #3)
  - [x] 3.1 Create `app/services/loans/refresh_status.rb` extending `ApplicationService`. Result shape: `Result = Struct.new(:loan, :transitioned, :error, keyword_init: true) do def success? = error.blank?; def blocked? = error.present?; def changed? = transitioned.present?; end`. `transitioned` is the symbol of the fired event (e.g. `:mark_overdue`, `:resolve_overdue`) or `nil` when nothing fired.
  - [x] 3.2 Constructor: `def initialize(loan:, today: Date.current)`. Inject `today:` the same way as `Payments::MarkOverdue`.
  - [x] 3.3 Scope: this service is responsible ONLY for the overdue ↔ active back-and-forth. It MUST NOT fire `close` or any other AASM event. Loan closure is Story 5.6's scope.
  - [x] 3.4 Derivation rules (apply in order, short-circuit after any transition):
    - If `loan.active?` and `loan.payments.any? { |p| p.overdue? }` → `loan.mark_overdue!` → return `Result.new(loan:, transitioned: :mark_overdue)`.
    - If `loan.overdue?` and `loan.payments.none? { |p| p.overdue? || (p.pending? && p.due_date < @today) }` → `loan.resolve_overdue!` → return `Result.new(loan:, transitioned: :resolve_overdue)`. (The pending-past-due arm matters because `Payments::MarkOverdue` runs inside `RefreshStatus` — see 3.6 — but BEFORE evaluating the loan arm. If for any reason a pending-past-due slipped through, do not resolve overdue with a still-unrecorded fact outstanding.)
    - Otherwise → no-op `Result.new(loan:, transitioned: nil)`.
  - [x] 3.5 All reads MUST use `loan.payments.reload` to see the freshly-transitioned payments from 3.6 (and any concurrent updates committed between the request's initial load and the refresh call). Do not rely on the `includes(:invoice)` chain from `LoansController#show` to be fresh.
  - [x] 3.6 Composition: the service first runs `Payments::MarkOverdue.call(payment: p, today: @today)` for every `payment` in `loan.payments.ordered` that is pending and past-due. Then evaluates 3.4. Running this in-line is correct because each `Payments::MarkOverdue` call is idempotent and no-ops on already-overdue / completed payments.
  - [x] 3.7 Transaction boundary: wrap the entire loan refresh (payment loop + loan AASM transition) in `loan.with_lock`. This is an AR row lock on the loan; it does NOT need `DoubleEntry.lock_accounts` because no ledger posting occurs. Rationale: serializes concurrent refreshes on the same loan so two requests don't fire conflicting transitions (`mark_overdue` + `resolve_overdue` race).
  - [x] 3.8 Rescue `AASM::InvalidTransition` at the loan boundary and return `blocked("Loan is not in a state that can refresh its overdue status.")`. This defends against loans in `:closed`, `:created`, `:documentation_in_progress`, or `:ready_for_disbursement` — those MUST be untouched by this service.
  - [x] 3.9 No-op for non-disbursed loans: if `!loan.disbursed?` (i.e. not `active || overdue || closed`), return success with `transitioned: nil` without touching the payment loop. Rationale: `payments.any?` is false pre-disbursement anyway, but short-circuiting keeps the service correct and cheap when called against freshly-created loans.
  - [x] 3.10 No-op for `:closed` loans: if `loan.closed?`, return success with `transitioned: nil`. Closed loans are terminal for Epic 5 scope.

- [x] Task 4: Wire derivation into read surfaces so page loads reflect latest committed state (AC: #1, #2, #3, NFR8)
  - [x] 4.1 In `app/controllers/loans_controller.rb#show`, call `Loans::RefreshStatus.call(loan: @loan)` AFTER `set_loan` and BEFORE `set_disbursement_readiness`. Reload `@loan` afterwards so the view sees the possibly-transitioned status. Ignore a `blocked?` result silently for non-disbursed / closed loans (the service already no-ops for those; the `blocked?` case is purely defensive). Do NOT show a flash — this is background derivation, not a user action.
  - [x] 4.2 In `app/controllers/payments_controller.rb#show`, call `Loans::RefreshStatus.call(loan: @payment.loan)` AFTER `set_payment`, then `@payment.reload`. Same rationale: opening a payment detail page must reflect its current derived state. Ignoring the result is intentional — this is freshness, not user flow.
  - [x] 4.3 In `app/controllers/payments_controller.rb#index`, run derivation across the visible scope BEFORE executing the filtered query. Specifically: find every `Payment.pending.where("due_date < ?", Date.current)` row, mark each overdue, then refresh each affected loan. To keep this cheap when the table is large, constrain to pending-past-due rows only (the `Payments::MarkOverdue` service is itself idempotent, but avoid iterating completed rows). Wrap in a single short-lived transaction per loan. See Task 4.4 for the composition helper.
  - [x] 4.4 Extract the shared "derive across all stale payments for a scope" composition into `Payments::DeriveOverdueStates` (new — `app/services/payments/derive_overdue_states.rb`). Contract:
    - `def initialize(today: Date.current); @today = today.to_date; end`
    - `def call` — SELECT pending payment IDs with `due_date < @today` (scoped via `Payment.pending.where("due_date < ?", @today).pluck(:id)`), GROUP the ids by `loan_id`, then for each loan fire `Loans::RefreshStatus.call(loan: loan, today: @today)` (the loan refresh itself loops over the payments). This keeps the payments loop OUT of the controller and puts it behind one service call.
    - Returns `Result.new(transitioned_payments: <count>, transitioned_loans: <count>, error: nil)` for observability in specs; ignore in controllers.
  - [x] 4.5 The `LoansController#index` does NOT call refresh (would loop across the full loan list on every dashboard hit). Freshness on that surface is acceptable because Story 6.1's dashboard is the action-first surface and it will drive refresh from its own widgets. DO NOT add derivation to the loan index in this story.
  - [x] 4.6 The dashboard (Story 6.1) is out of scope here. Do NOT create `app/controllers/dashboard_controller.rb` or any dashboard derivation hook.
  - [x] 4.7 In `PaymentsController#mark_completed`, inside the `if result.success?` branch, call `Loans::RefreshStatus.call(loan: result.payment.loan)` BEFORE the `redirect_to payment_path(...)` line. This lets a completion that drains the last overdue payment on a loan flip the loan back from `overdue → active` visibly on the next page load. The flash copy `"Payment #... recorded as completed."` MUST NOT change (Story 5.4 request spec asserts it exactly — only one additional line is added; no string change). Alternative location considered and REJECTED: putting the refresh inside `Loans::RecordRepayment` itself would couple a money-moving service to a workflow-derivation service — keep them composed at the controller seam instead.

- [x] Task 5: Ensure `payment_due_hint` and existing surface copy remain correct without change (AC: #1, #2)
  - [x] 5.1 `PaymentsHelper#payment_due_hint` already emits "Overdue by N days" for pending-past-due rows (Story 5.2). Once a payment is transitioned to `:overdue` by this story, the helper's arithmetic branch is unchanged (still `diff = payment.due_date - today`, still emits "Overdue by N days"). Do NOT alter this helper.
  - [x] 5.2 The `Loan#status_label` / `Loan#status_tone` methods already handle `:overdue` with `:danger` tone (see existing `app/models/loan.rb`). No change required.
  - [x] 5.3 The `Payment#status_label` / `Payment#status_tone` methods already handle `:overdue` with `:warning` tone. No change required.
  - [x] 5.4 The payments index empty-state copy currently reads: `No payments are currently marked overdue. Overdue derivation runs as part of a later story, so this list may remain empty until those facts are recorded.` Update `app/views/payments/index.html.erb` line 194 empty-state to: `No payments are currently overdue.` (remove the "later story" parenthetical — this IS that later story). Leave every other branch of the empty state unchanged.
  - [x] 5.5 Do NOT add new badges, new columns, new navigation, or new pages. The UI surfaces built in Story 5.2 (payments index, payments show, loans show repayment schedule + overdue counter) already render `:overdue` correctly as soon as the AASM state flips.

- [x] Task 6: Tests (AC: #1, #2, #3)
  - [x] 6.1 `spec/services/payments/mark_overdue_spec.rb` (new):
    - Happy path: a `pending` payment with `due_date < today` → service returns `success?`, `payment.reload.overdue?` is true.
    - Idempotency: a payment already `overdue` → `success?` with no state change (`payment.status_previously_changed?` is false).
    - No-op on completed: a `completed` payment → `success?` with no state change; MUST NOT raise `ActiveRecord::ReadOnlyRecord` (regression guard for the `Payment#readonly?` contract).
    - No-op on not-yet-due: a `pending` payment with `due_date == today` → `success?` with no state change (today is not past-due; overdue is strictly AFTER the due date).
    - No-op on due-today with injected `today` one day later works: `Payments::MarkOverdue.call(payment:, today: payment.due_date + 1)` → `payment.reload.overdue?`.
    - Deterministic `today:` injection: use `Date.new(2026, 5, 1)` style anchors; do NOT call `Date.current` inside `expect` blocks.
    - Blocked branch: stub `payment.may_mark_overdue?` to return false → service returns `blocked?` with the documented error message; do NOT leak `AASM::InvalidTransition`.
    - Row lock is acquired: `expect(payment).to receive(:with_lock).and_call_original` on the happy path.
    - PaperTrail: `payment.versions.last.event == "update"` and the `status` change is captured (existing `has_paper_trail` on `Payment` already handles this — the test documents the audit trail guarantee).
  - [x] 6.2 `spec/services/loans/refresh_status_spec.rb` (new):
    - Loan with one pending-past-due payment → calls `mark_overdue` on the payment, transitions the loan `active → overdue`, `result.transitioned == :mark_overdue`.
    - Loan with all pending payments in the future → no transition, `result.transitioned` is nil.
    - Loan with only completed payments (and `active` status) → no transition, `result.transitioned` is nil. (Closure is 5.6's concern; this service MUST NOT fire `close`.)
    - Back-flip: loan is `:overdue`, all overdue payments have since been completed (via `Loans::RecordRepayment` happy path in the setup), remaining pending are all future-dated → loan transitions `overdue → active`, `result.transitioned == :resolve_overdue`.
    - Back-flip guard: loan is `:overdue`, one completed, one still pending-past-due → the pending-past-due arm fires `Payments::MarkOverdue` first, so after the payment loop the loan still has an overdue payment → loan stays `:overdue`, `result.transitioned` is nil (no resolve).
    - No-op on `:closed` loan → `result.transitioned` is nil; no state change; NO exception raised.
    - No-op on `:ready_for_disbursement` loan (e.g. service called defensively before disbursement) → `result.transitioned` is nil; no state change.
    - Idempotency: calling the service twice in a row on the same state → second call no-ops with `result.transitioned == nil`.
    - Deterministic date injection: accept `today:` and verify one-day-before-due vs one-day-after-due scenarios on the same loan produce opposite results.
    - Row lock: `expect(loan).to receive(:with_lock).and_call_original`.
  - [x] 6.3 `spec/models/payment_spec.rb` (extend):
    - `Payment#readonly?` does NOT block the `pending → overdue` transition: create pending payment with `due_date < today`, call `payment.mark_overdue!`, expect `payment.reload.overdue?` is true (no `ActiveRecord::ReadOnlyRecord` raised). This is the regression guard promised in Task 2.1.
    - `Payment#readonly?` DOES still block the `completed → *` mutation path (Story 5.3 contract): create a completed payment via `Loans::RecordRepayment`, call `payment.update(notes: "changed")`, expect the update is a no-op (`payment.reload.notes` unchanged). Do NOT modify `Payment#readonly?` just because this test is added — it is the invariant Story 5.3 established.
  - [x] 6.4 `spec/services/payments/derive_overdue_states_spec.rb` (new):
    - Two loans, loan A has one pending-past-due payment, loan B has one pending-future payment → call `Payments::DeriveOverdueStates.call` → loan A payment is overdue, loan A loan is overdue, loan B untouched.
    - Idempotency: calling twice in a row → second call result has `transitioned_payments: 0, transitioned_loans: 0`.
    - Cheap-scan property: a loan with 100 completed payments and 0 pending → `transitioned_payments == 0, transitioned_loans == 0`; stub `Payments::MarkOverdue` NOT to receive `call` on any of the completed payments (guards against iterating completed rows).
  - [x] 6.5 `spec/requests/loans_spec.rb` (extend):
    - Given a disbursed loan with a pending-past-due payment that has NOT been refreshed, `GET /loans/:id` renders the loan with status `overdue` (assert the status badge text is "Overdue") and the repayment-schedule "Overdue installments" counter is 1 (regression guard that the show action calls `RefreshStatus` — see Task 4.1).
    - Given a disbursed loan with only future-dated payments, `GET /loans/:id` renders status `active` and "Overdue installments" counter is 0. (Freshness must not fabricate overdue state.)
    - Given a `:ready_for_disbursement` loan (never disbursed, no payments), `GET /loans/:id` renders successfully (no 500) — regression guard for the no-op path in `RefreshStatus` 3.9.
    - Given a `:closed` loan (manually set for the test via `loan.update_columns(status: "closed")` — controlled test stub; do NOT add a `close` transition in this story), `GET /loans/:id` renders successfully with no state mutation.
  - [x] 6.6 `spec/requests/payments_spec.rb` (extend):
    - `GET /payments/:id` on a pending-past-due payment → response renders with payment status badge "Overdue" after the action completes (freshness guarantee via Task 4.2). Reload the payment in the spec and assert `payment.reload.overdue?`.
    - `GET /payments` (index) with a pending-past-due payment → after the request, `payment.reload.overdue?` is true; additionally, assert `Payment.overdue.count` equals the pre-existing overdue rows + the newly-derived row.
    - `GET /payments?view=overdue` after derivation → the pending-past-due payment appears in the response body.
    - Existing `mark_completed` request specs must remain green: add no new assertions to them; confirm the `Loans::RefreshStatus.call` hook from Task 4.7 does NOT change the success flash (Story 5.4 spec asserts the exact string).
    - Back-flip request spec: a loan has exactly one pending-past-due payment which pushed it to `:overdue` on a prior show. Mark that payment completed via `PATCH /payments/:id/mark_completed` with valid data → after the request, `loan.reload.active?` is true (the completion drained the last overdue payment; `Loans::RefreshStatus` fired from Task 4.7).
  - [x] 6.7 `spec/models/loan_spec.rb` (extend):
    - Verify `loan.may_mark_overdue?` is true from `:active` only, false from `:created`, `:documentation_in_progress`, `:ready_for_disbursement`, `:overdue`, `:closed`. (Documents the AASM guard the service relies on.)
    - Verify `loan.may_resolve_overdue?` is true from `:overdue` only.
  - [x] 6.8 Run `bundle exec rspec` green; expect roughly 25–35 new examples. Run `bundle exec rubocop` green on all touched files.

### Review Findings

_Generated by code review on 2026-04-18 against uncommitted changes for story 5-5._

- [x] [Review][Patch] Widen rescue in `Loans::RefreshStatus#call` to also catch `ActiveRecord::RecordInvalid` [app/services/loans/refresh_status.rb:49] — Only `AASM::InvalidTransition` is caught. If `payment.mark_overdue!` or `loan.mark_overdue!` raises `ActiveRecord::RecordInvalid` (e.g. a disbursed-yet-validation-failing record, callback failure), the exception escapes `with_lock`, rolls back the lock tx, and bubbles a 500 to the controller. Same concern for the nested call inside the loop.
- [x] [Review][Patch] Rescue per-iteration failures in `Payments::DeriveOverdueStates#call` [app/services/payments/derive_overdue_states.rb:20-27] — A single raising loan (e.g. `Loan.find` race-deletion or downstream error) aborts the entire sweep and 500s every subsequent `/payments` index GET. Wrap the per-loan iteration in a `rescue => e` that logs and continues; surface counts of failed loans in the `Result` for observability.
- [x] [Review][Patch] Add `Rails.logger.warn` when `AASM::InvalidTransition` is rescued [app/services/payments/mark_overdue.rb:33; app/services/loans/refresh_status.rb:49] — Silent rescue of `AASM::InvalidTransition` makes race-condition bugs invisible. The outer `may_*?` guards mean reaching this rescue is always a race or a stale guard — exactly the case that should be logged.
- [x] [Review][Patch] Preserve eager-loaded associations after `@loan.reload` / `@payment.reload` [app/controllers/loans_controller.rb:13; app/controllers/payments_controller.rb:21] — `set_loan` uses `Loan.includes(:borrower, :loan_application, :invoices, :payments, document_uploads: [...])` and `set_payment` uses `Payment.includes(loan: :borrower)`. The `.reload` call drops those preloads, reintroducing N+1 in view rendering. Options: re-invoke `set_loan` / `set_payment`, or re-query with the same `includes`.
- [x] [Review][Patch] Pre-filter loans by disbursed/overdue status in `Payments::DeriveOverdueStates` [app/services/payments/derive_overdue_states.rb:14-21] — Each candidate `loan_id` triggers `Loan.find` + 2 count queries + `with_lock` round-trip, even for loans in `:closed` / `:created` / `:ready_for_disbursement` states where `RefreshStatus` immediately short-circuits. Replace `loan_ids.each { |id| Loan.find(id) ... }` with `Loan.where(id: loan_ids, status: %w[active overdue]).find_each`.
- [x] [Review][Patch] Simplify `stale_ids` pluck and rename [app/services/payments/derive_overdue_states.rb:14-15] — `pluck(:id, :loan_id)` returns tuples but only the second column is used; rename to `loan_ids` and use `pluck(:loan_id).uniq`. (Cosmetic; reduces reader confusion.)
- [x] [Review][Patch] Replace fragile before/after count-delta with a direct tally for `transitioned_payments` [app/services/payments/derive_overdue_states.rb:17-25] — Kept the before/after delta (simpler than threading per-payment return values through `RefreshStatus`) but added a `failed_loans` counter to the Result struct so the service surfaces per-iteration errors for observability. Documented that `transitioned_payments` is approximate under concurrency via the rescue-and-log pattern.
- [x] [Review][Defer] GET requests mutate DB state via inline read-surface derivation [app/controllers/loans_controller.rb:12; app/controllers/payments_controller.rb:5,20] — deferred, by design per Story 5.5 Dev Notes line 144 ("inline derivation on read is sufficient for MVP"; background job explicitly rejected for this story). Revisit when freshness SLA changes or dashboard story drives scheduled refresh.
- [x] [Review][Defer] `Payments::DeriveOverdueStates` runs unbounded on every `/payments` index hit; O(stale_loans) lock contention under load — deferred, accepted trade-off per Task 4.5 rationale (index of loans explicitly not refreshed for the same cost concern; payments index is much smaller operational surface).
- [x] [Review][Defer] Race between `Loans::RecordRepayment` commit and concurrent `Loans::RefreshStatus` on the same loan row — deferred, explicitly acknowledged in Story Dev Notes Calculation Edge Case #5 ("never a corrupt hybrid; next request fixes it"). A proper fix requires pushing loan row lock into `RecordRepayment` which is cross-story (Story 5.4's boundary).
- [x] [Review][Defer] Controllers silently ignore `RefreshStatus` blocked results with no log or flash [app/controllers/loans_controller.rb:12; app/controllers/payments_controller.rb:20,33] — deferred, by design per Task 4.1 ("Ignore a `blocked?` result silently ... Do NOT show a flash"). Worth revisiting if observability becomes a requirement; pair with the `Rails.logger.warn` patch above for minimum coverage.
- [x] [Review][Defer] No authorization check before state-mutating derivation in controllers — deferred, pre-existing repo-wide concern (no policy layer present). PaperTrail whodunnit will attribute derived transitions to whichever user opened the page.
- [x] [Review][Defer] PaperTrail whodunnit attributes automated derivations to the request user — deferred, same root cause as authorization gap; a `PaperTrail.request(whodunnit: "system:overdue_derivation") { ... }` wrapper would be a targeted mitigation but introduces a project-wide pattern that should be discussed before landing.
- [x] [Review][Defer] Time-zone mismatch between `Date.current` (Time.zone) and stored `due_date` — deferred, application-wide TZ concern outside story scope. Document once business TZ is defined.
- [x] [Review][Defer] Potential deadlock between `Loans::RefreshStatus` (loan → payment lock order) and `Payments::MarkCompleted` (payment-only lock) — deferred, InnoDB will detect and roll back one transaction; user sees the rescue path. A proper fix requires unifying lock ordering across Story 5.3/5.4/5.5 services.

## Dev Notes

### Epic 5 Cross-Story Context

- **Epic 5** covers repayment servicing, overdue control, and loan closure (FR40–FR56, FR72).
- **Story 5.1 (done)** — `Loans::GenerateRepaymentSchedule` + `Payment` records with `:pending`/`:completed`/`:overdue` AASM states.
- **Story 5.2 (done)** — payments list/detail read surfaces, `payment_due_hint` helper, `Payments::FilteredListQuery` with `view=overdue` filter. The index empty state for `view=overdue` currently tells the admin "overdue derivation runs as part of a later story" — THAT story is this one.
- **Story 5.3 (done)** — `Payments::MarkCompleted` + `Payment#readonly?` (blocks UPDATE only when `status_was == "completed"`, so the `pending → overdue` transition is permitted).
- **Story 5.4 (done)** — `Loans::RecordRepayment` composes `Payments::MarkCompleted` + `Invoices::IssuePaymentInvoice` + `DoubleEntry.transfer` under `DoubleEntry.lock_accounts`. Explicitly deferred overdue derivation to this story (see 5.4 Task 4.8 and Dev Notes line 105).
- **This story (5.5)** — adds `Payments::MarkOverdue`, `Loans::RefreshStatus`, `Payments::DeriveOverdueStates`; calls them from read surfaces (loans#show, payments#show, payments#index) and from the `mark_completed` controller action after a successful repayment. No new UI. No late fees. No loan closure.
- **Story 5.6 (backlog)** — will add `Payments::ApplyLateFee` and `Loans::Close` (closure from completed repayment facts). Do NOT add those services here. Do NOT fire `loan.close!` from `RefreshStatus`.

### Critical Architecture Constraints

- **Derivation lives in domain services, never in views or controllers.** [Source: `_bmad-output/planning-artifacts/architecture.md:250`] The controller's only responsibility is to call the service and ignore its result for silent freshness — or redirect with a flash for user-driven actions (which this story has none of).
- **Page loads reflect the latest committed system state (NFR8).** [Source: `_bmad-output/planning-artifacts/epics.md:111`] This is why the derivation hook is on `#show` and `#index` instead of a background job. The architecture mentions `mark_overdue_payments_job.rb` for future scheduling; do NOT create that job in this story — inline derivation on read is sufficient for MVP.
- **Dashboard/list visibility depends on the same canonical derived state (AC #3 "And" clause).** The filter `view=overdue` already reads `Payment.where(status: "overdue")`; after this story, its result set includes rows derived by `Payments::MarkOverdue`. No query-layer changes required — the query already resolves `:overdue` status. [Source: `app/queries/payments/filtered_list_query.rb:5-9`]
- **Facts over toggles (Epic 4 Retro line 98).** Overdue is a derived fact from `payment.due_date` + `payment.status`. Do NOT add boolean columns like `is_overdue`, `overdue_flag`, or `overdue_since`. The AASM state IS the fact.
- **No `DoubleEntry` postings in derivation services.** Overdue is a workflow transition, not a money event. Only `Loans::Disburse` and `Loans::RecordRepayment` move money. [Source: Story 5.4 Dev Notes; `app/services/loans/disburse.rb`]
- **Controllers stay thin.** The derivation hook in each controller is a single `.call(...)` line plus an optional `@record.reload`. No conditional logic, no error branching, no flash. [Source: `app/controllers/loans_controller.rb` precedent]
- **No new gems.** Service + specs only.
- **No new migrations.** `Payment.status` already supports `:overdue`; `Loan.status` already supports `:overdue`. `payment.overdue?` and `loan.overdue?` are already defined via AASM.
- **Row-level locks, not advisory locks.** `payment.with_lock` and `loan.with_lock` serialize concurrent derivations on the same record. Do NOT use `pg_advisory_lock` or `DoubleEntry.lock_accounts` — wrong tool for a non-money workflow transition.

### Files NOT to Create or Modify

- Do NOT create `app/jobs/mark_overdue_payments_job.rb` or `app/jobs/overdue_recalculation_job.rb` — inline derivation on read is the MVP approach; background jobs arrive later when scheduled freshness becomes a requirement.
- Do NOT create `DashboardController` or any dashboard surface. Story 6.1 owns that.
- Do NOT modify `Payment#readonly?`. The Story 5.3 invariant must hold; a targeted spec proves `pending → overdue` works under the existing implementation.
- Do NOT modify `Payments::MarkCompleted` or `Loans::RecordRepayment`. Compose around them; do not mutate them.
- Do NOT modify the `DoubleEntry` initializer. No new accounts, no new transfers.
- Do NOT create `Loans::Close` or `Payments::ApplyLateFee` (Story 5.6).
- Do NOT touch `app/controllers/loans_controller.rb#index`. Refreshing every loan on every index hit would be O(loans) per page load; that scaling concern is real and unnecessary for MVP.
- Do NOT add a background scheduler config (`recurring.yml`, cron, `solid_queue` recurring entry).
- Do NOT change the `payment_due_hint` helper or its spec. The helper is presentation-only and already correct.
- Do NOT add an explicit "Mark overdue" button or admin action to any UI. Overdue is derived, not user-triggered.
- Do NOT introduce an `OverdueController` or any overdue-specific route. The existing `GET /payments?view=overdue` is the canonical surface.

### File Structure (Expected Touchpoints)

| Area | Files |
|------|--------|
| New | `app/services/payments/mark_overdue.rb` |
| New | `app/services/loans/refresh_status.rb` |
| New | `app/services/payments/derive_overdue_states.rb` |
| New | `spec/services/payments/mark_overdue_spec.rb` |
| New | `spec/services/loans/refresh_status_spec.rb` |
| New | `spec/services/payments/derive_overdue_states_spec.rb` |
| Modify | `app/controllers/loans_controller.rb` — call `Loans::RefreshStatus` in `#show` |
| Modify | `app/controllers/payments_controller.rb` — call `Loans::RefreshStatus` in `#show`, `Payments::DeriveOverdueStates` in `#index`, and `Loans::RefreshStatus` after `Loans::RecordRepayment` success in `#mark_completed` |
| Modify | `app/views/payments/index.html.erb` — empty-state copy (remove "later story" parenthetical) |
| Modify | `spec/models/payment_spec.rb` — regression for `readonly?` + `pending → overdue` |
| Modify | `spec/models/loan_spec.rb` — document `may_mark_overdue?` / `may_resolve_overdue?` |
| Modify | `spec/requests/loans_spec.rb` — freshness assertions on `GET /loans/:id` |
| Modify | `spec/requests/payments_spec.rb` — freshness assertions on `GET /payments/:id`, `GET /payments`, and back-flip after `mark_completed` |

### Existing Patterns to Follow

1. **`Payments::MarkCompleted` service shape** — authoritative reference for the `Payments::MarkOverdue` service. Copy the `Result` struct, `blocked(...)` helper, `payment.with_lock { payment.reload; re-check; transition! }` pattern, and `rescue AASM::InvalidTransition` block. [Source: `app/services/payments/mark_completed.rb`]
2. **`Loans::Disburse` outer-boundary pattern** — reference for the service-level transaction boundary, though `RefreshStatus` uses `loan.with_lock` (row lock) instead of `DoubleEntry.lock_accounts` because no ledger posting occurs. [Source: `app/services/loans/disburse.rb`]
3. **`Payments::FilteredListQuery`** — reads `Payment.where(status: "overdue")` for the `view=overdue` filter; confirms that flipping `status → "overdue"` is sufficient for list visibility (AC #3's second clause). [Source: `app/queries/payments/filtered_list_query.rb:5`]
4. **`payment_due_hint` (presentation only)** — already emits "Overdue by N days" based on `payment.due_date - today` arithmetic, regardless of AASM state. The helper and its spec are the precedent for keeping presentation logic out of AASM transitions. [Source: `app/helpers/payments_helper.rb`]
5. **`Current.user` context** — `ApplicationController` already sets `Current.user` and `set_paper_trail_whodunnit` for the request cycle. Any service called inside a controller inherits the whodunnit for PaperTrail. [Source: `app/controllers/application_controller.rb`; Story 5.4 Dev Notes line 193]
6. **Thin controller dispatch** — one-line service call, optional `@record.reload`, no flash for derivation (only for user actions). [Source: `app/controllers/loans_controller.rb#disburse`]

### Derivation Rules (Reference Table)

| Scenario | Pre-state | `Payments::MarkOverdue` result | `Loans::RefreshStatus` result |
|---|---|---|---|
| Pending, `due_date < today` | payment: `:pending`, loan: `:active` | payment → `:overdue` | loan → `:overdue` (`transitioned: :mark_overdue`) |
| Pending, `due_date == today` | payment: `:pending`, loan: `:active` | no-op (strictly AFTER due) | no-op |
| Pending, `due_date > today` | payment: `:pending`, loan: `:active` | no-op | no-op |
| Completed | payment: `:completed`, loan: `:active` or `:overdue` | no-op (Task 1.3) | evaluates remaining payments |
| Already overdue | payment: `:overdue`, loan: `:overdue` | no-op (idempotent) | no-op (idempotent) |
| Last overdue payment just completed | payment: `:completed`, loan: `:overdue`, no other overdue rows, all others future-dated | no-op on the completed row | loan → `:active` (`transitioned: :resolve_overdue`) |
| Loan `:closed`, any payment state | — | no-op | no-op (Task 3.10) |
| Loan `:ready_for_disbursement`, no payments | — | N/A | no-op (Task 3.9) |

### UX Requirements

- **No new UI surfaces.** The admin sees overdue state automatically where Story 5.2 already surfaced it: `Payments#index` `view=overdue`, `Payments#show` status badge, `Loans#show` status badge + "Overdue installments" counter + `payment_due_hint` phrases.
- **No new flash messages.** Derivation on read is silent. The admin sees the new state directly.
- **Empty-state copy update on payments index.** Current copy (Story 5.2) references "a later story" — update to a present-tense statement (Task 5.4).
- **Semantic state must remain distinguishable without color alone (UX-DR16).** Confirmed: `Payment#status_label` returns the human-readable "Overdue" string and `Payment#status_tone` returns `:warning`; the shared `Shared::StatusBadgeComponent` renders both label and tone. No component change needed.
- **Accessibility.** No new interactive elements; a11y surface unchanged.
- **"Action-first" dashboard stays out of scope.** Story 6.1 owns the dashboard. This story makes the overdue derivation available so 6.1 can rely on `Payment.overdue` and `Loan.overdue` scopes directly.

### Library / Framework Requirements

- **Rails ~> 8.1** — `with_lock`, `reload`, `Current`, `ApplicationService` base class.
- **`aasm` ~> 5.5** — `payment.mark_overdue!`, `loan.mark_overdue!`, `loan.resolve_overdue!` already defined. No AASM config changes.
- **`paper_trail` ~> 17.0** — `Payment has_paper_trail` and `Loan has_paper_trail` already active; status-change versions are captured for free when the AASM transitions fire inside the request cycle.
- **`factory_bot` ~> 6.5** — existing `payments` and `loans` factories already support `:pending`, `:overdue`, `:completed` traits; no factory changes needed.
- **No new gems.** Service + specs + one-line controller hooks + one string change in one ERB view.

### Calculation and Edge Cases to Test

1. **Boundary: `due_date == today`.** MUST NOT be overdue. Overdue is strictly AFTER the due date. Deterministic spec with `today: Date.new(2026, 5, 1)` and `due_date: Date.new(2026, 5, 1)` → no transition.
2. **Boundary: `due_date == today - 1.day`.** MUST be overdue.
3. **Idempotency: repeated `Payments::MarkOverdue`.** Second call no-ops with `success?` true and `payment.status_previously_changed?` false.
4. **Back-flip: `:overdue → :active`.** After all overdue payments complete and no other pending-past-due rows remain, `Loans::RefreshStatus` fires `resolve_overdue`.
5. **Concurrent completion + refresh.** Two simultaneous requests: one marks the last overdue payment completed (via `Loans::RecordRepayment`), the other hits `/loans/:id`. `loan.with_lock` in `RefreshStatus` serializes; the outcome is deterministic (either the completion committed first and refresh sees `:active`-eligible state, or the refresh sees `:overdue` and is a no-op; never a corrupt hybrid).
6. **Partial completion with remaining pending-past-due.** `:overdue` loan with 5 overdue payments; 3 complete, 2 remain overdue → loan stays `:overdue`.
7. **Closed loans are inert.** `loan.closed?` → service no-ops; no exception, no state mutation.
8. **Non-disbursed loans are inert.** `loan.ready_for_disbursement?` → service no-ops; no payments to scan.
9. **`Payment#readonly?` does not block `pending → overdue`.** Critical regression guard for the Story 5.3 contract.
10. **`Payment#readonly?` continues to block `completed → *` updates.** Story 5.3 AC #3 must hold.
11. **Out-of-order installment overdue.** Installment #5 is pending-past-due while #1–#4 are still pending-future → ONLY #5 transitions to `:overdue`; the loan transitions to `:overdue` because the filter is "any payment overdue", not "all installments past in order". (Consistent with the deferred-work note from Story 5.3 about out-of-order completion.)
12. **Scope isolation.** Deriving overdue on loan A MUST NOT transition loan B's payments or status. `Payments::DeriveOverdueStates` must scope every mutation to one loan at a time via the group-by-loan-id step.
13. **PaperTrail coverage.** A `:pending → :overdue` transition creates a new `PaperTrail::Version` on the payment with `event: "update"` and `object_changes` including `status: ["pending", "overdue"]`.
14. **Request freshness.** A `GET /loans/:id` on a loan with a newly-past-due payment renders the page showing `:overdue` on the very first request after the due date passes — no background job required.

### Previous Story Intelligence (5.4 and 5.3)

- **`Loans::RecordRepayment` success path is the trigger for back-flip.** After a completion that drains the last overdue payment on a loan, the loan MUST flip `:overdue → :active`. Story 5.4 Dev Notes line 105 explicitly deferred this to 5.5. Hook it in `PaymentsController#mark_completed` (Task 4.7) not in the service itself — preserves the money-moving service boundary.
- **`Payments::MarkCompleted` accepts `:pending` and `:overdue` as starting states.** AASM event `mark_completed` fires from either; Story 5.3 Task 1.6's "may_mark_completed?" guard handles both. No change required here.
- **Flash copy on `mark_completed` is asserted byte-for-byte in Story 5.4 request spec.** Do NOT change it (Task 4.7 is explicit).
- **`Payment#readonly?` is the tightest contract in the module.** It returns `true` iff `status_was == "completed"`. The `pending → overdue` transition fires when `status_was == "pending"`, so `readonly?` is false at transition time → the `save!` inside `mark_overdue!` succeeds. Story 5.3 deferred-work notes that a future overdue derivation would need to "navigate around readonly?" — confirmed here that NO navigation is needed; the existing implementation is already correct. [Source: `app/models/payment.rb:56-60`; `_bmad-output/implementation-artifacts/deferred-work.md:12`]
- **Out-of-order installment completion is allowed.** Story 5.3 deferred-work #15 documents this. Overdue derivation must therefore be per-payment, not per-position-in-schedule.

### Git Intelligence

Recent commits (last 5) and their relevance:

- `<recent>` **Add payment invoice and repayment ledger posting on completion.** — Directly upstream. Installed `Loans::RecordRepayment` which 5.5 hooks into for back-flip (Task 4.7).
- `67d1945` **Add guarded payment completion with locked financial history.** — Installed `Payments::MarkCompleted` + `Payment#readonly?`. 5.5 relies on the existing shape of both without modifying them.
- `74ec10b` Add payment list, detail, and loan repayment-state visibility. — Installed `Payments::FilteredListQuery` (the `view=overdue` filter that becomes populated after this story) and `payment_due_hint` (already emits "Overdue by N days").
- `af4a085` Add repayment schedule generation from loan disbursement. — Installed `Payment` records with AASM `:overdue` state already defined.
- `af1d56d` Add guarded disbursement financial records and invoice handling. — The `Loans::Disburse` pattern; informs the service shape (though this story uses row locks, not `DoubleEntry.lock_accounts`).

**Preferred commit style:** `"Derive overdue payment and loan states from recorded facts."`

### Epic 4 Retrospective Insights (Apply to This Story)

1. **"Money-critical work lives in domain services."** Derivation isn't money-moving, but the same discipline applies: `Payments::MarkOverdue`, `Loans::RefreshStatus`, and `Payments::DeriveOverdueStates` own the logic; controllers are dispatchers. [Source: Epic 4 Retro]
2. **"Facts over toggles."** Overdue derivation is the canonical example: `due_date < today` AND `status == "pending"` is the fact; the AASM state is the durable representation. No booleans, no `overdue_flag`, no `overdue_since`. [Source: Epic 4 Retro line 98]
3. **"Test discipline."** Full `bundle exec rspec` must pass; expected new examples 25–35. Keep `bundle exec rubocop` clean. [Source: Epic 4 Retro line 42]
4. **"Serialized writes on the same record."** `with_lock` on both payment and loan serializes concurrent refreshes; this is the same class of concurrency defense used by `create_with_next_loan_number!` and `create_with_next_invoice_number!`, just tighter because it scopes to one row. [Source: Epic 4 Retro line 48]

### Non-Goals (Explicit Scope Boundaries)

- **No late fees.** Story 5.6.
- **No loan closure.** Story 5.6.
- **No scheduled background job.** Inline derivation on read is the MVP approach.
- **No dashboard.** Story 6.1.
- **No new UI surface, no new route, no new badge variant.**
- **No PaperTrail changes.** The existing `has_paper_trail` on `Payment` and `Loan` captures the status transitions automatically inside the request cycle.
- **No `DoubleEntry` postings.**
- **No changes to `Payment#readonly?`, `Payments::MarkCompleted`, `Loans::RecordRepayment`, `Invoices::IssuePaymentInvoice`, or the `double_entry` initializer.**

### Project Context Reference

- No `project-context.md` found in repo. The PRD (`_bmad-output/planning-artifacts/prd.md`), architecture (`_bmad-output/planning-artifacts/architecture.md`), UX spec (`_bmad-output/planning-artifacts/ux-design-specification.md`), and Stories 5.1–5.4 are the authoritative sources.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md:834-855` — Story 5.5 BDD]
- [Source: `_bmad-output/planning-artifacts/epics.md:74-78` — FR51 overdue payment derivation, FR54 loan overdue derivation]
- [Source: `_bmad-output/planning-artifacts/architecture.md:46` — "overdue derivation ... in deterministic, independently testable domain services"]
- [Source: `_bmad-output/planning-artifacts/architecture.md:250` — "dedicated service boundaries for ... overdue derivation"]
- [Source: `_bmad-output/planning-artifacts/architecture.md:46-47,250,812-815` — testability + service boundaries]
- [Source: `_bmad-output/planning-artifacts/architecture.md:612-616,866-867` — future job locations (NOT in scope for this story)]
- [Source: `app/models/payment.rb:38-50` — AASM `:pending → :overdue` and `:pending,:overdue → :completed`]
- [Source: `app/models/loan.rb:53-84` — AASM `:active ↔ :overdue`, `:active,:overdue → :closed`]
- [Source: `app/services/payments/mark_completed.rb` — reference service shape]
- [Source: `app/services/loans/record_repayment.rb` — composer the back-flip piggybacks on]
- [Source: `app/queries/payments/filtered_list_query.rb:5-9` — `view=overdue` already filters by `status: "overdue"`]
- [Source: `app/helpers/payments_helper.rb` — `payment_due_hint` "Overdue by N days" phrasing]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:12,15` — 5.3 deferred notes pointing at this story]
- [Source: `_bmad-output/implementation-artifacts/5-4-generate-payment-financial-records-and-preserve-the-accounting-boundary.md:105` — 5.4 deferred derivation to 5.5]

## Dev Agent Record

### Agent Model Used

Opus 4.7 (Cursor)

### Debug Log References

- Initial run of `Payments::MarkOverdue` spec revealed that the task spec (Task 1.3: no-op when `due_date > today`) diverged from Dev Notes Calculation #1 ("Boundary: due_date == today MUST NOT be overdue"). Followed the Dev Notes boundary — treat `due_date == today` as no-op — and implemented the no-op guard as `payment.due_date >= @today` in both the initial guard and the re-check inside `with_lock`.
- PaperTrail in this project is configured without `object_changes`. Spec adjusted from `object_changes` inspection to a version-count assertion that verifies an `update`-event `PaperTrail::Version` is created when the status transition fires.
- `Loan#reload` after `Loans::RefreshStatus.call` inside `LoansController#show` re-fetches the AR record; eager-loaded associations from `set_loan` are dropped, but the subsequent view access re-queries them. No regressions seen in `spec/requests/loans_spec.rb`.

### Completion Notes List

- Introduced `Payments::MarkOverdue` (`app/services/payments/mark_overdue.rb`) following the `Payments::MarkCompleted` shape: keyword-init `Result`, `payment.with_lock` pattern, re-checked no-op guards inside the lock, `AASM::InvalidTransition` rescued at the boundary. Injectable `today:` for deterministic date specs.
- Introduced `Loans::RefreshStatus` (`app/services/loans/refresh_status.rb`): loops idempotently through pending-past-due payments, fires `Payments::MarkOverdue` per payment under the loan row lock, then applies the overdue/active derivation rules. Scope guarded to `:active` and `:overdue` loans only — `:closed` and non-disbursed loans short-circuit. Does NOT fire `close` (Story 5.6's scope).
- Introduced `Payments::DeriveOverdueStates` (`app/services/payments/derive_overdue_states.rb`): SELECTs pending payment IDs with `due_date < today`, groups by `loan_id`, and delegates per-loan refresh to `Loans::RefreshStatus`. Returns observability counts for specs; controllers ignore the result.
- Wired derivation into read surfaces (controllers only — no service mutation):
  - `LoansController#show` — `Loans::RefreshStatus.call(loan: @loan)` + `@loan.reload` before readiness evaluation.
  - `PaymentsController#show` — `Loans::RefreshStatus.call(loan: @payment.loan)` + `@payment.reload`.
  - `PaymentsController#index` — `Payments::DeriveOverdueStates.call` before `FilteredListQuery.call`.
  - `PaymentsController#mark_completed` — `Loans::RefreshStatus.call(loan: result.payment.loan)` in the `result.success?` branch BEFORE the redirect; flash copy unchanged byte-for-byte (Story 5.4 assertion preserved).
  - `LoansController#index` intentionally NOT touched (O(loans) cost was documented as rejected).
- Updated the `view=overdue` empty-state copy in `app/views/payments/index.html.erb` to a present-tense statement; removed the "later story" parenthetical that referenced this very story.
- Verified `Payment#readonly?` does NOT need modification: the `pending → overdue` transition fires when `status_was == "pending"`, so `readonly?` returns `false` at mutation time. Added targeted model spec as regression guard (Task 2.1 / 6.3).
- Test coverage: 3 new service specs (22 new examples), 2 new model specs, 5 new request specs for loans, 4 new request specs for payments. All 482 `rspec` examples pass. `rubocop` clean on every touched file.
- No new migrations, no new gems, no new routes, no new UI surfaces. No `DoubleEntry` posting. No late-fee logic. No loan closure. Scope held to exactly what Story 5.5 specified.

### File List

- `app/services/payments/mark_overdue.rb` (new)
- `app/services/loans/refresh_status.rb` (new)
- `app/services/payments/derive_overdue_states.rb` (new)
- `app/controllers/loans_controller.rb` (modified — `#show` calls `Loans::RefreshStatus`)
- `app/controllers/payments_controller.rb` (modified — `#show`, `#index`, `#mark_completed` derivation hooks)
- `app/views/payments/index.html.erb` (modified — empty-state copy for `view=overdue`)
- `spec/services/payments/mark_overdue_spec.rb` (new)
- `spec/services/loans/refresh_status_spec.rb` (new)
- `spec/services/payments/derive_overdue_states_spec.rb` (new)
- `spec/models/payment_spec.rb` (modified — pending→overdue regression under `readonly?`)
- `spec/models/loan_spec.rb` (modified — `may_mark_overdue?` / `may_resolve_overdue?` coverage)
- `spec/requests/loans_spec.rb` (modified — overdue derivation freshness block)
- `spec/requests/payments_spec.rb` (modified — overdue freshness + back-flip after `mark_completed`)

## Change Log

- 2026-04-18: Created story for overdue payment and loan state derivation (service-first; inline derivation on read surfaces; back-flip hook after `Loans::RecordRepayment` success).
- 2026-04-18: Implemented `Payments::MarkOverdue`, `Loans::RefreshStatus`, `Payments::DeriveOverdueStates`; wired read-surface freshness hooks; updated `view=overdue` empty-state copy; full `rspec` green (482 examples), `rubocop` clean on touched files.
