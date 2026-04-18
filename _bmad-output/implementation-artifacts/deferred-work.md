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
