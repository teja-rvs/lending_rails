# Application Review Detail — Update Specification

**Scenario:** EVO-01 — Inline Step Actions and Step-Level Rejection

## Change Summary

Restructure the application review detail page so that each review step card has its own inline approve/reject buttons, replace the application-level "Reject" with step-level rejection that auto-rejects the application, add "Request details" as a dedicated workflow step, link the History Check step to the borrower profile, remove the separate "Borrower lending context" section, and require all pre-decision details before the application can be approved.

---

## Before → After: Page Section Map

| Section | Before | After |
|---------|--------|-------|
| **Review workflow header** | Shows "Current application status" + "Active review step" summary grid | Same — no change |
| **Current step actions block** | Shared action area with "Approve step" / "Request details" targeting the active step | **Removed entirely** |
| **Step cards (ol)** | 3 display-only cards (History check, Phone screening, Verification) showing status badge + label | **4 interactive cards** (History check, Phone screening, Request details, Verification). Active card has inline approve/reject buttons. History check card has "View borrower history" link. |
| **Borrower lending context** | Full section with borrower context, eligibility, and linked records list | **Removed** — replaced by "View borrower history" link on History Check step |
| **Application decision** | "Approve application" + "Reject application" + "Cancel application" buttons | "Approve application" (gated on all steps approved + pre-decision details present) + "Cancel application" only. Missing-details guidance shown when applicable. |
| **Pre-decision details form** | No change | No change |
| **Current request summary** | No change | No change |
| **Activity timeline** | No change | No change |

---

## Component Specifications

### C1: Review Step Card (redesigned)

Each `<li>` in the review step list becomes an interactive card with conditional content based on step state.

**Card states:**

| State | Left column | Right column | Bottom row |
|-------|------------|-------------|------------|
| **Active (initialized)** | Step N label, "Ready for review" summary | Status badge ("Initialized") | "Approve step" button + "Reject step" button |
| **Active (request_details, details incomplete)** | Step N label, "Fill in the pre-decision application details below before approving this step." summary | Status badge ("Initialized") | "Reject step" button only — "Approve step" is hidden until all 4 detail fields are present |
| **Active (request_details, details complete)** | Step N label, "Application details are complete. Ready for approval." summary | Status badge ("Initialized") | "Approve step" button + "Reject step" button |
| **Active (history_check, initialized)** | Step N label, "Ready for review" summary | Status badge | "Approve step" + "Reject step" + "View borrower history" link (opens new tab) |
| **Completed (approved)** | Step N label, "Approved" summary | Status badge ("Approved", success tone) | No buttons |
| **Completed (rejected)** | Step N label, "Rejected — {rejection_note}" summary | Status badge ("Rejected", danger tone) | No buttons |
| **Queued** | Step N label, "Awaiting turn" summary | Status badge ("Initialized", warning tone) | No buttons |
| **Post-final-decision** | Step N label, status-based summary | Status badge | No buttons (locked) |

**Active card visual emphasis:**
- Border changes from `border-slate-200` to `border-slate-400` to indicate interactivity
- Background changes from transparent to a subtle `bg-slate-50`

**Button layout within the active card:**
```
┌──────────────────────────────────────────────────────────┐
│ STEP 1                                                   │
│ History check                          [Initialized] ◯   │
│ Ready for review.                                        │
│                                                          │
│ [Approve step]  [Reject step]  [View borrower history →] │
└──────────────────────────────────────────────────────────┘
```

**Button styles:**
- "Approve step" — primary dark button (existing `bg-slate-950` style)
- "Reject step" — danger outline button (`border-rose-300 text-rose-700`, matching existing reject styling)
- "View borrower history" — text link with arrow, `target="_blank"` + `rel="noopener noreferrer"`, only on `history_check` step

### C2: Reject Step Inline Form

When the user clicks "Reject step", the button row is replaced (or expanded below) with an inline form:

```
┌──────────────────────────────────────────────────────────┐
│ STEP 2                                                   │
│ Phone screening                        [Initialized] ◯   │
│ Ready for review.                                        │
│                                                          │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ Rejection note (required)                            │ │
│ │ [textarea, 3 rows]                                   │ │
│ └──────────────────────────────────────────────────────┘ │
│ [Confirm rejection]  [Cancel]                            │
│                                                          │
│ ⚠ Rejecting this step will reject the entire            │
│   application. This cannot be undone.                    │
└──────────────────────────────────────────────────────────┘

```

