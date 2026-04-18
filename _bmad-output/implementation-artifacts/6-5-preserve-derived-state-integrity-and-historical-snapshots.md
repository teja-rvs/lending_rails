# Story 6.5: Preserve Derived State Integrity and Historical Snapshots

Status: done

## Story

As an admin operator,
I want derived lifecycle states and borrower snapshots to remain historically trustworthy,
So that record history keeps the context that existed when past decisions were made.

## Acceptance Criteria

1. **Given** applications and loans depend on borrower context
   **When** the system records those lending records
   **Then** it snapshots the relevant borrower data onto the application and loan
   **And** later borrower edits do not rewrite historical decision context

2. **Given** lifecycle states such as overdue and closed are shown in the UI
   **When** the system determines those states
   **Then** they are derived from recorded facts and workflow rules rather than manual toggles
   **And** the displayed status remains consistent with the underlying record history

3. **Given** the admin investigates a historical lending path
   **When** they move through borrower, application, loan, payment, and invoice context
   **Then** the system preserves a trustworthy narrative of what happened
   **And** linked records, statuses, and historical snapshots reinforce that trust

## Tasks / Subtasks

- [x] Task 1: Add model-level validations for snapshot presence on LoanApplication (AC: #1)
  - [x] 1.1 Add `validates :borrower_full_name_snapshot, presence: true` and `validates :borrower_phone_number_snapshot, presence: true` to `app/models/loan_application.rb`. Loan already validates presence; LoanApplication does not — this is the gap. The snapshots are set at creation time by `LoanApplications::Create` service, so presence validation ensures no application is ever saved without snapshot context.
  - [x] 1.2 Add model spec in `spec/models/loan_application_spec.rb` verifying that a LoanApplication without snapshot values fails validation.

- [x] Task 2: Add display helpers for LoanApplication snapshot fallback (AC: #1, #3)
  - [x] 2.1 Add `borrower_full_name_display` and `borrower_phone_number_display` methods to `LoanApplication` model, matching the existing `Loan` pattern: return snapshot value with fallback to live borrower data. This encapsulates fallback logic that is currently inline in the view.
  - [x] 2.2 Update `app/views/loan_applications/show.html.erb` to use the new display helpers instead of the inline fallback `@loan_application.borrower_full_name_snapshot || @loan_application.borrower.full_name` pattern (lines 55 and 60).
  - [x] 2.3 Add model spec for the display helpers: returns snapshot when present, falls back to live borrower when snapshot is nil.

- [x] Task 3: Add snapshot immutability guard on LoanApplication (AC: #1)
  - [x] 3.1 Add a validation on `LoanApplication` that prevents `borrower_full_name_snapshot` and `borrower_phone_number_snapshot` from being changed after initial creation. Use `on: :update` context validation or an `attribute_changed?` guard in a custom validation. This mirrors the architectural intent: "later borrower edits do not rewrite historical decision context."
  - [x] 3.2 Add model spec verifying that attempting to update snapshot fields on a persisted LoanApplication is rejected.

- [x] Task 4: Add snapshot immutability guard on Loan (AC: #1)
  - [x] 4.1 Add the same snapshot immutability validation on `Loan` — prevent changes to `borrower_full_name_snapshot` and `borrower_phone_number_snapshot` after creation.
  - [x] 4.2 Add model spec verifying that updating snapshot fields on a persisted Loan is rejected.

- [x] Task 5: Verify loan snapshot uses application-time borrower data, not live (AC: #1)
  - [x] 5.1 Add a service spec in `spec/services/loans/create_from_application_spec.rb` that verifies: when a borrower's name is updated after application creation, the new loan's `borrower_full_name_snapshot` still uses the borrower's current name at loan-creation time (not the application snapshot, since the borrower may have been corrected). The current implementation in `Loans::CreateFromApplication` uses `loan_application.borrower.full_name`, which is correct — the spec documents this intentional behavior.
  - [x] 5.2 Add a service spec in `spec/services/loan_applications/create_spec.rb` that verifies: the application's `borrower_full_name_snapshot` captures the borrower's `full_name` at creation time, and later changes to the borrower do not affect the stored snapshot.

- [x] Task 6: Add snapshot visibility indicators in detail views (AC: #3)
  - [x] 6.1 In `app/views/loan_applications/show.html.erb`, add a visual indicator when the borrower snapshot differs from the current live borrower data. Show a small informational note like "Borrower name was [snapshot] at application time" alongside "Current borrower: [live name]" when they differ. This helps the admin understand that decision context is preserved even if the borrower record was later updated.
  - [x] 6.2 In `app/views/loans/show.html.erb`, add the same snapshot divergence indicator. When `@loan.borrower_full_name_snapshot != @loan.borrower.full_name` or phone differs, show both the snapshot and current values clearly.

- [x] Task 7: Add derived state consistency verification specs (AC: #2)
  - [x] 7.1 Add spec in `spec/services/loans/refresh_status_spec.rb` (or a new dedicated spec file `spec/services/loans/derived_state_integrity_spec.rb`) that exercises a full lifecycle scenario: create loan → disburse → generate payments → some payments go overdue → verify loan status is derived correctly → mark all payments completed → verify loan closes automatically. This documents the derived-state contract end-to-end.
  - [x] 7.2 Add spec verifying that dashboard queries (`Dashboard::ActiveLoansQuery`, `Dashboard::OverduePaymentsQuery`, `Dashboard::PortfolioSummaryQuery`) return counts consistent with the persisted derived states after `Loans::RefreshStatus` runs. This proves the dashboard reflects the same truth as detail pages.

- [x] Task 8: Add derived state explanation to detail views (AC: #2, #3)
  - [x] 8.1 In `app/views/loans/show.html.erb`, when the loan is `overdue` or `closed`, add a brief informational note explaining that this state was derived from payment facts (e.g., "This loan's overdue status was derived from overdue payment conditions" or "This loan was closed automatically when all payments were completed"). Use the blocked-state callout pattern or a simple informational card.
  - [x] 8.2 In `app/views/payments/show.html.erb`, when the payment is `overdue`, add a note explaining the derivation: "This payment was marked overdue because its due date passed without completion."

- [x] Task 9: Comprehensive test coverage (AC: #1, #2, #3)
  - [x] 9.1 Add request spec assertions verifying snapshot values appear on loan application show page.
  - [x] 9.2 Add request spec assertions verifying snapshot values appear on loan show page.
  - [x] 9.3 Add request spec assertion verifying the snapshot divergence indicator appears when borrower data has changed since the snapshot was taken.
  - [x] 9.4 Run `bundle exec rspec` green. Run `bundle exec rubocop` green on all touched files.

### Review Findings

- [x] [Review][Decision] Presence validation not scoped to `on: :create` — resolved: keep unconditional. Borrower details are always present; legacy nil-snapshot records require backfill before any save. Matches pre-existing Loan model pattern.
- [x] [Review][Decision] Divergence indicator requires BOTH snapshots present — dismissed: borrower details are always assumed present, so both snapshots will always exist for valid records. `&&` guard is correct.
- [x] [Review][Patch] `validate` macro placed inside `private` block — fixed: moved to class-level alongside other validations [app/models/loan.rb, app/models/loan_application.rb]
- [x] [Review][Patch] Snapshot divergence view logic duplicated — fixed: extracted to `app/views/application/_snapshot_divergence.html.erb` shared partial [app/views/loan_applications/show.html.erb, app/views/loans/show.html.erb]
- [x] [Review][Patch] Views call borrower methods without safe navigation — fixed: partial uses `record.borrower&.full_name` consistently
- [x] [Review][Patch] No request spec coverage for derived state explanation notes — fixed: added 3 loan request specs (overdue, closed, non-terminal) [spec/requests/loans_spec.rb]
- [x] [Review][Patch] Immutability spec tests both fields simultaneously — fixed: split into per-field specs [spec/models/loan_application_spec.rb, spec/models/loan_spec.rb]
- [x] [Review][Patch] `create_from_application_spec.rb` uses non-E.164 phone — fixed: updated to `"+91 98765 43210"` [spec/services/loans/create_from_application_spec.rb]
- [x] [Review][Patch] `derived_state_integrity_spec.rb` declared `type: :model` — fixed: removed type tag [spec/services/loans/derived_state_integrity_spec.rb]
- [x] [Review][Defer] Immutability guard bypassable via `update_columns`/raw SQL — no DB-level constraint — deferred, pre-existing architectural choice
- [x] [Review][Defer] Display helper fallback silently returns live data when snapshot is nil — consumer cannot distinguish historical from current — deferred, pre-existing pattern from Loan model

## Dev Notes

### Epic 6 Cross-Story Context

- **Epic 6** covers portfolio visibility, search, and trusted record history (FR57–FR70, FR73–FR74).
- **Story 6.1** (done) built the action-first dashboard with triage/summary widgets, query objects, controller, components, and nav bar.
- **Story 6.2** (done) added dashboard drill-in filtered views with multi-status support and filter context banners.
- **Story 6.3** (done) completed cross-entity search and linked-record investigation from detail pages.
- **Story 6.4** (done) added audit history timeline (ActivityTimelineComponent) and deletion protection concern.
- **This story (6.5)** preserves derived-state integrity and historical borrower snapshots — the final story in Epic 6.

### Functional Requirements Covered

- **FR73:** System can keep financially significant lifecycle states derived from recorded facts rather than manual state toggles.
- **FR74:** System can snapshot borrower data onto applications and loans for historical integrity.

### What Already Exists (DO NOT Recreate)

**Borrower snapshots are already implemented as string columns:**
- `loan_applications` table: `borrower_full_name_snapshot`, `borrower_phone_number_snapshot` columns exist (nullable in schema).
- `loans` table: same two columns exist. `Loan` validates presence; `LoanApplication` does NOT — **this is the primary gap**.
- `LoanApplications::Create` service sets snapshots at creation: `borrower.full_name` and `borrower.phone_number_normalized`.
- `Loans::CreateFromApplication` service sets snapshots from **live borrower** at loan-creation time: `loan_application.borrower.full_name` and `loan_application.borrower.phone_number_normalized`.

**Display helpers — Loan has them, LoanApplication does NOT:**
- `Loan#borrower_full_name_display` returns `borrower_full_name_snapshot.presence || borrower&.full_name`
- `Loan#borrower_phone_number_display` returns `borrower_phone_number_snapshot.presence || borrower&.phone_number_normalized`
- `LoanApplication` has NO equivalent helpers — views use inline fallback `@loan_application.borrower_full_name_snapshot || @loan_application.borrower.full_name`

**Snapshot display in views:**
- `loan_applications/show.html.erb` lines 54-61: displays "Borrower snapshot" and "Snapshot phone number" fields with inline fallback
- `loans/show.html.erb` lines 62-69: displays "Borrower snapshot" and "Snapshot phone number" fields using `borrower_full_name_display` / `borrower_phone_number_display`

**NO BorrowerSnapshot model exists — snapshots are flat columns, not a separate model. Do NOT create one.**

**NO `snapshot_for_lending.rb` service exists in `app/` — it was only planned in architecture. Do NOT create one — the snapshotting logic is simple enough inline in the Create services.**

**Derived state logic is already fully implemented:**
- `Loans::RefreshStatus` — orchestrates overdue marking, late fees, loan closure, and resolve-overdue transitions
- `Payments::MarkOverdue` — marks individual payments overdue when `due_date < today`
- `Payments::DeriveOverdueStates` — batch sweep across all loans with pending past-due payments
- `Payments::ApplyLateFee` — applies flat late fee to overdue payments
- `Loan` AASM states: created → documentation_in_progress → ready_for_disbursement → active → overdue → closed (with resolve_overdue: overdue → active)
- `Payment` AASM states: pending → completed, pending → overdue

**Derivation triggers (inline on read, NOT background jobs):**
- `LoansController#show` calls `Loans::RefreshStatus.call(loan: @loan)`
- `PaymentsController#index` calls `Payments::DeriveOverdueStates.call`
- `PaymentsController#show` and `#mark_completed` also refresh loan status
- **No background jobs exist** — architecture planned them but they were not implemented. Overdue derivation is inline-on-read per Story 5.5 design decision.

**Dashboard queries count persisted statuses (NOT re-derived):**
- `Dashboard::ActiveLoansQuery` — `Loan.where(status: %w[active overdue]).count`
- `Dashboard::OverduePaymentsQuery` — `Payment.where(status: "overdue").count`
- `Dashboard::PortfolioSummaryQuery` — `Loan.where(status: "closed").count` + invoice sums
- These are only as fresh as the last persistence of derived state via `RefreshStatus`.

**Borrower model fields:**
- `full_name` (string, validated present)
- `phone_number` (string, validated present)
- `phone_number_normalized` (string, computed via `before_validation`)
- No `first_name` / `last_name` columns

### Critical Architecture Constraints

- **No new gems or migrations.** Snapshot columns already exist. Derived state services already exist.
- **No new controllers, routes, or query objects.**
- **No BorrowerSnapshot model.** Snapshots remain flat columns on `loan_applications` and `loans`.
- **No background jobs.** Derived state remains inline-on-read per existing design.
- **No new ViewComponents.** Use existing card/section patterns and informational callouts.
- **Controllers remain thin.** No controller changes needed — all work is model validation, view updates, and tests.

### Existing Patterns to Follow

1. **Snapshot validation pattern (Loan):**
   ```ruby
   validates :borrower_full_name_snapshot, presence: true
   validates :borrower_phone_number_snapshot, presence: true
   ```

2. **Display helper pattern (Loan):**
   ```ruby
   def borrower_full_name_display
     borrower_full_name_snapshot.presence || borrower&.full_name
   end
   ```

3. **Immutability guard pattern** — Use a custom validation:
   ```ruby
   validate :snapshot_fields_immutable, on: :update

   def snapshot_fields_immutable
     if borrower_full_name_snapshot_changed?
       errors.add(:borrower_full_name_snapshot, "cannot be changed after creation")
     end
     if borrower_phone_number_snapshot_changed?
       errors.add(:borrower_phone_number_snapshot, "cannot be changed after creation")
     end
   end
   ```

4. **Informational note pattern in views** — Use the existing card styling:
   ```erb
   <div class="mt-4 rounded-2xl border border-blue-200 bg-blue-50 px-5 py-4">
     <p class="text-sm font-semibold text-blue-900">Borrower details have changed since this record was created.</p>
     <p class="mt-2 text-sm leading-6 text-blue-800">
       The snapshot preserves the borrower context that existed at decision time.
     </p>
   </div>
   ```

5. **Detail page section styling** — `rounded-2xl border border-slate-200 bg-slate-50 p-6` for inner cards within `rounded-3xl border border-slate-200 bg-white p-8 shadow-sm sm:p-10` outer sections.

6. **Request spec auth pattern** — Use `sign_in_as` helper or `post session_path` (inconsistently used across specs — follow the pattern in the specific spec file being modified).

7. **Model spec pattern** — Use FactoryBot factories. Loan factory: `:loan` with traits like `:active`, `:with_details`. LoanApplication factory: `:loan_application`.

### Files to Create

| Area | File | Purpose |
|------|------|---------|
| Spec | `spec/services/loans/derived_state_integrity_spec.rb` | End-to-end derived state lifecycle verification |

### Files to Modify

| Area | File | Changes |
|------|------|---------|
| Model | `app/models/loan_application.rb` | Add snapshot presence validations, display helpers, snapshot immutability guard |
| Model | `app/models/loan.rb` | Add snapshot immutability guard |
| View | `app/views/loan_applications/show.html.erb` | Use display helpers, add snapshot divergence indicator |
| View | `app/views/loans/show.html.erb` | Add snapshot divergence indicator, add derived-state explanation note |
| View | `app/views/payments/show.html.erb` | Add derived-state explanation note for overdue payments |
| Spec | `spec/models/loan_application_spec.rb` | Snapshot presence validation, display helpers, immutability guard |
| Spec | `spec/models/loan_spec.rb` | Snapshot immutability guard |
| Spec | `spec/services/loans/create_from_application_spec.rb` | Snapshot captures borrower data at loan-creation time |
| Spec | `spec/services/loan_applications/create_spec.rb` | Snapshot captures borrower data at application-creation time |
| Spec | `spec/requests/loan_applications_spec.rb` | Snapshot display and divergence indicator assertions |
| Spec | `spec/requests/loans_spec.rb` | Snapshot display and divergence indicator assertions |

### Files NOT to Create or Modify

- Do NOT create `app/models/borrower_snapshot.rb` — snapshots are flat columns, not a separate model.
- Do NOT create `app/services/borrowers/snapshot_for_lending.rb` — inline snapshot assignment in Create services is sufficient.
- Do NOT create background jobs for overdue derivation — inline-on-read is the current design.
- Do NOT modify `Loans::RefreshStatus`, `Payments::MarkOverdue`, `Payments::DeriveOverdueStates`, or `Payments::ApplyLateFee` — these services are working correctly.
- Do NOT modify `ApplicationController` — no controller-level changes needed.
- Do NOT modify dashboard queries or views — they already count persisted derived statuses.
- Do NOT modify the existing snapshot assignment in `LoanApplications::Create` or `Loans::CreateFromApplication` — these are correct.
- Do NOT create new migrations — schema already has all needed columns.

### Derived State Derivation Points (Reference)

| State | Derived From | Where |
|-------|-------------|-------|
| Payment overdue | `due_date < today` and `status == "pending"` | `Payments::MarkOverdue` |
| Loan overdue | Any payment is `overdue` | `Loans::RefreshStatus` → `loan.mark_overdue!` |
| Loan closed | All payments `completed` | `Loans::RefreshStatus` → `loan.close!` |
| Loan resolve_overdue | No more overdue or past-due-pending payments | `Loans::RefreshStatus` → `loan.resolve_overdue!` |
| Late fee | Overdue payment with `late_fee_cents == 0` | `Payments::ApplyLateFee` (called from `Loans::RefreshStatus`) |

### Edge Cases

1. **Borrower edited after application/loan creation:** Snapshot should preserve original values. New display helpers fall back to live borrower only when snapshot is nil (legacy data). Immutability guard prevents accidental overwrite.
2. **LoanApplication created before presence validation was added:** Existing applications may have nil snapshots. Display helpers handle this with fallback to live borrower. Presence validation only applies to new records going forward — use `on: :create` context if needed to avoid breaking existing records on update.
3. **Snapshot same as current borrower:** When snapshot matches live borrower, no divergence indicator is shown. Only show the note when values differ.
4. **Loan display helpers already exist:** Do NOT duplicate or change `Loan#borrower_full_name_display` and `#borrower_phone_number_display` — they already work correctly with snapshot + fallback.
5. **Immutability guard and FactoryBot:** Ensure factories do not try to update snapshot fields on persisted records. The guard should not interfere with initial creation.
6. **LoanApplication presence validation and existing tests:** Adding `validates :borrower_full_name_snapshot, presence: true` might break tests that create LoanApplications without snapshots. Check all factories and test setups. The `LoanApplications::Create` service always sets them, but direct `create(:loan_application)` via FactoryBot might not. Update the `:loan_application` factory to include snapshot values if needed.

### Deferred Work from Previous Stories (Relevant Context)

From `deferred-work.md`:
- GET requests mutate DB via inline derivation (Story 5.5 design decision — not changed in this story).
- `DeriveOverdueStates` scope gaps (pending-only discovery misses some late-fee paths) — not changed in this story.
- PaperTrail whodunnit attributes automated derivations to request user — not changed in this story.
- Dashboard freshness depends on when `RefreshStatus` last ran — not changed in this story.

### UX Requirements

- **Snapshot divergence indicator:** Informational, not alarming. Use blue/neutral tones, not warning colors. The message should build trust: "The system preserved the context that existed at decision time."
- **Derived state explanation:** Brief, factual notes on detail pages when loan is overdue or closed. Not a modal or alert — just an informational card.
- **Desktop-first:** No mobile layout considerations.
- **WCAG 2.1 Level A:** Informational notes should use semantic HTML. Screen reader context should make snapshot vs current data distinction clear.

### Library / Framework Requirements

- **No new gems, no new migrations, no new initializers.**
- PaperTrail ~> 17.0 (already installed)
- ViewComponent (already used — no new components needed)
- AASM (already used for Loan/Payment state machines)

### Previous Story Intelligence (6.4)

- Story 6.4 added `DeletionProtection` concern, `ActivityTimelineComponent`, and `has_paper_trail` to Borrower.
- Story 6.4 changed `LoanApplication#review_steps` from `dependent: :destroy` to `dependent: :restrict_with_exception`.
- Story 6.4 confirmed all 668 examples pass with 97.11% line coverage.
- Story 6.4 review deferred: `DeletionProtection` doesn't guard `delete`/`delete_all` (callback bypass) — not relevant here.
- Story 6.4 review fixed: N+1 in `ActivityTimelineComponent` (batch user lookup), double-wrapped sections, redundant view guards.

### Git Intelligence

Recent commits:
- `3f40fcb` **Add audit history timeline and deletion protection for operational records.** (Story 6.4)
- `efa2174` **Add cross-entity phone search and linked-record investigation.** (Story 6.3)
- `0ef8ffe` **Add dashboard drill-in filtered views with multi-status support and filter context.** (Story 6.2)
- `ff3b07d` **Add action-first operational dashboard.** (Story 6.1)

Preferred commit style: `"Preserve derived-state integrity and add borrower snapshot guarantees."`

### Non-Goals (Explicit Scope Boundaries)

- **No BorrowerSnapshot model.** Flat columns are the chosen approach.
- **No background overdue derivation jobs.** Inline-on-read remains the design.
- **No dashboard query changes.** Dashboard freshness is a known pre-existing gap.
- **No changes to derived state services.** `RefreshStatus`, `MarkOverdue`, `DeriveOverdueStates`, `ApplyLateFee` are working correctly.
- **No centralized snapshot migration.** Snapshot columns already exist.
- **No snapshot expansion** — only `full_name` and `phone_number_normalized` are snapshotted per the architecture. No additional borrower fields.
- **No snapshot versioning** — snapshots are point-in-time captures, not a version history. PaperTrail already tracks model changes for audit.

### Project Structure Notes

- New spec file at `spec/services/loans/derived_state_integrity_spec.rb` follows existing `spec/services/loans/` directory.
- No new directories created.
- All modifications follow existing file structure and naming conventions.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md:981-1002` — Story 6.5 acceptance criteria]
- [Source: `_bmad-output/planning-artifacts/architecture.md:76-78` — Borrower data snapshotted onto applications and loans, post-disbursement non-editable]
- [Source: `_bmad-output/planning-artifacts/architecture.md:88-89` — Financial correctness, immutable history, record locking]
- [Source: `_bmad-output/planning-artifacts/architecture.md:97` — Consistent page-load freshness and state derivation without realtime infrastructure]
- [Source: `_bmad-output/planning-artifacts/prd.md:FR73` — Derived lifecycle states from recorded facts]
- [Source: `_bmad-output/planning-artifacts/prd.md:FR74` — Borrower snapshotting onto applications and loans]
- [Source: `app/services/loan_applications/create.rb:48-49` — Snapshot assignment at application creation]
- [Source: `app/services/loans/create_from_application.rb:43-44` — Snapshot assignment at loan creation]
- [Source: `app/models/loan.rb:33-35` — Snapshot presence validations on Loan]
- [Source: `app/models/loan.rb:121-127` — Display helper pattern with fallback]
- [Source: `app/services/loans/refresh_status.rb` — Central derived state orchestration]
- [Source: `app/services/payments/mark_overdue.rb` — Payment overdue derivation]
- [Source: `app/services/payments/derive_overdue_states.rb` — Batch overdue sweep]
- [Source: `app/views/loan_applications/show.html.erb:54-61` — Current inline snapshot display]
- [Source: `app/views/loans/show.html.erb:62-69` — Current snapshot display with helpers]
- [Source: `_bmad-output/implementation-artifacts/6-4-record-audit-history-and-protect-operational-records.md` — Previous story context]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` — Known deferred items]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — all tasks completed without debug halts.

### Completion Notes List

- ✅ Task 1: Added `validates :borrower_full_name_snapshot, presence: true` and `validates :borrower_phone_number_snapshot, presence: true` to LoanApplication. Fixed 2 pre-existing specs that created LoanApplications without snapshots (direct `create!` bypassing factory).
- ✅ Task 2: Added `borrower_full_name_display` and `borrower_phone_number_display` methods to LoanApplication matching the Loan pattern. Updated view to use helpers instead of inline fallback.
- ✅ Task 3: Added `snapshot_fields_immutable` custom validation on LoanApplication (`on: :update`) that rejects changes to snapshot fields after creation.
- ✅ Task 4: Added the same `snapshot_fields_immutable` validation on Loan model.
- ✅ Task 5: Added service spec documenting that loan snapshot captures borrower's current name at loan-creation time (not application snapshot). Added spec confirming application snapshot is immutable after borrower changes.
- ✅ Task 6: Added blue informational snapshot divergence indicators on both loan application and loan detail views. Shows both snapshot and current values when they differ.
- ✅ Task 7: Created `spec/services/loans/derived_state_integrity_spec.rb` with full lifecycle spec (active → overdue → resolved → closed) and dashboard query consistency spec.
- ✅ Task 8: Added derived state explanation notes on loans/show (overdue/closed) and payments/show (overdue) using informational card pattern.
- ✅ Task 9: Added 6 request spec assertions (3 for loan applications, 3 for loans) covering snapshot display and divergence indicators. Full suite: 685 examples, 0 failures, 97.14% line coverage, 84.01% branch coverage. Rubocop: 0 offenses.

### Change Log

- 2026-04-19: Story 6.5 implementation complete — snapshot integrity, immutability guards, display helpers, divergence indicators, derived-state explanations, and comprehensive test coverage.

### File List

- app/models/loan_application.rb (modified: added snapshot presence validations, display helpers, immutability guard)
- app/models/loan.rb (modified: added snapshot immutability guard)
- app/views/loan_applications/show.html.erb (modified: use display helpers, add snapshot divergence indicator)
- app/views/loans/show.html.erb (modified: add snapshot divergence indicator, add derived-state explanation)
- app/views/payments/show.html.erb (modified: add derived-state explanation for overdue payments)
- spec/models/loan_application_spec.rb (modified: snapshot presence, immutability, display helper specs)
- spec/models/loan_spec.rb (modified: snapshot immutability specs)
- spec/services/loans/create_from_application_spec.rb (modified: snapshot-at-creation-time spec)
- spec/services/loan_applications/create_spec.rb (modified: snapshot immutability-after-creation spec)
- spec/services/loans/derived_state_integrity_spec.rb (created: full lifecycle and dashboard consistency specs)
- spec/requests/loan_applications_spec.rb (modified: snapshot display and divergence indicator assertions)
- spec/requests/loans_spec.rb (modified: snapshot display and divergence indicator assertions)
