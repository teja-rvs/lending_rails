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

## Deferred from: code review of story 5-6-apply-late-fees-and-close-loans-from-completed-repayment-facts (2026-04-19)

- `DeriveOverdueStates` query scope (`Payment.where(status: "pending")`) misses loans with only already-overdue, unassessed payments (late_fee_cents == 0). Per-request `RefreshStatus` hooks cover this gap interactively; batch sweep may leave unassessed fees if no pending-past-due payments remain. Pre-existing Story 5.5 design. [app/services/payments/derive_overdue_states.rb:14]
- `DeriveOverdueStates` bare `rescue => e` swallows all exception types including programming errors (`NoMethodError`, `TypeError`) in the late-fee and closure paths. Isolation is intentional (one loan failure doesn't abort the sweep) but hides regressions in batch sweeps. Pre-existing Story 5.5 pattern. [app/services/payments/derive_overdue_states.rb:30]
- No model-level validation preventing negative `late_fee_cents` on Payment. Only writer is `ApplyLateFee` which always sets the positive constant, so no current path produces a negative value. Consider adding `validates :late_fee_cents, numericality: { greater_than_or_equal_to: 0 }` if external writers emerge. [app/models/payment.rb]

## Deferred from: code review of story 6-1-build-the-action-first-operational-dashboard (2026-04-18)

- Duplicated `self.call(...)` boilerplate across all 5 dashboard query classes. Same pattern exists across all query objects in the project — should be extracted to `ApplicationQuery` base class as a project-wide refactor. [app/queries/dashboard/*.rb]
- System specs use `match: :first` and `visit` hacks to resolve nav link ambiguity after adding the global nav bar. Tests still pass but are slightly weaker in exercising link discoverability. [spec/system/*_spec.rb]
- Nav bar logic defined inline in the application layout (array of tuples, iteration, `current_page?` logic). Should be extracted to a helper or ViewComponent for maintainability as nav grows. [app/views/layouts/application.html.erb:30-48]

## Deferred from: code review of story 6-2-drill-from-dashboard-into-filtered-operational-views (2026-04-18)

- Status pill click in multi-status mode replaces the filter with a single status instead of toggling. UX enhancement — current single-select pill behavior is the standard pattern across all views; toggle would improve drill-in context retention. [app/views/loan_applications/index.html.erb:60, app/views/loans/index.html.erb:71]
- Duplicated `normalized_status_filter` logic across `LoanApplicationsController` and `LoansController`. Nearly identical comma-splitting, downcasing, and allowlist validation. Should be extracted to a shared concern. [app/controllers/loan_applications_controller.rb:93, app/controllers/loans_controller.rb:109]
- Polymorphic return type (String vs Array) from `normalized_status_filter` forces all downstream consumers (views, queries) to branch on `is_a?(Array)`. Returning Array consistently would simplify. [app/controllers/loan_applications_controller.rb:100, app/controllers/loans_controller.rb:117]
- Hardcoded status combinations in dashboard view (`"open,in progress"`, `"active,overdue"`) are magic strings. Should be derived from constants or model methods. [app/views/dashboard/show.html.erb:32,39]
- No upper bound on comma-separated status count in URL params. Low risk given allowlist validation strips invalid entries. [app/controllers/loan_applications_controller.rb:97, app/controllers/loans_controller.rb:114]
- Payments filter-context banner uses a different pattern (chain of if/elsif on view_filter strings) than loans/applications views (dynamic label from filter values). [app/views/payments/index.html.erb:126-146]
- Test specs use inconsistent auth strategies: `post session_path` in loan_applications vs `sign_in_as` in loans/payments. [spec/requests/loan_applications_spec.rb, spec/requests/loans_spec.rb]
- Currency hardcoded to "INR" in dashboard summary widgets. [app/views/dashboard/show.html.erb:56,62]
- No unit test exercising `FilteredListQuery#normalized_status` with Array input directly. Covered by integration tests. [app/queries/loan_applications/filtered_list_query.rb:28, app/queries/loans/filtered_list_query.rb:28]

## Deferred from: code review of story 6-3-search-and-investigate-across-linked-lending-records (2026-04-18)

- No database index on `borrowers.phone_number_normalized` for ILIKE search. Three query objects now ILIKE-match against this column; without a `pg_trgm` index, searches will degrade at scale. Pre-existing schema concern. [app/queries/*/filtered_list_query.rb]
- Tripled raw SQL search predicate across three query objects. Identical `OR borrowers.phone_number_normalized ILIKE :query` in `LoanApplications::FilteredListQuery`, `Loans::FilteredListQuery`, and `Payments::FilteredListQuery`. Pre-existing duplication pattern (the `full_name ILIKE` clause was already duplicated). [app/queries/*/filtered_list_query.rb]
- Test setup duplication: every test creates `create(:user, email_address: "admin@example.com")` independently. Pre-existing pattern across all request specs. [spec/requests/*_spec.rb]
- No special-character test for phone search input (`%`, `_`, `+`). `sanitize_sql_like` is used correctly; general test hardening task. [spec/requests/*_spec.rb]

## Deferred from: code review of story 6-4-record-audit-history-and-protect-operational-records (2026-04-18)

- `DeletionProtection` concern uses `before_destroy` callback which does not guard `Model.delete`, `Model.delete_all`, or `Model.where(...).delete_all`. These bypass ActiveRecord callbacks entirely. FR70 is met at the application layer (destroy), but not at the raw SQL layer. A database-level trigger or revoked DELETE privilege would close this gap project-wide.
- `spec/models/concerns/deletion_protection_spec.rb` is a near-duplicate of the shared example already exercised via `borrower_spec.rb`. Minor test file hygiene — not blocking.
