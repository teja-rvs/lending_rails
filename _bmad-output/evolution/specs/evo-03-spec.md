# Repayment Schedule — Whole-Rupee Installments Specification

**Scenario:** EVO-03 — Whole-Rupee Installments

## Change Summary

Round every installment's `total_amount_cents` to the nearest whole rupee (multiple of 100 paise) using banker's rounding (round half to even). The last installment absorbs the cumulative rounding difference so the schedule total still equals principal + interest exactly. Principal and interest sub-allocations remain at paise precision. No schema, UI, controller, or model changes required.

---

## Before → After

| Aspect | Before | After |
|--------|--------|-------|
| **Installment totals** | Paise-level integer division (e.g. 441,666 paise = ₹4,416.66) | Rounded to nearest 100 paise (e.g. 441,700 paise = ₹4,417.00) |
| **Last installment** | Absorbs paise-level remainder | Absorbs rupee-rounding remainder (may differ from regular installments) |
| **Principal allocation** | Paise-level proportional split | Unchanged — still paise-level |
| **Interest allocation** | `total - principal` per row | Unchanged — still paise-level |
| **Schedule total** | Exactly equals principal + interest | Still exactly equals principal + interest |

**Worked example** (₹45,000 principal, ₹8,000 fixed interest, 12 monthly installments):

| | Before | After |
|---|--------|-------|
| Total to repay | 5,300,000 paise | 5,300,000 paise |
| Base installment | 441,666 paise (₹4,416.66) | 441,700 paise (₹4,417.00) |
| Regular (×11) | 11 × 441,666 = 4,858,326 | 11 × 441,700 = 4,858,700 |
| Last installment | 441,674 paise (₹4,416.74) | 441,300 paise (₹4,413.00) |
| Sum | 5,300,000 ✓ | 5,300,000 ✓ |

**Worked example** (₹45,000 principal, 12.5% rate, 12 monthly installments):

| | Before | After |
|---|--------|-------|
| Total interest | 562,500 paise | 562,500 paise |
| Total to repay | 5,062,500 paise | 5,062,500 paise |
| Base installment | 421,875 paise (₹4,218.75) | 421,900 paise (₹4,219.00) |
| Regular (×11) | 11 × 421,875 = 4,640,625 | 11 × 421,900 = 4,640,900 |
| Last installment | 421,875 paise (₹4,218.75) | 421,600 paise (₹4,216.00) |
| Sum | 5,062,500 ✓ | 5,062,500 ✓ |

---

## Component: `scheduled_installment_totals` (updated)

This is the only method that changes. Currently it performs integer division to get a base amount in paise and assigns the remainder to the last installment.

**New behavior:**

1. Compute `base_amount_cents = total_amount_cents / installment_count` (integer division, as today)
2. **Round to nearest 100** using banker's rounding: `rounded_base = ((base_amount_cents.to_f / 100).round * 100)` — Ruby's `Float#round` uses banker's rounding by default for `.round(0)`
3. Build the array: first `n-1` installments get `rounded_base`
4. Last installment gets `total_amount_cents - (rounded_base * (installment_count - 1))`

**Implementation:**

```ruby
def scheduled_installment_totals(total_amount_cents:, installment_count:)
  base_amount_cents = total_amount_cents / installment_count
  rounded_base_cents = (base_amount_cents / 100.0).round * 100

  Array.new(installment_count) do |index|
    if index + 1 < installment_count
      rounded_base_cents
    else
      total_amount_cents - (rounded_base_cents * (installment_count - 1))
    end
  end
end
```

The `installment_amount` private method is no longer called by this method and can be removed if unused elsewhere.

---

## Edge Cases

| Edge case | Handling |
|-----------|----------|
| **Total divides evenly into whole rupees** | `rounded_base == base`, all installments identical including last. No change from today. |
| **Base rounds down** | Last installment is larger (absorbs positive remainder). Acceptable — difference is at most ₹0.50 × (n-1). |
| **Base rounds up** | Last installment is smaller. Acceptable — same bound. |
| **Very small loan (< ₹100 per installment)** | `rounded_base` could be 0. Caught by existing guard: `installment_totals.any? { \|a\| a <= 0 }`. Schedule generation is blocked. |
| **Last installment goes negative** | Only possible if rounding up overshoots the total. For this to happen, `rounded_base * (n-1) > total`, which requires `rounded_base > total / (n-1)`. With banker's rounding (max +50 paise per installment), the overshoot is at most `50 * (n-1)` paise. For n=52 (weekly), that's ₹25.50. The loan total must be > ₹100 per installment (enforced by positive-installment guard), so the last installment stays positive in all practical cases. Add an explicit guard for safety. |
| **Banker's rounding tie-breaking** | 441,650 → 441,600 (rounds to even); 441,750 → 441,800 (rounds to even). Consistent, no bias. |
| **Already-disbursed loans** | No impact — schedule is only generated at disbursement. Existing payments are untouched. |
| **Bi-weekly / weekly schedules** | Same logic applies. More installments means smaller per-installment rounding impact. |

---

## Files Affected

| File | Change |
|------|--------|
| `app/services/loans/generate_repayment_schedule.rb` | Update `scheduled_installment_totals` to round base installment to nearest 100 paise. Remove or keep `installment_amount` (dead code after change). |
| `spec/services/loans/generate_repayment_schedule_spec.rb` | Update expected values in existing tests. Add new tests for whole-rupee rounding, tie-breaking, and last-installment absorption. |

**Not affected:** No migrations, models, controllers, views, other services, or routes.

---

## Acceptance Criteria

1. Every generated installment `total_amount_cents` is divisible by 100 (whole rupees), except the last installment which absorbs the remainder
2. The last installment `total_amount_cents` preserves the exact total: `sum(all installments) == principal_amount_cents + total_interest_cents`
3. Rounding uses banker's rounding (round half to even) at the rupee boundary
4. Principal sub-component sums equal `loan.principal_amount_cents` exactly
5. Interest sub-component sums equal total interest exactly
6. No installment has a non-positive `total_amount_cents` (existing guard still applies)
7. All existing schedule tests pass with updated expectations
8. New test cases cover: exact division (no rounding needed), round-up case, round-down case, banker's tie-breaking
