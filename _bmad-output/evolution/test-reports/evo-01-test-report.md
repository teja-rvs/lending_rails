# Test Report: EVO-01 — Inline Step Actions and Step-Level Rejection

## Summary

**14/14 criteria traced through code. 0 issues found.**

PostgreSQL is not installed on this machine, so the automated test suite (`bundle exec rspec`) could not be executed. This report is based on a systematic code-level trace of every acceptance criterion against the implementation.

**Action required:** Run `bin/rails db:migrate && bundle exec rspec` once PostgreSQL is available to confirm full green suite.

## Results

| # | Criterion | Code Trace | Verified? |
|---|-----------|-----------|-----------|
| 1 | Each step card shows inline "Approve step" and "Reject step" buttons only when active and pre-decision | `show.html.erb:101-102` — `can_approve_step` and `can_reject_step` computed per step; buttons rendered conditionally at lines 133-160 inside each `<li>` | Yes |
| 2 | No shared "Current step actions" block exists | Old lines 98-129 (shared action area) deleted entirely; step list starts at line 93 with `<ol>` | Yes |
| 3 | History Check step has "View borrower history →" link opening borrower profile in new tab | `show.html.erb:162-164` — `is_history_check` conditional renders `link_to` with `target="_blank"` and `rel="noopener noreferrer"`, visible regardless of step status | Yes |
| 4 | "Borrower lending context" section removed | Old section (lines 168-241) deleted; `load_borrower_history` removed from controller; `@borrower_history` / `@borrower_history_records` no longer set | Yes |
| 5 | "Reject step" reveals inline form with required note + turbo-confirm | `show.html.erb:140-159` — `<details>` element contains `form_with` posting to `reject_loan_application_review_step_path`; textarea has `required: true`; submit has `data-turbo-confirm`; warning text shown | Yes |
| 6 | Step rejection rejects step + application atomically with notes | `ReviewSteps::Reject` — `apply_step_changes` sets `rejection_note` on step; `after_step_transition` sets `status: "rejected"` and `decision_notes` on application; all within `Transition#call`'s `with_lock` block | Yes |
| 7 | No "Reject application" button in decision section | Route `patch :reject` removed from `loan_applications` member routes; `reject` action removed from `LoanApplicationsController`; view decision section only shows "Approve application" + "Cancel application" | Yes |
| 8 | "Approve application" appears when all steps approved | `approvable?` checks `status == "in progress" && all_review_steps_approved?` — unchanged; Request Details step structurally enforces details | Yes |
| 9 | Request Details step hides "Approve step" until all 4 detail fields present | `show.html.erb:101` — `can_approve_step = is_active && editable && (!is_request_details \|\| details_complete)`; when `is_request_details && !details_complete`, approve button hidden; summary says "Fill in the pre-decision application details below before approving this step." | Yes |
| 10 | "Cancel application" remains available | `show.html.erb:184` — `button_to "Cancel application"` present in decision section for editable applications | Yes |
| 11 | Workflow has 4 steps: History check → Phone screening → Request details → Verification | `ReviewStep::WORKFLOW_DEFINITION` has 4 entries at positions 1-4 | Yes |
| 12 | Existing applications gain new step on next page load | `InitializeReviewWorkflow` uses `find_or_create_by!(step_key:)` per definition; migration shifts verification from position 3→4; new `request_details` step created lazily | Yes |
| 13 | `rejection_note` persisted on `review_steps` table | Migration adds `rejection_note` text column; model normalizes it; `Reject` service sets it via `apply_step_changes` before `update!` | Yes |
| 14 | Server-side validation rejects blank rejection notes | `ReviewSteps::Reject#validate_before_transition` returns error when `rejection_note.blank?`; `Transition#call` checks this before any state mutation | Yes |

## Edge Cases Traced

| Edge case | Handling | Verified? |
|-----------|----------|-----------|
| Reject step on "open" app | `promote_application_status!` sets "in progress" first, then `after_step_transition` sets "rejected" — final state is "rejected" | Yes |
| Rejected step displays note | `show.html.erb:103-104` — checks `review_step.rejection_note.present?` and shows "Rejected — {note}" | Yes |
| Request details step with incomplete form | `can_approve_step` is false; summary text directs to form; only "Reject step" available | Yes |
| Concurrent rejection | `with_lock` on loan_application + `lock` on review_steps prevents race | Yes |
| History check link on approved step | `is_history_check` condition is independent of `is_active` — link visible on any status | Yes |

## Regression Risks

| Area | Risk | Mitigation |
|------|------|------------|
| Existing approved/cancelled applications | None — `InitializeReviewWorkflow` only creates missing steps, doesn't touch existing | Low |
| `ReviewSteps::Approve` | No changes to approve logic; hooks are no-ops in base class | Low |
| Application cancel flow | Unchanged — controller action, route, and view button all preserved | Low |
| PaperTrail audit trail | Both step rejection and application rejection create PaperTrail versions (model has `has_paper_trail`) | Low |

## Automated Test Coverage

| Test file | Status | Tests |
|-----------|--------|-------|
| `spec/services/review_steps/reject_spec.rb` | New — 5 tests | Covers: happy path, blank note, non-active step, final decision, waiting-for-details step |
| `spec/services/review_steps/approve_spec.rb` | Updated — 5 tests | All updated for 4-step workflow |
| `spec/services/review_steps/transition_spec.rb` | Updated — 9 tests | All updated for 4-step workflow; RequestDetails reference replaced |
| `spec/services/review_steps/request_details_spec.rb` | Deleted | Service no longer exists |
| `spec/models/review_step_spec.rb` | Updated | Workflow definition, `.active_for`, validation tests updated |
| `spec/models/loan_application_spec.rb` | Updated | `#approvable?` tests updated for 4 steps |
| `spec/services/loan_applications/approve_spec.rb` | Updated | Helper and inline step creation updated |
| `spec/services/loan_applications/initialize_review_workflow_spec.rb` | Updated | Expects 4 steps |
| `spec/requests/loan_applications_spec.rb` | Updated | Removed borrower context tests, reject tests; updated step counts |
| `spec/system/loan_application_workflow_spec.rb` | Updated | Removed borrower context tests, reject/request-details tests; added step rejection and history link tests |

## Issues Found

None.

## Recommendation

**Pass with condition** — All 14 acceptance criteria verified through code trace. Full confidence pending `bundle exec rspec` green suite once PostgreSQL is available. Run:

```bash
bin/rails db:migrate
bundle exec rspec
```
