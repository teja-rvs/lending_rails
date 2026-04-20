# Loan Detail Page — Processing Fee Specification

**Scenario:** EVO-02 — Loan Processing Fee

## Change Summary

Add a mandatory processing fee (charges) field to loans, fulfilling FR32 and the PRD's reconciliation chain. The processing fee defaults to zero, is editable only before disbursement, and is deducted from the principal at disbursement to produce the net disbursement amount. The disbursement invoice and DoubleEntry transfer record the net disbursement (principal − processing fee). The repayment schedule remains based on full principal + interest. The loan detail page displays the processing fee, net disbursement amount, and the complete reconciliation breakdown.

---

## Before → After: Page Section Map

| Section | Before | After |
|---------|--------|-------|
| **Pre-disbursement loan details form** | Fields: principal, tenure, frequency, interest mode, interest rate/amount, notes | Add **processing fee** field after principal amount |
| **Current loan summary** | Shows: principal, tenure, frequency, interest mode, interest details, notes | Add **processing fee** and **net disbursement amount** rows |
| **Disbursement section (pre)** | Confirm button; turbo_confirm dialog shows loan number only | Confirm dialog includes **net disbursement amount**. Section shows pre-disbursement financial summary with net amount. |
| **Disbursement section (post)** | Shows: disbursement date, invoice number, disbursed amount, status | Add **principal amount**, **processing fee** rows. "Disbursed amount" label now shows the net disbursement. |
| **Disbursement readiness** | Financial details checklist: principal, tenure, frequency, interest | Add processing fee to financial details validation |
| **Repayment schedule** | No change | No change |
| **Activity timeline** | No change | No change |

---

## Component Specifications

### C1: Processing Fee Form Field (new)

Added to the "Pre-disbursement loan details" form, positioned immediately after the principal amount field (same grid row on desktop, taking the second column).

```
┌─────────────────────────────────┬─────────────────────────────────┐
│ Principal amount                │ Processing fee                  │
│ [100000.00              ]       │ [2000.00                ]       │
├─────────────────────────────────┼─────────────────────────────────┤
│ Tenure (months)                 │ Repayment frequency             │
│ [12                     ]       │ [Monthly               ▾]      │
├─────────────────────────────────┼─────────────────────────────────┤
│ Interest mode                   │ Interest rate / amount          │
│ [Interest rate          ▾]      │ [12.0000                ]       │
├─────────────────────────────────┴─────────────────────────────────┤
│ Notes                                                             │
│ [                                                        ]        │
└───────────────────────────────────────────────────────────────────┘
```

**Field specification:**

| Property | Value |
|----------|-------|
| Label | "Processing fee" |
| Input type | `number_field` |
| `min` | `0` |
| `step` | `"0.01"` |
| Default value | `"0.00"` (from `processing_fee_cents` default 0) |
| Required | Yes (when editable) |
| Disabled | When `!editable` (post-disbursement) |
| CSS class | Same as principal amount field |

### C2: Loan Summary — Processing Fee and Net Disbursement (new rows)

Two new `<div>` items added to the "Current loan summary" `<dl>` grid, inserted after "Principal amount":

```
┌─────────────────────────────────┬─────────────────────────────────┐
│ Principal amount                │ Processing fee                  │
│ 100,000.00                      │ 2,000.00                        │
├─────────────────────────────────┼─────────────────────────────────┤
│ Net disbursement amount         │ Tenure                          │
│ 98,000.00                       │ 12 months                       │
├─────────────────────────────────┼─────────────────────────────────┤
│ Repayment frequency             │ Interest mode                   │
│ Monthly                         │ Interest rate                   │
├─────────────────────────────────┼─────────────────────────────────┤
│ Interest details                │                                 │
│ 12.0000%                        │                                 │
├─────────────────────────────────┴─────────────────────────────────┤
│ Notes                                                             │
│ —                                                                 │
└───────────────────────────────────────────────────────────────────┘
```

**Display rules:**

| Field | Display value |
|-------|---------------|
| Processing fee | `format("%.2f", processing_fee.to_d)` — always shows a number, "0.00" when zero |
| Net disbursement amount | `format("%.2f", net_disbursement_amount.to_d)` — computed as principal − processing fee. Shows "Not provided yet" only if principal is blank. |

### C3: Disbursement Section — Pre-Disbursement (updated)

When the loan is `ready_for_disbursement` and readiness is confirmed, add a financial summary before the confirm button:

```
┌───────────────────────────────────────────────────────────────────┐
│ Disbursement                                                      │
│ Disbursement records the release of funds...                      │
│                                                                   │
│ ┌─────────────────────────────────────────────────────────────┐   │
│ │ Principal amount              100,000.00                    │   │
│ │ Processing fee                  2,000.00                    │   │
│ │ Net disbursement amount        98,000.00                    │   │
│ └─────────────────────────────────────────────────────────────┘   │
│                                                                   │
│                                        [Confirm disbursement]     │
└───────────────────────────────────────────────────────────────────┘
```