**Implementation approach:** Use a `<details>` element or Turbo/Stimulus toggle. When "Reject step" is clicked, the textarea + confirm/cancel buttons appear. "Cancel" hides the form. "Confirm rejection" submits.

**Form submission:**
- `PATCH /loan_applications/:loan_application_id/review_steps/:id/reject`
- Params: `{ rejection_note: "..." }`
- Confirmation dialog via `data-turbo-confirm`: "Rejecting this step will reject the entire application. This cannot be undone. Continue?"

### C3: Application Decision Section (updated)

**Before (editable, not all steps approved):**
```
Approval becomes available once review has started and every review step
is approved. Rejection and cancellation remain available while the
application is still pre-decision.

[Reject application]  [Cancel application]
```

**After (editable, not all steps approved):**
```
Approval becomes available once every review step is approved. Steps can
be rejected individually during the review process.

[Cancel application]
```

**After (all steps approved — approvable):**
```
All review steps are approved. You can now record the final application
outcome.

[Approve application]  [Cancel application]
```

Since the "Request details" step already gates approval on pre-decision details being complete, there is no separate details check needed here. If all 4 steps are approved, the details are guaranteed to be present.

**After (final decision reached):**
No change from current behavior — shows outcome, decision notes, and timestamp.

### C4: Borrower Lending Context Section

**Removed entirely.** The `<section id="borrower-lending-context">` block (lines 168–241 of current `show.html.erb`) is deleted. The controller's `load_borrower_history` call and associated instance variables (`@borrower_history`, `@borrower_history_records`) are also removed.

---

## Data Model Changes

### ReviewStep — add `rejection_note` column

```ruby
# Migration
add_column :review_steps, :rejection_note, :text
```

No null constraint — only populated when status is "rejected".

### ReviewStep — update WORKFLOW_DEFINITION

```ruby
WORKFLOW_DEFINITION = [
  WorkflowDefinition.new(step_key: "history_check", label: "History check", position: 1),
  WorkflowDefinition.new(step_key: "phone_screening", label: "Phone screening", position: 2),
  WorkflowDefinition.new(step_key: "request_details", label: "Request details", position: 3),
  WorkflowDefinition.new(step_key: "verification", label: "Verification", position: 4)
].freeze
```

**Existing data handling:** The `InitializeReviewWorkflow` service already uses `find_or_create_by!` per step_key. When an in-progress application's show page is loaded, it will automatically create the new `request_details` step and leave existing steps untouched. The `verification` step position will need updating from 3→4 for existing records — handle in migration.

### ReviewStep model updates

- Add `normalizes :rejection_note` (same pattern as other text fields)
- Update `step_key` and `position` validations to include the new step
- Add a convenience method: `history_check?` → `step_key == "history_check"`

### LoanApplication model updates

`approvable?` is **unchanged** — it still checks `status == "in progress" && all_review_steps_approved?`. Since the "Request details" step can only be approved when all 4 pre-decision detail fields are present, the details check is enforced structurally through the workflow.

Add a helper used by the view to determine if the Request Details step's approve button should appear:

```ruby
def pre_decision_details_complete?
  requested_amount.present? &&
    requested_tenure_in_months.present? &&
    requested_repayment_frequency.present? &&
    proposed_interest_mode.present?
end
```

---

## Service Changes

### New: `ReviewSteps::Reject`

```ruby
module ReviewSteps
  class Reject < Transition
    def initialize(loan_application:, review_step_id:, rejection_note:)
      super(loan_application:, review_step_id:)
      @rejection_note = rejection_note
    end

    private
      attr_reader :rejection_note

      def allowed_statuses
        ["initialized", "waiting for details"]
      end

      def next_status
        "rejected"
      end

      def success_message
        "Review step rejected. Application has been rejected."
      end

      # Override call behavior from Transition to also reject the application
      # Done inside the same with_lock block
  end
end
```

The `Reject` service overrides the post-transition behavior in `Transition#call` to:
1. Set `review_step.rejection_note = rejection_note` before saving
2. After step update, set `loan_application.status = "rejected"` and `loan_application.decision_notes = rejection_note`

### Remove: `ReviewSteps::RequestDetails`

Delete `app/services/review_steps/request_details.rb`. The "Request details" is now a workflow step, not a status transition.

### Keep: `LoanApplications::Reject`

Keep the service file — it may still be useful for programmatic rejection. But remove the controller action and route that expose it to the UI.

---

## Route Changes

