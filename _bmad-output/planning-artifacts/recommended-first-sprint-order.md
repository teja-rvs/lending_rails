---
sourceDocument: /Users/rajanavenkatasuryateja/nearform/spike/lending_rails/_bmad-output/planning-artifacts/epics.md
basedOnStoryCount: 30
focus: first-sprint ordering
---

# Recommended First Sprint Order - lending_rails

## Sprint 1 Goal

Deliver a working internal product slice where the admin can:

- sign in
- access the dashboard shell
- create and search borrowers
- start an application safely
- enter application details
- see the fixed review workflow initialized

## Recommended Sprint 1 Story Order

1. **Story 1.1: Initialize the Rails Operational Foundation**
   Establish the approved Rails, PostgreSQL, Tailwind, testing, authentication, authorization, UI, and money-safe implementation baseline.

2. **Story 1.2: Seed the Admin Account and Secure Access Rules**
   Introduce the seeded admin account, protected routes, and secure session boundary.

3. **Story 1.3: Admin Login with Clear Feedback**
   Deliver the first user-facing authentication flow with recoverable feedback.

4. **Story 1.4: Authenticated Dashboard Entry and Logout**
   Create the protected workspace shell and primary post-login landing page.

5. **Story 2.1: Establish Borrower Identity and Searchable Records**
   Define borrower identity, normalized phone-based lookup, and duplicate-prevention rules.

6. **Story 2.2: Create Borrower Intake Flow**
   Deliver borrower creation as the first lending-domain write flow.

7. **Story 2.3: Search and Browse Borrowers**
   Provide borrower search and operational list behavior to support daily use.

8. **Story 2.5: Start a Borrower-Linked Application with Eligibility Guardrails**
   Allow safe application entry while blocking conflicting active lending work.

9. **Story 3.1: Capture and Maintain Application Loan Details**
   Make the application real by capturing editable pre-decision loan details.

10. **Story 3.2: Generate the Fixed Review Workflow**
    Initialize the fixed MVP review-step flow and expose visible application state.

## Why This Order

- It establishes a coherent vertical slice rather than isolated technical tasks.
- It keeps Sprint 1 entirely pre-money, which reduces risk.
- It proves the app shell, secure access boundary, borrower identity, application entry, and workflow skeleton before disbursement or repayment logic.
- It creates a usable internal operational workspace without forcing irreversible financial behavior too early.

## Deliberately Deferred From Sprint 1

- `Story 2.4`: View Borrower Details and Lending History
- `Story 3.3`: Progress Review Steps in Sequence
- `Story 3.4`: Review Borrower History During Decisioning
- `Story 3.5`: Approve, Reject, and Cancel Applications with Preserved History
- All of `Epic 4`
- All of `Epic 5`
- Most of `Epic 6`

## Optional Sprint 1 Stretch Stories

- `Story 3.3`: Progress Review Steps in Sequence
- `Story 3.5`: Approve, Reject, and Cancel Applications with Preserved History

Do not pull disbursement or repayment stories into Sprint 1 as stretch work.

## Recommended Sprint 2 Direction

- `Story 3.3`: Progress Review Steps in Sequence
- `Story 3.4`: Review Borrower History During Decisioning
- `Story 3.5`: Approve, Reject, and Cancel Applications with Preserved History
- `Story 4.1`: Create a Loan from an Approved Application
- `Story 4.2`: Prepare and Review Loan Details Before Disbursement
- `Story 4.3`: Complete Loan Documentation and Manage Supporting Documents

## Planning Notes

- Treat `Epic 4` and `Epic 5` as money-critical implementation phases that should begin only after the pre-money workflow is stable.
- If schedule pressure emerges, compress richer visibility and history work before compressing money-path correctness.
- Use this document as the recommended sprint sequencing companion to the canonical `epics.md` backlog.
