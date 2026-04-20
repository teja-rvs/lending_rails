# EVO-03: Whole-Rupee Installments

## Target

Installment payment amounts should be rounded to whole rupees (multiples of 100 paise). Currently, the schedule splits the total into paise-level amounts, producing fractional rupee values like ₹4,416.66. Borrowers and field agents work in whole rupees — decimal payments create confusion and are impractical to collect in cash.

## Current State

- `GenerateRepaymentSchedule` splits total repayment (principal + interest) evenly using **integer division in paise**
- Each installment can be any paise amount (e.g. 441,666 paise = ₹4,416.66)
- The last installment absorbs the paise-level remainder
- Principal and interest sub-components are allocated proportionally, also at paise granularity

**Example (₹45,000 principal, ₹8,000 interest, 12 months):**
- Regular installments: 441,666 paise (₹4,416.66)
- Last installment: 441,674 paise (₹4,416.74)

## Desired State

- Every installment `total_amount_cents` is a multiple of 100 (whole rupees)
- Rounding uses **banker's rounding** (round half to even) at the rupee boundary
- The last installment absorbs the difference so the schedule total still equals principal + interest exactly
- Principal and interest sub-components continue to be allocated at paise precision (only the total is rounded to whole rupees)

**Example (same loan):**
- Regular installments: 441,700 paise (₹4,417.00)
- Last installment: 441,700 adjusted for remainder (₹4,412.26 — absorbs the overshoot from rounding up 11 installments)
- Sum still equals 5,300,000 paise exactly

## User Journey

1. **Entry point:** Lender disburses an approved loan
2. **Current flow:** `Loans::Disburse` → `GenerateRepaymentSchedule` → Payment rows with fractional-rupee totals → displayed in loan show view
3. **Pain point:** Installment amounts like ₹4,416.66 are awkward for cash collection; field agents round manually, causing reconciliation gaps
4. **Proposed flow:** Same trigger, but `scheduled_installment_totals` rounds each base installment to the nearest 100 paise (₹1) using banker's rounding; last installment absorbs the remainder; all downstream display and ledger entries use whole-rupee totals

## Success Criteria

- All generated installment `total_amount_cents` values are divisible by 100
- Sum of all installment totals equals principal + interest exactly
- Principal sub-component sums equal loan principal exactly
- Interest sub-component sums equal total interest exactly
- No negative installment amounts
- Existing test suite passes with updated expectations

## Scope

- **Files affected:**
  - `app/services/loans/generate_repayment_schedule.rb` — `scheduled_installment_totals` method
  - `spec/services/loans/generate_repayment_schedule_spec.rb` — updated expectations + new rounding-specific tests
- **Components touched:** Repayment schedule generation only; no UI, controller, or model changes
- **Data changes:** None — schema unchanged; values stored in existing `bigint` columns
- **Risk level:** Medium (behavior change in payment calculation, but isolated to schedule generation at disbursement time; no impact on existing disbursed loans)
