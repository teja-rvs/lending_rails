## Deferred from: code review of 1-2-seed-the-admin-account-and-secure-access-rules (2026-03-31)

- Case-insensitive email uniqueness is not enforced at the database layer. `User` normalizes and validates email case-insensitively, but the database still has a plain unique index on `email_address`, so legacy mixed-case rows could behave inconsistently. This appears to predate Story 1.2.
