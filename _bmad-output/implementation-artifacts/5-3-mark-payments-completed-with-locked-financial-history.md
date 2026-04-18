# Story 5.3: Mark Payments Completed with Locked Financial History

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want to record externally received payments with the right completion details,
So that the system stays the source of truth for repayment progress.

## Acceptance Criteria

1. **Given** a payment has been received outside the system
   **When** the admin marks the payment as completed
   **Then** the system records the completion successfully
   **And** requires the payment date and payment mode as part of the action

2. **Given** the payment completion is a money-sensitive action
   **When** the admin initiates it
   **Then** the UI uses a guarded confirmation pattern with consequence-aware messaging
   **And** the updated state is shown clearly after completion

3. **Given** a payment has been marked completed
   **When** the admin attempts to edit the completed payment record
   **Then** the system blocks the edit
   **And** explains that completed financial records are non-editable

## Tasks / Subtasks

- [x] Task 1: Create `Payments::MarkCompleted` domain service (AC: #1, #2, #3)
  - [x] 1.1 Create `app/services/payments/mark_completed.rb` extending `ApplicationService`
  - [x] 1.2 Follow the canonical `Result = Struct.new(:payment, :error, keyword_init: true)` pattern with `success?` / `blocked?` — mirror `Loans::Disburse` and `Invoices::IssueDisbursementInvoice`
  - [x] 1.3 Accept keyword args: `payment:`, `payment_date:`, `payment_mode:`, `completed_by:` (for audit whodunnit context — reuse `Current.user`), `notes: nil`
  - [x] 1.4 Wrap mutation in `payment.with_lock` (pessimistic row lock) — do NOT use `DoubleEntry.lock_accounts` in this story (no ledger postings here; Story 5.4 adds them)
  - [x] 1.5 Guard: return blocked with "This payment has already been completed." if `payment.completed?` (AASM idempotency — prevents re-completion and defends AC #3)
  - [x] 1.6 Guard: return blocked with "This payment cannot be completed from its current state." unless `payment.may_mark_completed?` (covers any future state beyond pending/overdue)
  - [x] 1.7 Guard: return blocked with "Payment date is required." if `payment_date.blank?`
  - [x] 1.8 Guard: return blocked with "Payment date cannot be in the future." if `payment_date > Date.current`
  - [x] 1.9 Guard: return blocked with "Payment mode is required." if normalized payment_mode blank (strip + downcase via model's existing `normalizes` — pass through as-is; the service validates presence before delegating to AR)
  - [x] 1.10 Guard: return blocked with "<mode> is not a supported payment mode." if normalized payment_mode not in `Payment::PAYMENT_MODES` (see Task 2.1)
  - [x] 1.11 On success: assign `payment.payment_date = payment_date`, `payment.payment_mode = payment_mode`, `payment.notes = notes` (only when `notes.present?` — do NOT overwrite an existing note with nil), `payment.completed_at = Time.current`, then `payment.mark_completed!` (AASM fires the state transition and `save!`)
  - [x] 1.12 Return `Result.new(payment: payment)` on success; do NOT raise `AASM::InvalidTransition` out to the caller — convert it to a blocked result
  - [x] 1.13 Service is pure domain logic: no params parsing, no flash/HTTP concerns, no invoice/ledger work (Story 5.4 wraps this call with those side effects)

- [x] Task 2: Add domain constants and editability enforcement on `Payment` (AC: #1, #3)
  - [x] 2.1 In `app/models/payment.rb`, add `PAYMENT_MODES = %w[cash upi bank_transfer cheque other].freeze` at the top of the class. Rationale: stable vocabulary, matches `normalizes :payment_mode` downcase rule, covers India-first MVP modes (FR49 says "payment mode" with no enum constraint in the PRD — we pin it here to keep storage tidy and surface a select in the UI)
  - [x] 2.2 Add validations that only run on completion-context updates:
    - `validates :payment_date, presence: true, if: :completed?`
    - `validates :payment_mode, presence: true, inclusion: { in: PAYMENT_MODES }, if: :completed?`
    - `validates :completed_at, presence: true, if: :completed?`
    - `validate :payment_date_not_in_future, if: -> { completed? && payment_date.present? }`
  - [x] 2.3 Add `payment_mode_label` helper: `payment_mode.to_s.humanize.presence` (so "bank_transfer" → "Bank transfer" for UI) — call from views instead of ad-hoc `humanize`
  - [x] 2.4 Keep the existing `editable?` method (`pending? || overdue?`) — this is the canonical gate used by the show view to decide whether to render the completion form. Do NOT widen it
  - [x] 2.5 Add a `readonly?` AR callback that returns true when the **persisted** record is already `completed` — this is a belt-and-braces guard that makes `record.update(...)` and `record.save` no-ops at the AR layer so completed financial history cannot be mutated by any accidental caller. Pattern:
    ```ruby
    def readonly?
      return false if new_record?
      status_was == "completed"
    end
    ```
    This defends AC #3 at the model layer even if a future controller forgets the state check. Caveat: the service performs its own `mark_completed!` transition through AASM; at the moment of transition the *previous* persisted status is still `pending`/`overdue`, so the save proceeds. After that, any further `update` against the persisted completed row is refused.

- [x] Task 3: Add `PATCH /payments/:id/mark_completed` route and controller action (AC: #1, #2, #3)
  - [x] 3.1 In `config/routes.rb`, extend the existing payments resource:
    ```ruby
    resources :payments, only: %i[index show], constraints: { id: UUID_REGEX } do
      member do
        patch :mark_completed
      end
    end
    ```
    — keep the existing UUID constraint. (Extract the UUID regex inline as it is today; no new helpers in this story.)
  - [x] 3.2 Add `mark_completed` action to `PaymentsController` following the `LoansController#disburse` thin-controller pattern:
    ```ruby
    def mark_completed
      set_payment
      result = Payments::MarkCompleted.call(
        payment: @payment,
        payment_date: completion_params[:payment_date],
        payment_mode: completion_params[:payment_mode],
        notes: completion_params[:notes],
        completed_by: Current.user
      )
      if result.success?
        redirect_to payment_path(@payment, from: params[:from]),
                    notice: "Payment ##{@payment.installment_number} for #{@payment.loan.loan_number} recorded as completed."
      else
        redirect_to payment_path(@payment, from: params[:from]), alert: result.error
      end
    end
    ```
  - [x] 3.3 Add `before_action :set_payment, only: %i[show mark_completed]` (extend the existing `only: :show`)
  - [x] 3.4 Add a private `completion_params`: `params.require(:payment).permit(:payment_date, :payment_mode, :notes)` — scoped under a `:payment` key, matching the form builder in Task 4
  - [x] 3.5 Do NOT add new authorization primitives — the existing `Authentication` concern on `ApplicationController` guards every route in this controller; Pundit has not yet been introduced to the codebase (matches Story 5.2 note)
  - [x] 3.6 Preserve the `from` breadcrumb parameter through the redirect so the admin returns to the same breadcrumb context (payments list or loan detail)

- [x] Task 4: Guarded completion form on payment show (AC: #1, #2)
  - [x] 4.1 In `app/views/payments/show.html.erb`, replace the existing "Completion is recorded through a guarded flow" callout with a **conditional completion section**:
    - When `@payment.editable?` (pending or overdue): render the guarded completion form card
    - When `@payment.completed?`: render a locked-state summary card (see Task 5)
  - [x] 4.2 Completion form card structure (matches wireframe 12 — `_bmad-output/planning-artifacts/ux-wireframes-pages/12-12-payment-detail-completion.html`):
    - Card heading: "Record completed payment" with a short consequence blurb: "Completing this payment locks the record. The payment date, mode, and notes cannot be edited afterward."
    - `form_with model: @payment, url: mark_completed_payment_path(@payment, from: params[:from]), method: :patch, scope: :payment, local: true` — scope the inputs under `payment[...]` so `completion_params` in the controller receives the right shape
    - Inputs (two-column grid on `sm` and above, stack on mobile):
      - `Payment date` — `date_field :payment_date, required: true, max: Date.current, value: params.dig(:payment, :payment_date) || Date.current`
      - `Payment mode` — `select :payment_mode, Payment::PAYMENT_MODES.map { |m| [m.humanize, m] }, { include_blank: "Select a mode" }, required: true`
      - `Notes` — `text_area :notes, rows: 3` (optional; helper "Optional context that will be stored alongside this completion record")
    - Submit button: `button_to "Mark payment complete", mark_completed_payment_path(@payment, from: params[:from]), method: :patch, form: {...}` OR a `submit_tag "Mark payment complete"` inside the `form_with`. Prefer the `form_with` approach (single form; simpler data binding). Apply Turbo guarded confirmation via `data: { turbo_confirm: "Mark this payment as completed? This will lock the payment date, mode, and notes — these fields cannot be edited afterward." }` on the submit button
    - Cancel link back to payments list or originating loan via the `from` param (no cancel button inside the form is required; the breadcrumb already supports navigation). A secondary "Cancel" link-button following loans disbursement button layout is acceptable but optional
  - [x] 4.3 Place the completion form card **above** the existing details `<dl>` so the action is visible without scrolling — mirrors wireframe 12's top-of-page placement
  - [x] 4.4 For pending/overdue payments, KEEP the existing details grid visible — the admin needs to verify principal/interest/total before confirming (verification-first is the wireframe's explicit intent)
  - [x] 4.5 Accessibility: each input has an associated `<label>`; the form card carries `aria-labelledby` pointing to the heading; the guarded `data-turbo-confirm` message spells out the consequence in plain language (no vague "Are you sure?")

- [x] Task 5: Post-completion locked summary card (AC: #2, #3)
  - [x] 5.1 When `@payment.completed?`, render a summary card in place of the form containing:
    - Heading: "Payment completed"
    - `Shared::StatusBadgeComponent` with `:success` tone
    - A short sentence: "This payment was recorded on <completed_at long date/time>. The payment date, mode, and notes are now locked and cannot be edited."
    - A small `<dl>` grid showing `Payment date`, `Payment mode` (`payment.payment_mode_label`), `Notes` (show "—" if blank), `Completed at`, `Completed by` (see Task 5.2)
  - [x] 5.2 "Completed by" surfaces the PaperTrail whodunnit value recorded on the `:completed` version — look up via `@payment.versions.where(event: "update").last`. Render gracefully as "—" when unavailable (e.g., older records created before this story). Do NOT add a foreign-key column for `completed_by` — the audit is PaperTrail's job. [Source: `config/initializers/paper_trail.rb`, `Payment has_paper_trail`]
  - [x] 5.3 Do NOT render any form elements on completed payments — this enforces AC #3 visually in addition to the controller/service/model guards
  - [x] 5.4 Ensure the detail page's existing rows (Loan, Borrower, Installment, Due date, Principal, Interest, Total, Late fee, Repayment frequency, Current repayment state, Payment date, Payment mode, Completed at, Notes) still render — they now reflect the persisted completed values. Remove the "Not recorded yet" fallbacks from `payment_date` / `payment_mode` lines when the payment is completed (the values are always present); keep them when the payment is still pending/overdue

- [x] Task 6: Payments list — surface the completion affordance inline (AC: #1, #2)
  - [x] 6.1 In `app/views/payments/index.html.erb`, update the per-row action cell (currently "Open") so pending and overdue rows show an explicit "Mark complete" link that navigates to the payment detail page with `from: "payments"`. Do NOT inline a form in the index — the guarded confirmation and verification content live on the detail page (AC #2: "guarded confirmation pattern with consequence-aware messaging")
  - [x] 6.2 Link label per status: pending/overdue → "Mark complete"; completed → "View"
  - [x] 6.3 Use the same ring/link styling as the existing "Open" link (keep visual parity with loans/applications indexes)

- [x] Task 7: Loan detail — keep the row drill link correct after completion (AC: #2)
  - [x] 7.1 In `app/views/loans/show.html.erb` (inside the repayment schedule table row), the "Open payment" link already uses `payment_path(payment, from: "loans")` from Story 5.2 — no behavior change needed. Verify it still points at the same action and that the completion form appears for pending/overdue installments and hides for completed ones (already handled by the view branching in Task 4)
  - [x] 7.2 The "Next payment due", "Completed installments", "Pending installments", "Overdue installments" counts in the loan-show summary already re-derive from the in-memory collection; a successful completion will flip one installment from pending to completed, and a page reload will update the counts naturally. Do NOT add new queries — match the Story 5.2 precedent

- [x] Task 8: Tests (AC: #1, #2, #3)
  - [x] 8.1 `spec/services/payments/mark_completed_spec.rb` (new):
    - success from pending state — transitions AASM to completed, sets `payment_date`, `payment_mode`, `completed_at`, optional `notes`; returns `success?`
    - success from overdue state — covers the `from: %i[pending overdue]` AASM transition branch
    - idempotency — calling twice returns blocked on the second call with "already been completed" message; no second PaperTrail version; `completed_at` does not change
    - blocked when `payment_date` is nil
    - blocked when `payment_date` is in the future (use `Date.current + 1.day`)
    - blocked when `payment_mode` is nil or blank after normalization
    - blocked when `payment_mode` is not in `Payment::PAYMENT_MODES`
    - blocked when an unsupported state is somehow forced (e.g., stub `may_mark_completed?` to return false) — verifies the AASM guard path
    - persists PaperTrail whodunnit: `PaperTrail.request(whodunnit: admin.id) { Payments::MarkCompleted.call(...) }` — assert `payment.versions.last.whodunnit == admin.id`
    - concurrency note: use `payment.with_lock` (already in the service) — no explicit thread test required, but verify the service wraps its mutations in `with_lock` via `expect(payment).to receive(:with_lock).and_call_original`
  - [x] 8.2 `spec/models/payment_spec.rb` (extend existing):
    - `readonly?` returns false for new records
    - `readonly?` returns false for pending/overdue persisted records
    - `readonly?` returns true for completed persisted records; `payment.update(notes: "changed")` returns false and persists no change; `reload`'s notes are unchanged
    - Completion-context validations: `payment.status = "completed"` without `payment_date` / `payment_mode` / `completed_at` is invalid with the expected error messages
    - `payment_mode` inclusion validation rejects "wire" and accepts every `PAYMENT_MODES` value
    - `payment_mode_label` returns humanized label (e.g., "bank_transfer" → "Bank transfer") and nil for a blank value
  - [x] 8.3 `spec/requests/payments_spec.rb` (extend existing):
    - `PATCH /payments/:id/mark_completed` as unauthenticated visitor → redirect to sign-in (mirror existing auth tests)
    - authenticated admin + valid params on a pending payment → redirect to `payment_path(..., from: "payments")` with success flash; payment is completed; Flash notice mentions loan number and installment number
    - authenticated admin + missing `payment_date` → redirect back to the payment show with the service's blocked flash
    - authenticated admin + unsupported `payment_mode` value → redirect back with the mode-specific blocked flash
    - authenticated admin attempting to complete an already-completed payment → redirect back with the "already been completed" alert (idempotency)
    - GET `/payments/:id` renders the completion form for a pending payment (assert presence of "Mark payment complete" button and `data-turbo-confirm` attribute)
    - GET `/payments/:id` renders the locked summary card for a completed payment (assert absence of form inputs; presence of "Payment completed" heading)
    - `from=loans` param round-trip: posting `mark_completed` with `from=loans` redirects to `payment_path(..., from: "loans")`
  - [x] 8.4 `spec/requests/loans_spec.rb` (no new assertions required, but do not regress): confirm the loan show "Open payment" link still resolves and that a subsequent GET to the payment show renders the completion form for a pending installment
  - [x] 8.5 Run `bundle exec rspec` green; run `bundle exec rubocop` green on all touched files before marking the story done

## Review Findings

<!-- Populated by the code-review workflow. -->

## Dev Notes

### Epic 5 Cross-Story Context

- **Epic 5** covers repayment servicing, overdue control, and loan closure (FR40–FR56, FR72).
- **Story 5.1 (done)** created the `Payment` model + `Loans::GenerateRepaymentSchedule` + loan-show schedule section.
- **Story 5.2 (done)** added the payments list/detail read surfaces, the loan-show repayment-state summary, and the `payment_due_hint` helper. It explicitly left completion action/form out of scope.
- **This story (5.3)** adds guarded payment completion: the `Payments::MarkCompleted` domain service, the completion form on the payment detail page, and the locked/readonly enforcement for completed records. **It does NOT** create a payment invoice or post `DoubleEntry` transfers — that is Story 5.4.
- **5.4** will extend `Invoice::INVOICE_TYPES` with `"payment"`, add `Invoices::IssuePaymentInvoice`, and chain it + a `repayment_received → loan_receivable` ledger transfer behind the same `Payments::MarkCompleted` call. This story **must leave a clean extension point** for that chaining (see "Service extension points" below).
- **5.5** will derive overdue state from facts; this story does not touch overdue derivation. However, completing an overdue payment (via the AASM `from: %i[pending overdue]` branch) is in-scope here — 5.5 only decides when a payment *becomes* overdue.
- **5.6** will apply late fees and auto-close loans from completed repayment facts; this story leaves the `late_fee_cents` column untouched (default 0).

### Critical Architecture Constraints

- **Domain services own all money-critical mutations.** Payment completion belongs in `app/services/payments/mark_completed.rb`. The controller must NOT call `payment.mark_completed!` directly, must NOT set `completed_at`, and must NOT persist `payment_date`/`payment_mode` outside the service. [Source: `_bmad-output/planning-artifacts/architecture.md#Domain logic boundaries`]
- **AASM for state transitions.** The `mark_completed` event already exists on `Payment` (`transitions from: %i[pending overdue], to: :completed`). Do NOT redefine the AASM block. [Source: `app/models/payment.rb:35-37`]
- **`with_lock` for transitions.** State-changing services acquire a pessimistic lock. [Source: architecture.md — concurrency patterns; existing services]
- **Service result pattern.** Follow `Result = Struct.new(:payment, :error, keyword_init: true)` with `success?` / `blocked?`. Mirror `Loans::Disburse`, `Loans::UpdateDetails`, `Invoices::IssueDisbursementInvoice`. [Source: `app/services/loans/*`, `app/services/invoices/issue_disbursement_invoice.rb`]
- **`paper_trail` for audit.** `Payment has_paper_trail` is already declared. `PaperTrail.whodunnit` is wired in `ApplicationController`. The service must execute inside the standard request cycle so whodunnit is captured automatically; no explicit `PaperTrail.request` wrapping is required in controllers. [Source: `app/models/payment.rb:5`, prd.md — FR68/FR69]
- **No hard delete.** Payments are never destroyed. Completed payments are additionally immutable via `readonly?`. [Source: prd.md — FR70]
- **Domain vocabulary is canonical.** Payment AASM states are `pending`, `completed`, `overdue`. Views render `payment.status_label` / `payment.status_tone`. Do NOT introduce alternative state strings ("paid", "settled", etc.) in the UI. [Source: architecture.md — "Using different status strings in UI than in domain enums" anti-pattern]
- **Guarded confirmation is the UX primitive for money-sensitive actions.** Payment completion is explicitly called out alongside disbursement as requiring guarded confirmation with a consequence summary. Use `data-turbo-confirm` with a multi-line consequence message, matching the `Loans::Disburse` precedent in `app/views/loans/show.html.erb`. [Source: ux-design-specification.md — "Guarded Confirmation Dialog" lines 587-593; "Mark payment complete" as an explicit action label line 664]
- **Post-money records stay locked.** After completion, the payment is non-editable. This is enforced at three layers: AASM has no transition out of `completed`; the service refuses to re-complete; the model's `readonly?` returns true. AC #3 demands this; the layered defense is deliberate. [Source: architecture.md — "Post-money records must remain locked after commitment" (NFR10 in PRD)]
- **Authentication gating.** All payment routes are admin-protected through the existing `Authentication` concern on `ApplicationController`. Do NOT introduce Pundit in this story — the codebase has not yet introduced a `PaymentPolicy` (Story 5.2 noted the same). [Source: `app/controllers/concerns/authentication.rb`, Story 5.2 Dev Notes]

### Files NOT to Create or Modify

- Do NOT create `app/services/invoices/issue_payment_invoice.rb` — Story 5.4.
- Do NOT extend `Invoice::INVOICE_TYPES` with `"payment"` — Story 5.4.
- Do NOT add a `repayment_received` transfer or new `double_entry` account — Story 5.4. The `DoubleEntry` initializer stays unchanged in this story.
- Do NOT call `DoubleEntry.transfer` or `DoubleEntry.lock_accounts` from `Payments::MarkCompleted` — this story is ledger-free.
- Do NOT implement overdue-state derivation or flip pending → overdue anywhere — Story 5.5.
- Do NOT apply late fees or close loans — Story 5.6.
- Do NOT add a Pundit `PaymentPolicy` — the codebase still uses the shared authentication gate.
- Do NOT change the Payment AASM definitions — the `mark_completed` event is already correct.
- Do NOT add a new migration — all required columns (`payment_date`, `payment_mode`, `completed_at`, `notes`, `late_fee_cents`) already exist from Story 5.1. [Source: `db/schema.rb:174-193`, `db/migrate/20260416215225_create_payments.rb`]
- Do NOT add pagination to the payments index — the Story 5.2 review captured this as deferred work. [Source: `_bmad-output/implementation-artifacts/deferred-work.md`]

### File Structure (Expected Touchpoints)

| Area | Files |
|------|--------|
| New | `app/services/payments/mark_completed.rb` |
| New | `spec/services/payments/mark_completed_spec.rb` |
| Modify | `app/models/payment.rb` — add `PAYMENT_MODES`, completion-context validations, `payment_mode_label`, `readonly?` |
| Modify | `app/controllers/payments_controller.rb` — add `mark_completed` action + `completion_params` + extend `before_action :set_payment` |
| Modify | `app/views/payments/show.html.erb` — replace informational callout with completion form for editable payments and locked summary for completed payments |
| Modify | `app/views/payments/index.html.erb` — per-row action label reflects completion eligibility |
| Modify | `config/routes.rb` — add `patch :mark_completed` member action under payments resource |
| Modify | `spec/models/payment_spec.rb` — coverage for `readonly?`, new validations, `payment_mode_label` |
| Modify | `spec/requests/payments_spec.rb` — coverage for the new `PATCH /payments/:id/mark_completed` action, render branches, auth guard |

### Existing Patterns to Follow

1. **Thin controller action** — identical shape to `LoansController#disburse`:
   ```ruby
   def mark_completed
     set_payment
     result = Payments::MarkCompleted.call(
       payment: @payment,
       payment_date: completion_params[:payment_date],
       payment_mode: completion_params[:payment_mode],
       notes: completion_params[:notes],
       completed_by: Current.user
     )
     if result.success?
       redirect_to payment_path(@payment, from: params[:from]), notice: "..."
     else
       redirect_to payment_path(@payment, from: params[:from]), alert: result.error
     end
   end
   ```

2. **Service `with_lock` pattern** — minimal skeleton for `Payments::MarkCompleted`:
   ```ruby
   module Payments
     class MarkCompleted < ApplicationService
       Result = Struct.new(:payment, :error, keyword_init: true) do
         def success? = error.blank?
         def blocked? = error.present?
       end

       def initialize(payment:, payment_date:, payment_mode:, completed_by:, notes: nil)
         @payment = payment
         @payment_date = parse_date(payment_date)
         @payment_mode = payment_mode.to_s.squish.downcase.presence
         @notes = notes.presence
         @completed_by = completed_by
       end

       def call
         return blocked("This payment has already been completed.") if payment.completed?
         return blocked("Payment date is required.") if @payment_date.blank?
         return blocked("Payment date cannot be in the future.") if @payment_date > Date.current
         return blocked("Payment mode is required.") if @payment_mode.blank?
         return blocked("#{@payment_mode} is not a supported payment mode.") unless Payment::PAYMENT_MODES.include?(@payment_mode)

         payment.with_lock do
           return blocked("This payment cannot be completed from its current state.") unless payment.may_mark_completed?

           payment.payment_date = @payment_date
           payment.payment_mode = @payment_mode
           payment.notes = @notes if @notes
           payment.completed_at = Time.current
           payment.mark_completed!
         end

         Result.new(payment: payment)
       rescue AASM::InvalidTransition => e
         Result.new(payment: payment, error: e.message)
       end

       private
         attr_reader :payment

         def blocked(message) = Result.new(payment: payment, error: message)

         def parse_date(value)
           return value if value.is_a?(Date)
           Date.parse(value.to_s)
         rescue ArgumentError, TypeError
           nil
         end
     end
   end
   ```
   This skeleton is authoritative for result shape, guard order, and lock placement. Implement with no stylistic deviations.

3. **Guarded confirmation via `data-turbo-confirm`** — follow the disbursement pattern in `app/views/loans/show.html.erb`. Use a multi-line confirmation message that names the consequence explicitly ("locks the payment date, mode, and notes — these cannot be edited afterward").

4. **`form_with scope: :payment`** — scoping under `:payment` keeps `completion_params = params.require(:payment).permit(...)` consistent with existing Rails conventions in the codebase (see `LoansController#update`).

5. **`from` query-string breadcrumb pattern** — established by `loans`, `loan_applications`, and extended by `payments` in Story 5.2. Preserve `from` through the `mark_completed` redirect so the admin returns to the same context.

6. **Money display** — amounts on the detail page already use `humanized_money_with_symbol`. Completion does not introduce new money columns or formats.

### UX Requirements

- **Verification-first before commitment.** The wireframe (`_bmad-output/planning-artifacts/ux-wireframes-pages/12-12-payment-detail-completion.html`) places the completion form alongside full verification content — loan number, installment, borrower, principal, interest, total, due date. Do NOT hide the details grid when rendering the form; the admin needs to verify the payment's facts before confirming. The annotation on the wireframe says it plainly: "The page should make it impossible to casually commit a payment without seeing what data is being recorded and what becomes locked." [Source: ux-wireframes-pages/12-12-payment-detail-completion.html:621]
- **Explicit action label.** Button copy is "Mark payment complete" — per UX spec's explicit-action-label rule. NOT "Submit" / "Continue" / "Record". [Source: ux-design-specification.md:664]
- **Consequence-aware confirm dialog.** The `data-turbo-confirm` message must spell out what becomes locked, in plain language. The Loan disbursement pattern is the reference. [Source: ux-design-specification.md:587-593]
- **Unmistakable post-action state.** After completion, render a success-toned locked summary card at the top of the detail page so the admin never doubts whether the completion was recorded correctly. Mirrors the disbursement success UX. [Source: ux-design-specification.md:94-96, lines 144-146]
- **No casual money actions anywhere.** Do NOT add a one-click "Complete" button to the payments list. The index's per-row affordance is a "Mark complete" link that routes to the detail page, where the guarded confirmation and verification content live. [Source: ux-design-specification.md — "Avoid casual treatment of money-related actions" line 202]
- **Blocked-state copy for completed records.** When a completed payment's detail page renders, the locked summary doubles as the blocked-state explanation required by AC #3: "The payment date, mode, and notes are now locked and cannot be edited." Use calm, informative language — this is not an error. [Source: ux-design-specification.md — "Blocked-State Callout" line 602]
- **Accessibility.** Each input has an associated `<label>`; the confirmation dialog message is readable by screen readers (Turbo surfaces the confirm text natively); locked and active states are distinguishable without color alone (badge copy + heading + sentence carry the state).

### Library / Framework Requirements

- **Rails ~> 8.1** — `form_with`, `button_to`, `data-turbo-confirm`, member route block for `patch :mark_completed`
- **AASM ~> 5.5** — `payment.may_mark_completed?` / `payment.mark_completed!`; the `from: %i[pending overdue]` transition already exists
- **money-rails ~> 3.0** — no new monetized columns; reads via existing `humanized_money_with_symbol`
- **paper_trail ~> 17.0** — `has_paper_trail` already on `Payment`; whodunnit captured via the request cycle; the "Completed by" display looks up the latest `versions` row
- **FactoryBot ~> 6.5** — existing `:payment` factory + `:pending`, `:completed`, `:overdue` traits already cover the fixtures needed in specs. You MAY add a `:due_today` trait locally to `spec/factories/payments.rb` if it makes request specs clearer, but it is not required
- **No new gems.** This story must not add a dependency.

### Payment State / Column Matrix

| Current state | `editable?` | `mark_completed` allowed | Render on show |
|---------------|-------------|--------------------------|----------------|
| `pending` | true | yes (AASM: pending → completed) | Completion form + details |
| `overdue` | true | yes (AASM: overdue → completed) | Completion form + details |
| `completed` | false | no (AASM no transition out; service blocks) | Locked summary + details (payment_date/mode/notes now persisted and read-only) |

Columns written by `Payments::MarkCompleted` on success: `status` (via AASM), `payment_date`, `payment_mode`, `completed_at`, optionally `notes`. Columns left untouched: `late_fee_cents` (Story 5.6), `installment_number`, `due_date`, `principal_amount_cents`, `interest_amount_cents`, `total_amount_cents`, `loan_id`.

### Service Extension Points (for Story 5.4)

Story 5.4 will add two side effects to a successful completion: (1) an auto-issued payment invoice via `Invoices::IssuePaymentInvoice`, and (2) a `DoubleEntry.transfer` from `loan_receivable` to a new `repayment_received` account. To keep 5.4 clean, this story should:

- Keep `Payments::MarkCompleted` **single-responsibility** — the method body ends with the AASM transition and a `Result` return. Do NOT sprinkle conditionals or TODO hooks for future invoice/ledger work; 5.4 will wrap or extend the service deliberately.
- Return the `payment` as the primary result entity (`Result.new(payment: ...)`) so 5.4 can reuse the same result object and add an `invoice:` field if it chooses the extension approach.
- Leave `payment.with_lock` as the outermost transaction boundary in this story. 5.4 may replace it with a `DoubleEntry.lock_accounts` block when it wires in the ledger (analogous to `Loans::Disburse`'s restructuring in Story 4.5), but that refactor belongs to 5.4, not this story. [Source: Story 4.5 debug log — the nested-transaction pitfall with `DoubleEntry`]

### Immutability Defense-in-Depth (AC #3)

Three layers enforce that completed payments cannot be edited:

1. **AASM** — no event transitions `completed` out of the terminal state; any attempt raises `AASM::InvalidTransition`.
2. **Service** — `Payments::MarkCompleted` short-circuits with "already been completed" when the payment is already completed; this is the idempotent contract tested in spec.
3. **Model `readonly?`** — completed persisted records refuse AR-level `update` / `save`, so even a bug in a future controller that bypasses the service would fail silently (returns `false`) rather than corrupting committed financial history.

The existing `Payment#editable?` (true for pending/overdue, false for completed) is what the view branches on; keep it as-is.

### Previous Story Intelligence (5.2)

- **Per-row drill link pattern.** Story 5.2's payments index uses `link_to "Open", payment_path(payment, from: "payments")`. Extend this per-row cell with a label that reflects completion eligibility (see Task 6.2). Reuse the same `ring` styling. [Source: `app/views/payments/index.html.erb`]
- **`payment_due_hint` helper.** Already covers "Completed on <date>" and "Completed" branches from Story 5.2. No changes required — the helper output will now be populated with a real `payment_date` for completed rows. Verify view spec rendering after the model changes. [Source: `app/helpers/payments_helper.rb`]
- **`from` breadcrumb param.** The payment show page already reads `params[:from]` to switch the breadcrumb between "Payments" and the originating loan. Pass the same param through the `mark_completed` form action and the post-action redirect so the admin returns to the same context. [Source: `app/views/payments/show.html.erb:3-22`]
- **Loan-show summary counts.** Already derived in memory from the preloaded `payments` collection; a successful completion on the next page load will flip one count automatically without new queries. No changes required. [Source: Story 5.2 Task 5]
- **Test structure.** Story 5.2's request spec covers auth guard + empty/filtered/show branches for payments. Extend the same file; do not create a new file for the member action. [Source: `spec/requests/payments_spec.rb`]
- **`normalizes :payment_mode` already downcases.** The service normalizes input explicitly (`to_s.squish.downcase.presence`) so the blocked guard fires with clear messages before the AR normalizer runs; this is belt-and-braces but matches Story 5.1's input-hygiene approach. [Source: `app/models/payment.rb:13`]

### Git Intelligence

Recent commits (last 5) and their relevance:

- `74ec10b` **Add payment list, detail, and loan repayment-state visibility.** — Directly upstream; installed the payments list/detail surfaces and helpers that this story extends with the completion action.
- `af4a085` Add repayment schedule generation from loan disbursement. — Installed the `Payment` model + factory + AASM states/events including the `mark_completed` event this story fires.
- `59e7827` Complete Epic 4 retrospective. — Planning only; no code impact.
- `af1d56d` Add guarded disbursement financial records and invoice handling. — The authoritative reference pattern for a guarded, service-driven, AASM-transition-committing action. Mirror its controller/service/view shape.
- `d3fb90f` Add disbursement readiness evaluation before disbursement. — Shows the "result object with `blocked?` / `success?`" convention; re-use it.

**Preferred commit style:** `"Add guarded payment completion with locked financial history."`

### Epic 4 Retrospective Insights (Apply to This Story)

1. **"Money-critical work lives in domain services."** `Payments::MarkCompleted` must own the AASM transition, the `completed_at` stamp, and any future invoice/ledger chaining. The controller is a redirect orchestrator. [Source: Epic 4 Retro]
2. **"Guarded confirmation is a first-class UX primitive."** Use `data-turbo-confirm` with a consequence-named message. Do NOT invent a modal component in this story. [Source: Epic 4 Retro; existing `button_to ... data-turbo-confirm` usages]
3. **"Post-money records stay locked."** `readonly?` + completion-context validations together enforce this. Tests must cover the AR-level refusal directly. [Source: Epic 4 Retro — "disbursement-locked loan fields are no longer editable"]
4. **"Test discipline."** Expect `bundle exec rspec` total to grow by ~15–25 examples (service spec + model additions + request spec additions). Keep `bundle exec rubocop` green on touched files. [Source: Epic 4 Retro]
5. **"Facts over toggles."** `payment.completed?` is a fact derived from the AASM state, not a boolean flag; do not add a `completed` boolean column. The existing `completed_at` timestamp is the audit stamp, not the gating fact. [Source: Epic 4 Retro; architecture.md]

### Calculation and Validation Edge Cases to Test

1. **Future payment date.** `payment_date = Date.current + 1.day` → blocked with "Payment date cannot be in the future." (today is allowed.)
2. **Payment date boundary (today).** `payment_date = Date.current` → allowed.
3. **Payment date in the past.** `payment_date = Date.current - 30.days` → allowed (late payments received offline are legitimate). Do NOT reject past dates.
4. **Blank `payment_date` string.** `params[:payment][:payment_date] = ""` → service parses to nil and blocks with "Payment date is required."
5. **Mixed-case `payment_mode`.** `"Cash"` / `"UPI"` / `" cash "` → all normalize to `"cash"` / `"upi"` and are accepted (matches `normalizes :payment_mode` + service normalization).
6. **Unsupported mode.** `"wire_transfer"` → blocked with "wire_transfer is not a supported payment mode."
7. **Idempotent completion.** Calling `Payments::MarkCompleted` twice on the same payment → second call blocks; PaperTrail versions count does not increase; `completed_at` from the first call is preserved.
8. **AASM invalid transition** (defense-in-depth). Directly calling `payment.mark_completed!` on an already-completed payment raises `AASM::InvalidTransition`; the service catches it and returns blocked (should never happen in practice because the `completed?` guard fires first).
9. **Readonly enforcement.** A completed payment's `update(notes: "foo")` returns false and persists no change; `reload.notes` is unchanged. Also: `update!(notes: "foo")` raises `ActiveRecord::ReadOnlyRecord`.
10. **Concurrent completion attempts.** Two simultaneous `Payments::MarkCompleted` calls on the same payment — only one should succeed thanks to `payment.with_lock`; the other re-reads state after the lock releases and blocks with "already been completed." (Not required to write a concurrency integration test; verify via unit-level stub on `with_lock` being called.)
11. **Empty `notes`.** `notes = ""` or `"   "` → stored as nil (matches `normalizes :notes`).
12. **`completed_at` uniqueness across retries.** Not required, but the field is set to `Time.current` once per successful completion; idempotency ensures no overwrite.
13. **Unauthenticated access.** `PATCH /payments/:id/mark_completed` without a session → redirect to sign-in; mirror Story 5.2's auth spec.
14. **`from=loans` round-trip.** Posting with `from=loans` must redirect back to `payment_path(..., from: "loans")` so the breadcrumb continues to show the loan ancestor.

### `double_entry` Notes (for Awareness, Not Action)

- Currently configured accounts: `loan_receivable` (positive-only, loan-scoped), `disbursement_clearing` (loan-scoped).
- Story 5.4 will add `repayment_received` as a new account and define a `:repayment` transfer from `loan_receivable` to `repayment_received`.
- **This story does NOT post, read, or touch `DoubleEntry`.** Payment completion records the repayment fact and the AASM state transition; the accounting posting comes later.

### Project Context Reference

- No `project-context.md` found in repo. This story, the PRD, architecture, UX specification, and Stories 5.1–5.2 are the authoritative sources.

## Dev Agent Record

### Agent Model Used

Opus 4.7 (Cursor)

### Debug Log References

- Initial run of the new model spec revealed that adding `validates :payment_date, presence: true, if: :completed?` + the future-date validation broke the existing lifecycle tests (`mark pending/overdue payments as completed`) because those tests transitioned the AASM state without supplying the completion context. Fixed by supplying `payment_date`, `payment_mode`, and `completed_at` in those tests before calling `mark_completed!` — this also matches the real-world service flow.
- The `:completed` FactoryBot trait previously set `payment_date { loan.disbursement_date + installment_number.months }`, which with `:active` loans (whose `disbursement_date` is `Date.current`) produces a future date. After adding `payment_date_not_in_future`, dozens of existing specs using the trait would fail validation. Fixed by pinning the trait's `payment_date` to `Date.current`.
- Expected `payment.update(notes: "changed")` on a readonly record to return `false`; in practice AR raises `ActiveRecord::ReadOnlyRecord` for both `update` and `update!`. The spec was adjusted to assert the raise.

### Completion Notes List

- Added `Payments::MarkCompleted` domain service following the canonical result/lock/AASM pattern used by `Loans::Disburse`.
- Added `Payment::PAYMENT_MODES`, completion-context validations, `payment_mode_label`, and an AR `readonly?` guard for completed records.
- Wired `PATCH /payments/:id/mark_completed` through the existing `PaymentsController` with strong params scoped under `:payment` and preserving the `from` breadcrumb through the redirect.
- Replaced the informational "guarded flow coming later" callout on `payments/show` with a conditional completion form (pending/overdue) and a locked summary card (completed). The form uses `data-turbo-confirm` with an explicit consequence-named message.
- Payments index now renders "Mark complete" for pending/overdue rows and "View" for completed rows, both pointing at the payment detail page (no casual money actions inline).
- Tests: new `spec/services/payments/mark_completed_spec.rb` (12 examples), extended `spec/models/payment_spec.rb` (readonly?, completion validations, payment_mode_label), and extended `spec/requests/payments_spec.rb` (auth, happy path, blocked paths, idempotency, breadcrumb round-trip, render branches).
- Full suite: `bundle exec rspec` — 419 examples, 0 failures. `bundle exec rubocop` — clean on all touched Ruby files.
- No DoubleEntry / Invoice work in this story — extension points left intact for Story 5.4.

### File List

- `app/models/payment.rb` (modified)
- `app/services/payments/mark_completed.rb` (new)
- `app/controllers/payments_controller.rb` (modified)
- `app/views/payments/show.html.erb` (modified)
- `app/views/payments/index.html.erb` (modified)
- `config/routes.rb` (modified)
- `spec/services/payments/mark_completed_spec.rb` (new)
- `spec/models/payment_spec.rb` (modified)
- `spec/requests/payments_spec.rb` (modified)
- `spec/factories/payments.rb` (modified)

## Change Log

- 2026-04-18: Created story for guarded payment completion and locked financial history.
- 2026-04-18: Implemented guarded payment completion — `Payments::MarkCompleted` service, completion form + locked summary on payment show, index action labels, model `readonly?` + completion-context validations, full test coverage. Status → review.
- 2026-04-18: Code review complete. Applied 7 patches: removed dead `completed_by` param from service/controller; added reload+recheck inside `with_lock` for consistent idempotency message under races; restructured `with_lock` block to avoid non-local return; domain-friendly `AASM::InvalidTransition` rescue message; switched controller to `render :show, status: :unprocessable_content` with `flash.now[:alert]` (preserves user input); added request spec for non-admin denial; added request spec for PaperTrail whodunnit round-trip. Full suite: 422 examples, 0 failures. RuboCop clean. Status → done.

### Review Findings

Code review run on 2026-04-18 against uncommitted changes. Three review layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor). Many Blind Hunter findings were dismissed after verification against actual codebase (e.g., global `require_admin_user!` and `set_paper_trail_whodunnit` in `ApplicationController` refute "authorization absent" and "whodunnit not wired"; `detail_from_loans` is defined at the top of the view).

Decision-needed (all resolved 2026-04-18):

- [x] [Review][Decision] `completed_by` param is accepted by the service but never persisted — `app/services/payments/mark_completed.rb:13-18,44`. Spec Task 1.3 says "for audit whodunnit context — reuse `Current.user`", but `set_paper_trail_whodunnit` is already global, so the only real audit record is PaperTrail's `whodunnit`. Options: (a) remove the `completed_by` param as dead weight, (b) wrap the mutation in `PaperTrail.request(whodunnit: @completed_by&.id&.to_s)` to make the service self-sufficient for non-request callers (jobs/rake), (c) leave as-is with a comment documenting intent.
- [x] [Review][Decision] Idempotency/race message inconsistency under concurrent completion — `app/services/payments/mark_completed.rb:22,29`. Two concurrent admins see different messages depending on which guard catches them ("already been completed" pre-lock vs "cannot be completed from its current state" post-lock). Options: (a) after `with_lock`, `payment.reload` then re-check `payment.completed?` before `may_mark_completed?` to produce the same idempotency message in races (recommended), (b) accept the inconsistency as a spike trade-off, (c) test both messages explicitly.
- [x] [Review][Decision] Validation failure loses user input — `app/controllers/payments_controller.rb:34`. On `result.blocked?`, controller redirects (PRG), losing typed notes/date/mode. Options: (a) switch to `render :show, status: :unprocessable_entity` with `@payment` carrying attempted values and `flash.now[:alert]`, (b) keep the spec-prescribed `redirect_to` pattern (matches `LoansController#disburse`) and accept re-entry UX.

Patch (all applied 2026-04-18):

- [x] [Review][Patch] `return` from inside `payment.with_lock` transaction block is fragile under future refactors [app/services/payments/mark_completed.rb:29] — restructure to avoid non-local return out of a `with_lock`/transaction block.
- [x] [Review][Patch] `rescue AASM::InvalidTransition` surfaces raw AASM library English to the UI [app/services/payments/mark_completed.rb:39-40] — replace `e.message` with the domain-friendly copy "This payment cannot be completed from its current state." to match the guard copy.
- [x] [Review][Patch] Missing test: non-admin is denied on `PATCH /payments/:id/mark_completed` [spec/requests/payments_spec.rb] — add a request spec asserting a signed-in non-admin cannot hit the endpoint, protecting the new route against future regressions in `require_admin_user!` scope.
- [x] [Review][Patch] Missing test: request-level whodunnit verification [spec/requests/payments_spec.rb] — service spec covers whodunnit via `PaperTrail.request(...)`, but no request spec asserts the controller path (with global `set_paper_trail_whodunnit`) ends up with the admin's id on the completion version. Protects the "Completed by" view logic against accidental removal of the global whodunnit hook.

Deferred:

- [x] [Review][Defer] `readonly?` blocks UPDATE but not DELETE — completed payments can still be destroyed [app/models/payment.rb:55-59] — deferred, pre-existing pattern; spec Task 2.5 only required update/save protection. Loan-level `dependent: :restrict_with_exception` blocks cascade from the loan side.
- [x] [Review][Defer] `readonly?` blocks future legitimate after-completion callbacks [app/models/payment.rb:55-59] — deferred; will surface as friction when story 5-5 adds overdue derivation on completion; design decision belongs to 5-5/5-6.
- [x] [Review][Defer] No lower bound on `payment_date` against `loan.disbursement_date` — 1990-01-01 is accepted [app/services/payments/mark_completed.rb:24] — deferred, not in spec scope.
- [x] [Review][Defer] No loan-state guard (closed/undisbursed loans can still have a payment marked completed) [app/services/payments/mark_completed.rb:22] — deferred, spec scope is payment-state only; loan-state invariants belong to 5-5/5-6.
- [x] [Review][Defer] Out-of-order / prepaid installment completion allowed — deferred, not in spec scope; overdue derivation in 5-5 will need to handle it.
- [x] [Review][Defer] No length bound on `notes` — deferred, pre-existing model concern.
