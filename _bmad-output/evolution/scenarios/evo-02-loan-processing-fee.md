# EVO-02: Loan Processing Fee

## Target

Implement the "charges" concept from FR32 and the PRD's reconciliation chain (approved amount → charges → net disbursement → repayment schedule) as a processing fee field on loans. The PRD references "charges" and "net disbursement" in Business Success criteria, Measurable Outcomes, FR32, and Reliability NFRs, but the current implementation has no charges field — disbursement transfers and invoices use the full principal amount.

## Current State

**What users experience today:**

1. The loan has `principal_amount` as the only pre-disbursement money field (besides interest). There is no way to record charges or a processing fee.
2. At disbursement, the full `principal_amount` is transferred via DoubleEntry from `disbursement_clearing` to `loan_receivable` and recorded on the disbursement invoice.
3. The loan summary shows principal, tenure, frequency, interest details, and notes — no charges or net disbursement.
4. The disbursement section shows the disbursed amount as the full principal.
5. The PRD's reconciliation requirement — "zero reconciliation mismatches between approved amount, charges, net disbursement, and generated repayment schedule" — cannot be validated because charges and net disbursement do not exist in the system.
6. FR32 explicitly lists "charges" as a pre-disbursement detail that the admin should be able to prepare and finalize.

## Desired State

**What users should experience after:**

### 1. Processing fee field on the loan

A mandatory `processing_fee` money field on the loan, defaulting to zero. The operator sets this during pre-disbursement loan setup alongside principal, tenure, frequency, and interest details. It appears in the "Pre-disbursement loan details" form as a currency input field.

The field is:
- **Mandatory** — always present, defaults to `0` when not explicitly set
- **Non-negative** — must be ≥ 0
- **Bounded** — must be < principal amount (cannot equal or exceed it, since net disbursement must be positive)
- **Editable** only in pre-disbursement states (created, documentation_in_progress, ready_for_disbursement)
- **Locked** after disbursement, same as all other pre-disbursement details

### 2. Net disbursement amount

A derived value: **net disbursement = principal − processing fee**

This is not stored as a separate column — it is computed from the two stored fields. It is displayed:
- In the **loan summary** section (alongside principal, processing fee, tenure, frequency, interest)
- In the **disbursement section** (both pre-disbursement readiness and post-disbursement confirmation)
- On the **disbursement invoice** (the invoice `amount_cents` records the net disbursement, since this is what the borrower actually receives)

### 3. Disbursement invoice records net disbursement

The disbursement invoice `amount_cents` changes from `principal_amount_cents` to `principal_amount_cents - processing_fee_cents`. This reflects the actual amount disbursed to the borrower.

### 4. DoubleEntry accounting

The DoubleEntry transfer at disbursement changes from transferring `principal_amount_cents` to transferring `net_disbursement_cents` (principal − processing fee) from `disbursement_clearing` to `loan_receivable`.

The receivable account balance reflects what was actually disbursed. The repayment schedule still totals `principal + interest` — the difference between receivable balance and total scheduled repayment represents the processing fee revenue plus interest income.

### 5. Repayment schedule unchanged

The repayment schedule generation remains based on `principal_amount_cents + total_interest_cents`. The borrower repays the full principal plus interest regardless of the processing fee. The processing fee is a deduction from what the borrower receives at disbursement, not a reduction in what they owe.

### 6. Disbursement readiness

The existing financial details readiness check expands to include `processing_fee`:
- Processing fee must be present (it defaults to 0, so this is always met unless somehow nil)
- Processing fee must be ≥ 0
- Processing fee must be < principal amount

### 7. Loan summary display

The "Current loan summary" section adds:
- **Processing fee** — the fee amount (shows "0.00" when zero)
- **Net disbursement amount** — principal minus processing fee

Post-disbursement, the disbursement confirmation section also shows both values.

## User Journey

### Entry point

Operator navigates to a loan detail page from loans list, dashboard drill-in, or borrower profile.

### Proposed flow (step-by-step)

1. **Loan created from approved application** — Loan is created with `processing_fee_cents` defaulting to `0`. All existing behavior unchanged.

2. **Operator edits pre-disbursement details** — The loan details form now includes a "Processing fee" currency input field (between principal and tenure, or in a logical financial grouping). The field shows `0.00` by default. Operator enters the agreed processing fee for this loan.