This summary panel uses the existing `rounded-2xl border border-slate-200 bg-slate-50 p-6` style with a `<dl>` grid.

**Turbo confirm dialog updated:**

Before:
> "You are about to disburse LOAN-0001. This action records the disbursement date, creates the disbursement invoice, posts accounting entries, and locks the loan for active servicing. Loan details will no longer be editable after disbursement. This action cannot be undone."

After:
> "You are about to disburse LOAN-0001.\n\nNet disbursement amount: ₹98,000.00\n(Principal ₹100,000.00 minus processing fee ₹2,000.00)\n\nThis action records the disbursement date, creates the disbursement invoice, posts accounting entries, and locks the loan for active servicing.\n\nLoan details will no longer be editable after disbursement.\n\nThis action cannot be undone."

When processing fee is zero, the line simplifies to:
> "Net disbursement amount: ₹100,000.00\n(No processing fee)"

### C4: Disbursement Section — Post-Disbursement (updated)

The existing emerald confirmation grid adds principal and processing fee rows:

```
┌───────────────────────────────────────────────────────────────────┐
│ Disbursement                                                      │
│ This loan has been disbursed...                                   │
│                                                                   │
│ ┌─────────────────────────────┬─────────────────────────────────┐ │
│ │ Disbursement date           │ Invoice number                  │ │
│ │ April 20, 2026              │ INV-0001                        │ │
│ ├─────────────────────────────┼─────────────────────────────────┤ │
│ │ Principal amount            │ Processing fee                  │ │
│ │ ₹100,000.00                 │ ₹2,000.00                       │ │
│ ├─────────────────────────────┼─────────────────────────────────┤ │
│ │ Disbursed amount (net)      │ Status                          │ │
│ │ ₹98,000.00                  │ ✓ Disbursed — loan is now active│ │
│ └─────────────────────────────┴─────────────────────────────────┘ │
│                                                                   │
│ 🔒 Locked — pre-disbursement details are no longer editable       │
└───────────────────────────────────────────────────────────────────┘
```

The "Disbursed amount" label changes to **"Disbursed amount (net)"** to clarify this is principal minus fee. The value still comes from `disbursement_invoice.amount` (which will now be net).

The new "Principal amount" and "Processing fee" rows use the same `text-sm font-medium text-emerald-800` dt / `text-lg font-semibold text-slate-950` dd pattern as the existing rows. Values use `humanized_money_with_symbol`.

---

## Data Model Changes

### Loan — add `processing_fee_cents` column

```ruby
# Migration
class AddProcessingFeeToLoans < ActiveRecord::Migration[8.0]
  def change
    add_column :loans, :processing_fee_cents, :bigint, null: false, default: 0
  end
end
```

This is a safe migration for existing data — every existing loan gets `processing_fee_cents = 0`, which means net disbursement = principal (no behavioral change).

### Loan model updates

```ruby
# Monetize
monetize :processing_fee_cents

# Validations (on :details_update context, alongside existing validations)
validates :processing_fee, presence: true, numericality: {
  greater_than_or_equal_to: 0
}, on: :details_update
validate :processing_fee_less_than_principal, on: :details_update

# Helper methods
def processing_fee_display
  format("%.2f", processing_fee.to_d)
end

def net_disbursement_amount_cents
  (principal_amount_cents || 0) - (processing_fee_cents || 0)
end

def net_disbursement_amount
  Money.new(net_disbursement_amount_cents, "INR")
end

def net_disbursement_display
  return "Not provided yet" if principal_amount.blank?

  format("%.2f", net_disbursement_amount.to_d)
end

private

def processing_fee_less_than_principal
  return if processing_fee.blank? || principal_amount.blank?

  if processing_fee_cents >= principal_amount_cents
    errors.add(:processing_fee, "must be less than the principal amount")
  end
end
```

The `processing_fee_cents` column has a DB-level NOT NULL default of 0, so `monetize` will always have a value. The `presence: true` validation ensures the form cannot submit a blank.

---

## Service Changes

### `Loans::EvaluateDisbursementReadiness`

Add `processing_fee` to the `FINANCIAL_DETAIL_ATTRIBUTES` constant:

```ruby
FINANCIAL_DETAIL_ATTRIBUTES = %i[
  principal_amount
  processing_fee
  tenure_in_months
  repayment_frequency
  interest_mode
  interest_rate
  total_interest_amount
].freeze
```

