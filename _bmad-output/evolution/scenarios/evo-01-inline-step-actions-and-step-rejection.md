# EVO-01: Inline Step Actions and Step-Level Rejection

## Target

Redesign the application review workflow UI so that each review step has its own action buttons inline, replace the application-level "Reject" with step-level rejection that auto-rejects the application, enforce pre-decision details before approval, restructure the workflow definition to add "Request details" as a dedicated step, and give the History Check step a direct link to the borrower's lending history.

## Current State

**What users experience today:**

1. The review workflow section has a single shared "Current step actions" area at the top with "Approve step" and "Request details" buttons — these always target whichever step is currently active, which is not obvious.
2. The 3 review step cards (History check → Phone screening → Verification) are display-only — they show status badges but have no actionable buttons.
3. "Reject application" is an application-level action in the "Application decision" section, unrelated to any specific step. No rejection note is required.
4. "Request details" is a status transition on any step, not a dedicated step in the workflow.
5. The History Check step card has no connection to borrower lending history — that data lives in a completely separate "Borrower lending context" section further down the page.
6. Application approval only requires `status == "in progress"` and all steps approved — it does not check whether pre-decision details (amount, tenure, frequency, interest mode) have been filled in.

## Desired State

**What users should experience after:**

### 1. Per-step inline action buttons

Each review step card shows its own action buttons when that step is the active step:
- **"Approve step"** — marks this step as approved, advances workflow to the next step
- **"Reject step"** — opens a note input; on submit, rejects this step AND auto-rejects the entire application, saving the note as `decision_notes`

When a step is not the active step, its card shows only its status (no buttons). Completed steps show their final status. Future steps show "Awaiting turn".

The shared "Current step actions" area at the top of the review section is removed entirely.

### 2. "Request details" becomes a workflow step

The current "Request details" status transition is removed from step actions. Instead, a new workflow step **"Request details"** is inserted at position 3 (after Phone screening, before Verification):

| Position | Step key | Label |
|----------|----------|-------|
| 1 | history_check | History check |
| 2 | phone_screening | Phone screening |
| 3 | request_details | Request details |
| 4 | verification | Verification |

This step is approved when the reviewer confirms that all requested information has been received. It follows the same inline approve/reject pattern as all other steps.

### 3. Streamline the application decision section

The "Reject application" button is removed from the decision section — rejection now only happens through step-level rejection. The decision section retains two actions:
- **"Approve application"** — visible when all steps are approved (since the Request Details step can only be approved when pre-decision details are complete, no separate details check is needed here).
- **"Cancel application"** — remains as-is (separate concern — borrower withdrawal).

`LoanApplication#approvable?` remains unchanged (`status == "in progress" && all_review_steps_approved?`). The pre-decision details gate is enforced structurally through the Request Details workflow step. `LoanApplication#rejectable?` is no longer called from the controller.

### 4. History Check step links to borrower history

The History Check step card gets a **"View borrower history"** button/link that opens the borrower's detail page (`borrower_path`) in a new tab. This gives the reviewer quick access to the full lending history (applications, loans) without leaving the review page.

The existing "Borrower lending context" section on the application page is removed — the borrower detail page already provides this information, and the History Check step now links directly to it.

### 5. Step rejection auto-rejects application

When any step is rejected:
- The `ReviewStep` status is set to `"rejected"`
- A `rejection_note` (new text column on `review_steps`) captures the reviewer's note
- The `LoanApplication` status is set to `"rejected"`
- The `LoanApplication.decision_notes` is set to the rejection note
- All remaining non-final steps stay as-is (their status is not changed)
- This happens atomically in a single transaction

## User Journey

### Entry point
User navigates to an application detail page from the applications list, dashboard drill-in, or borrower profile.

### Proposed flow (step-by-step)

1. **Arrive at application page** — Header shows application info and status. Review workflow section shows all 4 step cards in order.