3. **Loan summary updates** — The summary section shows principal, processing fee, net disbursement amount, tenure, frequency, interest mode, interest details, and notes. Net disbursement is computed as principal − processing fee.

4. **Validation on save** — If the operator enters a processing fee ≥ principal, validation fails with a clear message: "Processing fee must be less than the principal amount." If negative, validation fails: "Processing fee must be greater than or equal to 0."

5. **Documentation stage** — No change. Processing fee is visible and editable throughout pre-disbursement stages.

6. **Disbursement readiness** — The financial details checklist now includes the processing fee validity check. Since processing fee defaults to 0 and 0 < any positive principal, this check passes by default for loans without an explicit fee.

7. **Disbursement confirmation** — The confirmation dialog shows the net disbursement amount (principal − processing fee) so the operator knows exactly how much will be disbursed.

8. **Disbursement executes** — The system:
   - Sets disbursement date
   - Transitions loan to active
   - Issues disbursement invoice for the **net disbursement amount** (not full principal)
   - Posts DoubleEntry transfer for the **net disbursement amount**
   - Generates repayment schedule from **principal + interest** (unchanged)
   - Locks all pre-disbursement details including processing fee

9. **Post-disbursement view** — The disbursement section shows:
   - Principal amount
   - Processing fee
   - Net disbursement amount (what was actually disbursed)
   - Disbursement date
   - Invoice number and amount (= net disbursement)

### Zero-fee path

When the processing fee is 0 (the default), net disbursement = principal. The disbursement invoice and DoubleEntry transfer use the full principal. This is identical to today's behavior — no regression for existing loans.

## Success Criteria

1. Loan has a mandatory `processing_fee` money field, defaulting to 0
2. Processing fee is editable in pre-disbursement states and locked after disbursement
3. Processing fee validation: ≥ 0 and < principal amount
4. Net disbursement amount (principal − processing fee) is displayed in loan summary, disbursement section, and disbursement confirmation
5. Disbursement invoice `amount_cents` = principal − processing fee (net disbursement)
6. DoubleEntry transfer amount = net disbursement
7. Repayment schedule is unchanged — still generated from principal + interest
8. Disbursement readiness checklist includes processing fee validity
9. Existing loans without a processing fee default to 0 and behave identically to today
10. The PRD reconciliation chain (principal → charges → net disbursement → repayment schedule) is verifiable in the system
11. All existing tests pass (with updates for changed disbursement invoice amount and DoubleEntry transfer amount)

## Scope

### Pages affected

- `app/views/loans/show.html.erb` — add processing fee to details form, add processing fee and net disbursement to loan summary, update disbursement section to show net amount

### Model changes

- **`Loan`** — add `processing_fee_cents` (bigint, NOT NULL, default 0); `monetize :processing_fee_cents`; add validation (≥ 0, < principal) on `:details_update` context; add `processing_fee_display`, `net_disbursement_amount`, `net_disbursement_amount_cents`, `net_disbursement_display` helper methods
- **Migration** — add `processing_fee_cents` to `loans` with NOT NULL default 0 (safe for existing data)

### Service changes

- **`Loans::UpdateDetails`** — no logic change needed; `processing_fee` is permitted via `loan_params` and saved through `assign_attributes` + `save(context: :details_update)` like other fields
- **`Loans::EvaluateDisbursementReadiness`** — add `processing_fee` to `FINANCIAL_DETAIL_ATTRIBUTES` list so it participates in the financial details completeness check
- **`Loans::Disburse`** — change DoubleEntry transfer amount from `principal_amount_cents` to `net_disbursement_amount_cents`
- **`Invoices::IssueDisbursementInvoice`** — change `amount_cents` from `loan.principal_amount_cents` to `loan.net_disbursement_amount_cents`
- **`Loans::GenerateRepaymentSchedule`** — no change (still uses principal + interest)

### Controller changes

- **`LoansController`** — add `:processing_fee` to `loan_params` permit list

### Route changes

- None

### Risk level

**Medium** — Changes the DoubleEntry transfer amount and disbursement invoice amount. The accounting boundary is affected, but the change is well-scoped: only the disbursement transfer and invoice change, not the repayment side. Existing loans with no processing fee default to 0, preserving current behavior exactly.
