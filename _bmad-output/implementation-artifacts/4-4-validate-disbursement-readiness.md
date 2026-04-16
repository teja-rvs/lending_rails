# Story 4.4: Validate Disbursement Readiness

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want the system to verify that a loan is fully ready before disbursement is allowed,
So that funds cannot be released while required preconditions are incomplete.

## Acceptance Criteria

1. **Given** a loan is still in a pre-disbursement state  
   **When** the admin opens the disbursement readiness view  
   **Then** the system evaluates the required readiness conditions for disbursement  
   **And** shows whether the loan is blocked or ready for the next step

2. **Given** one or more readiness conditions are missing  
   **When** the admin attempts to proceed toward disbursement  
   **Then** the system blocks the action  
   **And** displays a blocked-state explanation describing the missing prerequisite and safest next step

3. **Given** the readiness evaluation is implemented  
   **When** the application behavior is reviewed  
   **Then** the readiness rules are enforced by server-side domain logic rather than UI-only checks  
   **And** the same readiness outcome can be tested independently of the browser flow

## Tasks / Subtasks

- [x] Task 1: Add domain service `Loans::EvaluateDisbursementReadiness` (or equivalent name under `app/services/loans/`) (AC: #1, #3)
  - [x] 1.1 Return a stable result object (struct or value object) with: `ready_for_disbursement_action?` (boolean), `items` (enumerable checklist), optional `blocked_summary` string
  - [x] 1.2 Each checklist item: `key` (symbol), `met?` (boolean), `label` (short), `detail` (why it matters), `next_step` (actionable recovery copy)
  - [x] 1.3 Encode rules derived from current domain (see Dev Notes — Readiness rules); use `loan.valid?(:details_update)` (or equivalent) for financial-field completeness — do not duplicate validation logic in divergent ways
  - [x] 1.4 Pure domain logic: no `params`, no `Current.user`, no HTTP — only `Loan` and loaded associations as needed
  - [x] 1.5 Unit specs covering: loan in `created` / `documentation_in_progress` / `ready_for_disbursement` with various combinations of missing details vs complete details; assert stable keys and copy for blocked cases
- [x] Task 2: Add server-side guard for “proceed toward disbursement” (AC: #2, #3)
  - [x] 2.1 If Story 4.5 will add `Loans::Disburse` / `disburse` controller action, define a single authoritative check method used by both UI and that service (e.g. `Loans::EvaluateDisbursementReadiness` + `allowed_to_disburse?` or `readiness_result.ready_for_disbursement_action?`)
  - [x] 2.2 For this story, implement the minimum route/action that represents “attempt to proceed toward disbursement” **or** document that the guard must wrap `loan.disburse!` / disburse service when added — **prefer** adding a thin `PATCH` member action (e.g. `attempt_disbursement` or `validate_disbursement`) that returns redirect+flash when blocked, so AC #2 is demonstrably enforced before 4.5 expands behavior
  - [x] 2.3 Use `loan.with_lock` when the action could race with concurrent edits (match `LoansController` patterns)
  - [x] 2.4 Request spec: blocked response includes user-visible explanation (flash or response body per pattern)
- [x] Task 3: Disbursement readiness view on loan detail (AC: #1)
  - [x] 3.1 Add a dedicated section (e.g. “Disbursement readiness”) on `app/views/loans/show.html.erb` — placement: after lifecycle/header context and documentation section is logical (readiness summarizes “can we release funds next”)
  - [x] 3.2 Controller sets `@disbursement_readiness = Loans::EvaluateDisbursementReadiness.call(loan: @loan)` (or `.new(loan: @loan).call`) in `show` — keep controller thin
  - [x] 3.3 Visual design: follow UX blocked-state / success patterns (semantic borders, calm copy) per `ux-design-specification.md` — list each item with met/unmet indicator (check vs warning), never rely on color alone (icons + text)
  - [x] 3.4 When not `ready_for_disbursement` lifecycle state, headline should still clarify **next stage** vs **ready to disburse** (avoid implying money can move before `ready_for_disbursement` unless rules say so)
  - [x] 3.5 If a “proceed” button is shown for AC #2, disable or hide it when blocked; primary CTA copy must be explicit (avoid vague “Continue”)
- [x] Task 4: Testing matrix (AC: #3)
  - [x] 4.1 Service specs are the source of truth for rule coverage
  - [x] 4.2 Request/system specs prove blocked “proceed” path and visible explanation
  - [x] 4.3 Maintain SimpleCov / full suite discipline from prior stories (run full `bundle exec rspec` before merge)

### Review Findings

- [x] [Review][Patch] Post-disbursement loans render the readiness panel as currently blocked instead of historical context [`app/views/loans/show.html.erb:322`, `app/services/loans/evaluate_disbursement_readiness.rb:70`]

## Dev Notes

### Epic 4 cross-story context

- **4.1** introduced full `Loan` AASM states and events, including `ready_for_disbursement` and `disburse` (`ready_for_disbursement` → `active`). [Source: epics.md — Story 4.1; `app/models/loan.rb`]
- **4.2** established `Loans::UpdateDetails`, `editable_details?`, and `on: :details_update` validations for principal, tenure, repayment frequency, interest mode, and interest branch fields. [Source: `app/services/loans/update_details.rb`, `app/models/loan.rb`]
- **4.3** added `DocumentUpload`, documentation stage UI, and `complete_documentation` transition to `ready_for_disbursement`. Documentation can be completed without uploads (empty state allowed in 4.3). [Source: `_bmad-output/implementation-artifacts/4-3-complete-loan-documentation-and-manage-supporting-documents.md`]
- **4.5** will execute guarded disbursement, invoices, `double_entry`, and lock post-disbursement — **do not** implement money movement, postings, or invoice records in 4.4. [Source: epics.md — Story 4.5]

### Readiness rules (authoritative for this story)

Implement conditions that match product intent: **no disbursement until pre-disbursement work is complete and financial inputs are valid.**

1. **Lifecycle / documentation path**  
   - Disbursement must not be presented as allowed until the loan has reached `ready_for_disbursement` (documentation completion event has fired).  
   - For loans in `created` or `documentation_in_progress`, the readiness view should show documentation/lifecycle items as **not met** with recovery pointing to existing actions (`begin_documentation`, complete loan details, upload docs, `complete_documentation` as appropriate).

2. **Financial details**  
   - When evaluating whether the loan is ready for the **disbursement** step, require the same completeness as `loan.valid?(:details_update)` (principal, tenure, repayment frequency, interest mode, and branch-specific interest fields).  
   - Reuse validation context — avoid a second set of ad hoc checks that drift from `Loan` validations.

3. **Documents**  
   - Do **not** add a hard “at least one document” rule unless you find explicit product requirement; PRD stresses documentation as a stage, and 4.3 allows zero uploads when completing documentation.

4. **Future fields (bank details, charges)**  
   - PRD FR32 mentions bank details and charges; `loans` table currently has no such columns. Do not invent columns in 4.4 — if readiness needs placeholders, track as follow-up epic/PRD alignment.

### Architecture compliance

- **Domain services own rules.** Readiness evaluation belongs in `app/services/loans/`, not in views or helpers as the sole source of truth. [Source: architecture.md — Domain logic boundaries]
- **Result / value object.** Prefer a small immutable result object over ad hoc hashes for checklist items so tests stay stable. [Source: architecture.md — Service boundaries; existing `Loans::UpdateDetails::Result` pattern]
- **Concurrency.** Follow `with_lock` on mutating controller actions consistent with `LoansController#begin_documentation` / `#complete_documentation`. [Source: architecture.md — Concurrency patterns]
- **Testing.** RSpec for services and requests; system spec optional but valuable for blocked-state UX. [Source: architecture.md — Testing expectations]
- **No `double_entry` / disbursement invoices in this story.** [Source: architecture.md — Money-moving services]

### Library / framework requirements

- **Rails ~> 8.1**, **AASM ~> 5.5** — use `may_disburse?` only for transition eligibility; **readiness** is a separate business gate that should combine AASM state + validations + any extra rules. [Source: `Gemfile`, `app/models/loan.rb`]
- **Pundit:** If a policy exists for loans, authorize new actions consistently with `show`/`update`. [Source: existing controller policies if present]

### File structure (expected touchpoints)

| Area | Files |
|------|--------|
| New | `app/services/loans/evaluate_disbursement_readiness.rb` (name may vary but keep namespace `Loans::`) |
| Modify | `app/controllers/loans_controller.rb` — expose readiness result on `show`; add member action if implementing proceed guard |
| Modify | `config/routes.rb` — member route if adding proceed/attempt action |
| Modify | `app/views/loans/show.html.erb` — disbursement readiness section |
| New/Modify | `spec/services/loans/evaluate_disbursement_readiness_spec.rb`, `spec/requests/loans_spec.rb`, optional `spec/system/loan_detail_flow_spec.rb` |

### UX requirements

- Blocked-state callouts: calm, specific, actionable; explain **what** is missing and **what to do next** (align with UX spec blocked-state and high-risk action patterns). [Source: `ux-design-specification.md` — Feedback Patterns, Blocked-State Callout, Forms]

### Previous story intelligence (4.3)

- **Thin controllers:** `find → service → redirect + flash` — same for any new disbursement attempt action. [Source: `4-3` story file]
- **Do not** weaken `Documents::Upload` / documentation rules in 4.4 — readiness **consumes** current state. [Source: `4-3` Dev Notes]
- **Explicit non-goals from 4.3:** disbursement readiness was explicitly deferred to 4.4; 4.3 file lists “Do not add disbursement readiness checks” as completed scope boundary — now implement here. [Source: `4-3` Dev Notes — Files NOT to touch section]
- **Test count / SimpleCov:** Full suite was ~270 examples at 4.3 completion — keep green. [Source: `4-3` Dev Agent Record]

### Git intelligence

- Recent commits: documentation story (`15d78cb`), loan preparation (`f6eb7d0`), loan creation (`041a8c4`). Prefer focused commits matching “Add disbursement readiness evaluation.” style.

### Latest technical notes (April 2026)

- No external API version research required for this story; stack is pinned in `Gemfile.lock`. Prefer existing patterns over new gems.

### Project context reference

- No `project-context.md` found in repo; rely on PRD, architecture, epics, and this file.

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Add `Loans::EvaluateDisbursementReadiness` as the single authoritative domain gate for lifecycle readiness and `details_update` financial completeness.
- Reuse that result in `LoansController#show` and a thin `attempt_disbursement` member action guarded with `loan.with_lock`.
- Render a dedicated readiness section on `app/views/loans/show.html.erb` with a checklist, blocked-state explanation, and explicit proceed CTA state.

### Debug Log References

- 2026-04-16T16:24:06+0530: `bundle exec rspec spec/services/loans/evaluate_disbursement_readiness_spec.rb spec/requests/loans_spec.rb` failed before examples ran because PostgreSQL was unreachable on `localhost:5432`.
- 2026-04-16T16:24:06+0530: `docker compose up -d postgres && RAILS_ENV=test bin/rails db:prepare` failed because the Docker daemon socket was unavailable on this machine.
- 2026-04-16T16:24:06+0530: `ReadLints` reported no diagnostics on the edited Ruby, ERB, route, and spec files.
- 2026-04-16T16:24:06+0530: `bundle exec ruby -c` passed for the edited Ruby files and spec files.
- 2026-04-16T16:34:05+0530: `docker compose up -d postgres` brought up the local database, targeted readiness/document regressions passed, `bundle exec rubocop` on the edited files passed, and `bundle exec rspec` finished green with 278 examples and 0 failures.

### Completion Notes List

- Added `Loans::EvaluateDisbursementReadiness` with stable result/checklist structs, lifecycle readiness rules, and financial completeness evaluation based on the existing `details_update` validation context.
- Added the thin `attempt_disbursement` server-side guard, reused the readiness result in the show flow, and rendered a dedicated loan detail readiness section with explicit blocked/ready states and CTA behavior.
- Extended request coverage for the readiness UI and blocked proceed path, added dedicated service specs for the readiness rules, and fixed the document upload invalid-render path so it also provides readiness data when `loans/show` is re-rendered.
- Validation completed successfully with `bundle exec rubocop app/controllers/loans_controller.rb app/controllers/documents_controller.rb app/services/loans/evaluate_disbursement_readiness.rb config/routes.rb spec/services/loans/evaluate_disbursement_readiness_spec.rb spec/requests/loans_spec.rb` and `bundle exec rspec`.

### File List

- `_bmad-output/implementation-artifacts/4-4-validate-disbursement-readiness.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/controllers/documents_controller.rb`
- `app/controllers/loans_controller.rb`
- `app/services/loans/evaluate_disbursement_readiness.rb`
- `app/views/loans/show.html.erb`
- `config/routes.rb`
- `spec/requests/documents_spec.rb`
- `spec/requests/loans_spec.rb`
- `spec/services/loans/evaluate_disbursement_readiness_spec.rb`

### Change Log

- 2026-04-16: Completed disbursement readiness evaluation, blocked proceed guard, loan detail readiness UI, and the related service/request regression coverage; story is ready for review.

---

**Story completion status:** Implementation complete, review patch applied, validation passed, and story status moved to done.