```ruby
resources :loan_applications, only: %i[index show update] do
  member do
    patch :approve
    # patch :reject  ← REMOVE
    patch :cancel
  end

  resources :review_steps, only: [] do
    member do
      patch :approve
      patch :reject       # ← ADD
      # patch :request_details  ← REMOVE
    end
  end
end
```

## Controller Changes

### `LoanApplicationsController`

- Remove `reject` action
- Remove `load_borrower_history` private method
- Remove `@borrower_history` and `@borrower_history_records` from `show`
- Keep `cancel` action as-is

### `ReviewStepsController`

- Add `reject` action:
  ```ruby
  def reject
    handle_result(
      ReviewSteps::Reject.call(
        loan_application: @loan_application,
        review_step_id: params[:id],
        rejection_note: params[:rejection_note]
      )
    )
  end
  ```
- Remove `request_details` action

---

## Responsive Behavior

The step cards already use `flex-col` → `sm:flex-row` for the label/status layout. The new button row follows the same pattern:

- **Mobile (< 640px):** Buttons stack vertically, full width
- **Desktop (≥ 640px):** Buttons sit in a horizontal row with `flex-wrap gap-3`

The reject note textarea spans full width of the card at all breakpoints.

---

## Edge Cases

| Edge case | Handling |
|-----------|----------|
| **Empty rejection note** | "Confirm rejection" button is disabled until textarea has content. Server-side validation also rejects blank notes. |
| **Very long rejection note** | Textarea is unconstrained (matches existing `notes` pattern). Displayed in decision section with word-wrap. |
| **Application already rejected/cancelled** | Step cards show no buttons (existing `editable` guard). Decision section shows final outcome. |
| **In-progress application with old 3-step workflow** | Migration updates existing `verification` steps from position 3→4. `InitializeReviewWorkflow` creates the new `request_details` step on next page load. |
| **Request details step is active but form incomplete** | "Approve step" button hidden on the step card. Summary text directs user to fill in the form below. "Reject step" remains available. |
| **User fills in form then returns to step** | Page reloads after form save. If all 4 fields are now present, "Approve step" appears on the Request Details card. |
| **Reject step on the last step** | Same behavior — step rejected, application rejected. No special case. |
| **Browser back after rejection** | Page shows rejected state on reload. Turbo handles redirect. |
| **History check "View borrower history" link** | Opens `borrower_path(borrower)` with `target="_blank"`. Works even if step is already approved (link stays visible on completed history_check cards). |
| **Concurrent step rejection** | `with_lock` in `Transition` base class prevents race conditions. Second request gets "final decision" error. |

---

## Migration Plan

```ruby
class AddStepRejectionAndRequestDetailsStep < ActiveRecord::Migration[8.0]
  def up
    add_column :review_steps, :rejection_note, :text

    # Shift existing verification steps from position 3 to position 4
    ReviewStep.where(step_key: "verification").update_all(position: 4)
  end

  def down
    # Shift verification back to position 3
    ReviewStep.where(step_key: "verification").update_all(position: 3)

    # Remove any request_details steps that were auto-created
    ReviewStep.where(step_key: "request_details").delete_all

    remove_column :review_steps, :rejection_note
  end
end
```

The new `request_details` steps for existing applications are created lazily by `InitializeReviewWorkflow` on the next page load — no bulk seed needed.

---

## Acceptance Criteria

1. Each step card shows inline "Approve step" and "Reject step" buttons only when it is the active step and the application is pre-decision
2. No shared "Current step actions" block exists on the page
3. History Check step card shows a "View borrower history" link that opens the borrower profile in a new browser tab; this link is visible on the history_check card regardless of step status
4. The "Borrower lending context" section is removed from the page
5. Clicking "Reject step" reveals an inline form with a required rejection note textarea, a "Confirm rejection" button, and a turbo-confirm warning
6. Confirming step rejection rejects the step (with note), rejects the application (with same note as decision_notes), all in one transaction
7. No "Reject application" button exists in the application decision section
8. "Approve application" button appears when all steps are approved (no separate detail check needed — Request Details step enforces it)
9. Request Details step card hides "Approve step" until all 4 pre-decision detail fields (amount, tenure, frequency, interest mode) are present; shows guidance directing user to fill in the form
10. "Cancel application" button remains available for pre-decision applications
11. Workflow has 4 ordered steps: History check (1), Phone screening (2), Request details (3), Verification (4)
12. Existing in-progress applications with the old 3-step workflow gracefully gain the new step on next page load
13. The `rejection_note` is persisted on the `review_steps` table
14. Server-side validation rejects blank rejection notes
