## Deferred from: code review of 1-2-seed-the-admin-account-and-secure-access-rules (2026-03-31)

- Case-insensitive email uniqueness is not enforced at the database layer. `User` normalizes and validates email case-insensitively, but the database still has a plain unique index on `email_address`, so legacy mixed-case rows could behave inconsistently. This appears to predate Story 1.2.

## Deferred from: code review of 5-2-view-upcoming-and-overdue-repayment-work (2026-04-18)

- Payments index has no pagination and will load the entire result set into memory at render time. Mirrors the pre-existing pattern on `loans` and `loan_applications` indexes; would need a project-wide pagination initiative to address consistently.
