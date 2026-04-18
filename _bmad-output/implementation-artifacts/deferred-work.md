## Deferred from: code review of 1-2-seed-the-admin-account-and-secure-access-rules (2026-03-31)

- Case-insensitive email uniqueness is not enforced at the database layer. `User` normalizes and validates email case-insensitively, but the database still has a plain unique index on `email_address`, so legacy mixed-case rows could behave inconsistently. This appears to predate Story 1.2.

## Deferred from: code review of 5-2-view-upcoming-and-overdue-repayment-work (2026-04-18)

- Payments index has no pagination and will load the entire result set into memory at render time. Mirrors the pre-existing pattern on `loans` and `loan_applications` indexes; would need a project-wide pagination initiative to address consistently.

## Deferred from: code review of story 5-3-mark-payments-completed-with-locked-financial-history (2026-04-18)

- `Payment#readonly?` blocks UPDATE but not DELETE — completed payments can still be destroyed directly via `Payment.find(id).destroy` (Loan-level `dependent: :restrict_with_exception` blocks cascade from the loan side). Pre-existing pattern; story 5-3 spec only required update/save protection. [app/models/payment.rb:55-59]
- `Payment#readonly?` will block future legitimate after-completion callbacks (e.g., story 5-5 "recompute loan overdue after completion" will raise `ActiveRecord::ReadOnlyRecord`). Design decision belongs to 5-5/5-6. [app/models/payment.rb:55-59]
- No lower bound on `payment_date` against `loan.disbursement_date` — arbitrary historical dates (e.g., 1990-01-01) are accepted on modern loans. Not in story 5-3 spec scope. [app/services/payments/mark_completed.rb:24]
- No loan-state guard — a payment can be marked completed on a loan still in `ready_for_disbursement`, `closed`, or `cancelled`. Story 5-3 spec scope is payment-state only; loan-state invariants belong to 5-5/5-6. [app/services/payments/mark_completed.rb:22]
- Out-of-order installment completion allowed — installment #5 can be marked completed while #1-#4 remain pending. Overdue derivation in 5-5 will need to handle it. [app/services/payments/mark_completed.rb]
- No length bound on `Payment#notes` — arbitrarily large blobs accepted and then locked permanently. Pre-existing model concern. [app/models/payment.rb:16]

## Deferred from: code review of story 5-4-generate-payment-financial-records-and-preserve-the-accounting-boundary (2026-04-18)

- Cross-loan isolation spec for `loan_receivable` / `repayment_received` scopes (Dev Notes Edge Case #7) — intrinsic to `DoubleEntry.account(scope: loan)` and guarded structurally by the `scope_identifier: loan_scope` initializer contract; no current code change threatens the invariant. Add later if a bug in `loan_scope` is ever suspected. [spec/services/loans/record_repayment_spec.rb]

## Deferred from: code review of story 5-5-derive-overdue-payment-and-loan-states (2026-04-18)

- GET requests mutate DB state via inline read-surface derivation. By design per Story 5.5 Dev Notes line 144 ("inline derivation on read is sufficient for MVP"; background job rejected). Revisit when freshness SLA or dashboard story drives scheduled refresh. [app/controllers/loans_controller.rb:12; app/controllers/payments_controller.rb:5,20]
- `Payments::DeriveOverdueStates` runs unbounded on every `/payments` index hit; potential O(stale_loans) lock contention under load. Accepted trade-off per Task 4.5 rationale. [app/services/payments/derive_overdue_states.rb:14-21]
- Race between `Loans::RecordRepayment` commit and concurrent `Loans::RefreshStatus` on the same loan row. Explicitly acknowledged in Story 5.5 Calculation Edge Case #5. Proper fix requires pushing loan row lock into `RecordRepayment` (cross-story; Story 5.4 boundary). [app/services/loans/refresh_status.rb:30; app/services/loans/record_repayment.rb:28]
- Controllers silently ignore `RefreshStatus` blocked results with no log or flash. By design per Task 4.1. Revisit if observability becomes a requirement; pair with logger-warn inside the service rescue for minimum coverage. [app/controllers/loans_controller.rb:12; app/controllers/payments_controller.rb:20,33]
- No authorization check before state-mutating derivation in controllers; any user reaching `#show` triggers PaperTrail versions attributed to them. Pre-existing repo-wide concern (no policy layer present). [app/controllers/payments_controller.rb; app/controllers/loans_controller.rb]
- PaperTrail whodunnit attributes automated derivations to the request user rather than a system actor. A `PaperTrail.request(whodunnit: "system:overdue_derivation") { ... }` wrapper would be a targeted mitigation but introduces a project-wide pattern.
- Time-zone mismatch between `Date.current` (Time.zone) and stored `due_date`. Application-wide TZ concern outside story scope. [app/services/payments/mark_overdue.rb:41; app/services/loans/refresh_status.rb:32]
- Potential InnoDB deadlock between `Loans::RefreshStatus` (loan → payment lock order) and `Payments::MarkCompleted` (payment-only lock from `Loans::RecordRepayment`). Database will detect and roll back one side; fix requires unifying lock ordering across Stories 5.3/5.4/5.5. [app/services/loans/refresh_status.rb:30; app/services/payments/mark_completed.rb]