The existing `financial_detail_errors` method runs `loan.valid?(:details_update)` and checks for errors on each attribute. The new `processing_fee` validations (presence, ≥ 0, < principal) will be picked up automatically through this mechanism.

Update the `financial_details_item` detail text to mention processing fee:

```ruby
detail: "Principal, processing fee, tenure, repayment frequency, and interest details satisfy the pre-disbursement validation rules."
```

### `Loans::Disburse`

Change the DoubleEntry transfer amount from `principal_amount_cents` to `net_disbursement_amount_cents`:

Before:
```ruby
DoubleEntry.transfer(
  Money.new(loan.principal_amount_cents, "INR"),
  from: clearing,
  to: receivable,
  code: :disbursement,
  metadata: { loan_id: loan.id, invoice_id: invoice.id, disbursed_by: disbursed_by.id }
)
```

After:
```ruby
DoubleEntry.transfer(
  Money.new(loan.net_disbursement_amount_cents, "INR"),
  from: clearing,
  to: receivable,
  code: :disbursement,
  metadata: { loan_id: loan.id, invoice_id: invoice.id, disbursed_by: disbursed_by.id }
)
```

Add a guard before transfer:

```ruby
return blocked("Net disbursement amount must be positive.") if loan.net_disbursement_amount_cents <= 0
```

### `Invoices::IssueDisbursementInvoice`

Change the invoice amount from `principal_amount_cents` to `net_disbursement_amount_cents`:

Before:
```ruby
def create_invoice!
  Invoice.create_with_next_invoice_number!(
    loan:,
    invoice_type: "disbursement",
    amount_cents: loan.principal_amount_cents,
    currency: "INR",
    issued_on: loan.disbursement_date || Date.current,
    notes: "Disbursement invoice for #{loan.loan_number}"
  )
end
```

After:
```ruby
def create_invoice!
  Invoice.create_with_next_invoice_number!(
    loan:,
    invoice_type: "disbursement",
    amount_cents: loan.net_disbursement_amount_cents,
    currency: "INR",
    issued_on: loan.disbursement_date || Date.current,
    notes: "Disbursement invoice for #{loan.loan_number}"
  )
end
```

Add a guard:

```ruby
return blocked("Net disbursement amount must be positive.") if loan.net_disbursement_amount_cents <= 0
```

### `Loans::UpdateDetails` — no logic change

The `processing_fee` attribute flows through `assign_attributes` → `save(context: :details_update)` like all other permitted fields. No special normalization needed (unlike `interest_mode` which clears the alternate field).

### `Loans::GenerateRepaymentSchedule` — no change

Still uses `principal_amount_cents + total_interest_cents` for the repayment total. The borrower repays the full principal regardless of processing fee.

---

## Controller Changes

### `LoansController`

Add `:processing_fee` to the `loan_params` permit list:

```ruby
def loan_params
  params.require(:loan).permit(
    :principal_amount,
    :processing_fee,
    :tenure_in_months,
    :repayment_frequency,
    :interest_mode,
    :interest_rate,
    :total_interest_amount,
    :notes
  )
end
```

No other controller changes needed.

---

## Route Changes

None.

---

## View Changes — Detailed

### `loans/show.html.erb`

#### 1. Pre-disbursement loan details form

Insert processing fee field after the principal amount `<div>`, sharing the same `lg:grid-cols-2` row:

```erb
<div class="space-y-2">
  <%= form.label :processing_fee, "Processing fee", class: "block text-sm font-medium text-slate-700" %>
  <%= form.number_field :processing_fee,
      required: editable,
      disabled: !editable,
      min: 0,
      step: "0.01",
      value: format("%.2f", @loan.processing_fee.to_d),
      class: "block w-full rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm text-slate-900 shadow-sm transition focus:border-slate-400 focus:outline-none focus:ring-2 focus:ring-slate-950/10 disabled:cursor-not-allowed disabled:bg-slate-100" %>
</div>
```

#### 2. Current loan summary section

Insert two new `<div>` items after "Principal amount":

```erb
<div>
  <dt class="text-sm font-medium text-slate-500">Processing fee</dt>
  <dd class="mt-2 text-lg font-semibold text-slate-950"><%= @loan.processing_fee_display %></dd>
</div>

<div>
  <dt class="text-sm font-medium text-slate-500">Net disbursement amount</dt>
  <dd class="mt-2 text-lg font-semibold text-slate-950"><%= @loan.net_disbursement_display %></dd>
</div>
```

#### 3. Disbursement section — pre-disbursement (ready_for_disbursement, readiness_ready)

Add a financial summary `<dl>` above the confirm button:

```erb
<dl class="mt-8 grid gap-5 rounded-2xl border border-slate-200 bg-slate-50 p-6 sm:grid-cols-3">
  <div>
    <dt class="text-sm font-medium text-slate-500">Principal amount</dt>
    <dd class="mt-2 text-lg font-semibold text-slate-950"><%= humanized_money_with_symbol(@loan.principal_amount) %></dd>
  </div>
  <div>
    <dt class="text-sm font-medium text-slate-500">Processing fee</dt>
    <dd class="mt-2 text-lg font-semibold text-slate-950"><%= humanized_money_with_symbol(@loan.processing_fee) %></dd>
  </div>
  <div>
    <dt class="text-sm font-medium text-slate-500">Net disbursement amount</dt>
    <dd class="mt-2 text-lg font-semibold text-slate-950"><%= humanized_money_with_symbol(@loan.net_disbursement_amount) %></dd>
  </div>
</dl>
```

Update the turbo_confirm text to include net disbursement breakdown.

#### 4. Disbursement section — post-disbursement

Insert "Principal amount" and "Processing fee" rows into the emerald `<dl>` grid, before the existing "Disbursed amount" row. Update the "Disbursed amount" label to "Disbursed amount (net)".

---

## Responsive Behavior

All new elements follow existing patterns:
- **Form field:** Same `lg:grid-cols-2` grid — processing fee sits beside principal on desktop, stacks below on mobile
- **Summary rows:** Same `sm:grid-cols-2` grid — processing fee and net disbursement sit side-by-side on desktop, stack on mobile
- **Pre-disbursement financial summary:** Uses `sm:grid-cols-3` for the three values; stacks vertically on mobile
- **Post-disbursement grid:** Existing `sm:grid-cols-2` pattern; the two new rows follow the same layout

---

## Edge Cases

| Edge case | Handling |
|-----------|----------|
| **Processing fee is zero (default)** | Net disbursement = principal. Invoice and DoubleEntry use full principal. Display shows "0.00" for fee. Turbo confirm says "No processing fee". Identical to current behavior. |
| **Processing fee equals principal** | Validation fails: "Processing fee must be less than the principal amount." Net disbursement would be zero, which is blocked. |
| **Processing fee exceeds principal** | Same validation failure. |
| **Processing fee entered before principal** | If principal is blank, the `processing_fee_less_than_principal` validation is skipped (early return). Principal's own `presence` validation will catch the blank principal. |
| **Negative processing fee** | Validation fails: "Processing fee must be greater than or equal to 0." |
| **Existing loans (pre-migration)** | Migration sets `processing_fee_cents = 0` (NOT NULL default). No behavioral change — net = principal. |
| **Already-disbursed loans** | Processing fee field is disabled/locked. Net disbursement = principal (since fee was 0). Disbursement invoice amount unchanged. |
| **Very large processing fee** | Bounded by < principal. Display uses `humanized_money_with_symbol` which handles large numbers with proper formatting. |
| **Loan created from application** | `Loans::CreateFromApplication` does not set `processing_fee` — it defaults to 0 from the DB column default. Operator sets it during pre-disbursement editing. |

---

## Migration Plan

```ruby
class AddProcessingFeeToLoans < ActiveRecord::Migration[8.0]
  def change
    add_column :loans, :processing_fee_cents, :bigint, null: false, default: 0
  end
end
```

Single column addition with a default — no data migration needed. Safe for zero-downtime deployment. All existing rows get `processing_fee_cents = 0`.

---

## Acceptance Criteria

1. Loan has a mandatory `processing_fee` money field with DB default 0, shown in the pre-disbursement loan details form
2. Processing fee validates: present, ≥ 0, and strictly < principal amount (on `:details_update` context)
3. Processing fee field is disabled/locked after disbursement (same as other pre-disbursement fields)
4. "Current loan summary" displays processing fee and net disbursement amount (principal − fee)
5. Pre-disbursement "Disbursement" section shows a financial summary with principal, processing fee, and net disbursement when readiness is confirmed
6. Turbo confirm dialog for disbursement includes the net disbursement amount breakdown
7. Post-disbursement "Disbursement" section shows principal, processing fee, and disbursed amount (net)
8. Disbursement invoice `amount_cents` = `net_disbursement_amount_cents` (principal − processing fee)
9. DoubleEntry transfer at disbursement uses `net_disbursement_amount_cents`
10. `Loans::Disburse` blocks if net disbursement amount is ≤ 0
11. Repayment schedule generation is unchanged — still based on principal + interest
12. `Loans::EvaluateDisbursementReadiness` includes processing fee in financial details validation
13. `LoansController#loan_params` permits `:processing_fee`
14. Existing loans default to `processing_fee_cents = 0` and behave identically to current behavior
15. All existing tests pass (with updates for changed disbursement invoice amount and DoubleEntry transfer amount where processing fee is non-zero)