2. **Step 1: History check (active)** — Card shows "Approve step" and "Reject step" buttons, plus a "View borrower history" link that opens borrower profile in new tab. Reviewer opens borrower history, reviews lending records, returns to application tab.
   - If satisfied → clicks "Approve step" → step moves to approved, Step 2 becomes active.
   - If not satisfied → clicks "Reject step" → note input appears → submits → step rejected, application auto-rejected with note.

3. **Step 2: Phone screening (active)** — Card shows "Approve step" and "Reject step" buttons.
   - Same approve/reject pattern.

4. **Step 3: Request details (active)** — Card checks whether all 4 pre-decision detail fields (amount, tenure, frequency, interest mode) are filled in.
   - If details are incomplete → card shows guidance to fill in the form below and only "Reject step" is available.
   - If details are complete → "Approve step" appears alongside "Reject step". Reviewer approves to confirm details are satisfactory.

5. **Step 4: Verification (active)** — Card shows "Approve step" and "Reject step" buttons. Final verification step.
   - Same approve/reject pattern.

6. **All steps approved** — Review section shows all steps as completed. Application decision section shows "Approve application" button (only if pre-decision details are filled in). "Cancel application" remains available.

7. **Approve application** — Creates loan, sets status to approved. Same as today.

### Rejection path (at any step)
- Reviewer clicks "Reject step" on the active step
- A text input/textarea for the rejection note appears inline on the step card
- Reviewer enters a note (required) and confirms
- Step is rejected, application is rejected, note is saved as decision_notes
- Page reloads showing the final rejected state

## Success Criteria

1. Each step card has its own inline "Approve step" and "Reject step" buttons (only when active)
2. No shared "Current step actions" area exists
3. No "Reject application" button exists in the decision section
4. "Cancel application" button remains available in the decision section
5. Request Details step card hides "Approve step" until all 4 pre-decision detail fields are present; shows guidance directing user to fill in the form
6. Rejecting any step with a note auto-rejects the entire application; the note is saved as `decision_notes` on the application and `rejection_note` on the step
7. History Check step card has a "View borrower history" link opening borrower profile in a new tab
8. The separate "Borrower lending context" section is removed from the application page
9. Workflow has 4 steps: History check → Phone screening → Request details → Verification
10. All existing tests pass (with updates for changed behavior)

## Scope

### Pages affected
- `app/views/loan_applications/show.html.erb` — major restructure of review workflow section, remove borrower lending context section, update decision section

### Components touched
- Review step cards — add inline action buttons, reject note input
- "Current step actions" block — removed
- "Borrower lending context" section — removed
- "Application decision" section — remove reject button, add pre-decision detail guard

### Model / data changes
- **`ReviewStep`** — add `rejection_note` text column; update `WORKFLOW_DEFINITION` to include `request_details` step at position 3, shift verification to position 4
- **`LoanApplication`** — update `approvable?` to check pre-decision detail presence; remove `rejectable?` (no longer called from controller)
- **Migration** — add `rejection_note` to `review_steps`; handle existing data (re-seed steps for any in-progress applications with old 3-step workflow)

### Service changes
- **`ReviewSteps::Reject`** (new) — extends `Transition`; rejects the step, saves rejection note, auto-rejects the application with decision_notes
- **`ReviewSteps::Approve`** — unchanged logic
- **`ReviewSteps::RequestDetails`** — removed (no longer a status transition)
- **`LoanApplications::Reject`** — keep the service but remove the controller action/route for it
- **`ReviewStepsController`** — add `reject` action, remove `request_details` action

### Route changes
- Remove `patch :reject` from `loan_applications` member routes
- Remove `patch :request_details` from `review_steps` member routes
- Add `patch :reject` to `review_steps` member routes

### Risk level
**Medium** — Behavioral change to the review workflow (new step, new rejection flow, removed actions). No structural data model changes beyond adding a column and updating a constant. Existing approved/cancelled applications are unaffected. In-progress applications need step re-initialization to pick up the new 4-step workflow.
