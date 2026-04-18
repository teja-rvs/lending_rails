# Story 6.4: Record Audit History and Protect Operational Records

Status: done

## Story

As an admin operator,
I want key operational actions recorded and protected from destructive loss,
So that I can trust the system as a historical source of truth.

## Acceptance Criteria

1. **Given** the admin performs a key operational or financial action
   **When** the system records that event
   **Then** it creates an audit trail entry or version history as appropriate
   **And** the trail includes who performed the action and when it occurred

2. **Given** the admin is reviewing a record with meaningful history
   **When** they inspect the available audit context
   **Then** they can see the relevant historical events in a readable way
   **And** the activity or timeline presentation supports operational review

3. **Given** an operator attempts to remove critical historical data
   **When** they try to hard-delete an operational or financial record
   **Then** the system prevents hard deletion
   **And** the record remains available as part of the searchable system history

## Tasks / Subtasks

- [x] Task 1: Add `has_paper_trail` to Borrower model (AC: #1)
  - [x] 1.1 Add `has_paper_trail` to `app/models/borrower.rb`. Every other domain model already has it; Borrower is the sole gap. FR68 lists "borrower creation" as an auditable action.
  - [x] 1.2 Add spec in `spec/models/borrower_spec.rb`: verify `Borrower.new.respond_to?(:versions)` and that creating a borrower produces a PaperTrail version with `event: "create"`.

- [x] Task 2: Add deletion protection concern to ApplicationRecord (AC: #3)
  - [x] 2.1 Create `app/models/concerns/deletion_protection.rb` with a concern that raises `ActiveRecord::ReadOnlyRecord` (or a custom `DeletionProtectedError < StandardError`) in a `before_destroy` callback. The concern should be includable by any model that needs protection.
  - [x] 2.2 Include the concern in all operational/financial models: `Borrower`, `LoanApplication`, `Loan`, `Payment`, `Invoice`, `ReviewStep`, `DocumentUpload`. Session and User are excluded — sessions must be destroyable for logout, and user management may need deletion in future.
  - [x] 2.3 Add spec `spec/models/concerns/deletion_protection_spec.rb` testing that a protected model raises an error on `destroy` and `destroy!`, and that the record persists after the failed attempt.
  - [x] 2.4 Add individual model specs (one assertion per model) confirming that each protected model cannot be destroyed. Use shared examples: `it_behaves_like "deletion protected"`.
  - [x] 2.5 **CRITICAL:** Update the `LoanApplication` model — `review_steps` currently uses `dependent: :destroy`. Change to `dependent: :restrict_with_exception` since ReviewStep will now be deletion-protected. The deletion protection concern on ReviewStep would conflict with `dependent: :destroy` on the parent. Similarly verify all `dependent:` declarations on protected models are `:restrict_with_exception` or `:nullify`, never `:destroy`.

- [x] Task 3: Add version history / activity timeline to loan detail page (AC: #2)
  - [x] 3.1 Create a `Shared::ActivityTimelineComponent` ViewComponent at `app/components/shared/activity_timeline_component.rb` and `app/components/shared/activity_timeline_component.html.erb`. The component accepts a collection of version records and renders them as a vertical timeline. Each entry shows: event label (create/update mapped to human text), timestamp, actor (resolve `whodunnit` to `User#email_address`, fallback to "System"), and changed fields summary (from `object_changes` or `object` diff if available, otherwise just event type).
  - [x] 3.2 UX pattern per the UX spec "Activity / Timeline Block": event label, timestamp, actor, optional note. States: system event vs user action. Use the compact history list variant. Styling: use the existing `rounded-2xl border border-slate-200 bg-slate-50 p-6` card pattern. Each timeline entry uses a left-border accent or dot indicator.
  - [x] 3.3 Add the timeline to `app/views/loans/show.html.erb` — render `Shared::ActivityTimelineComponent.new(versions: @loan.versions.order(created_at: :desc))` in a new "Record history" section after the existing content. Only render the section if `@loan.versions.any?`.
  - [x] 3.4 Add spec `spec/components/shared/activity_timeline_component_spec.rb` testing: renders event labels, timestamps, actor emails, handles missing whodunnit gracefully, handles empty versions (renders nothing or empty state).

- [x] Task 4: Add version history to loan application detail page (AC: #2)
  - [x] 4.1 Add the same `Shared::ActivityTimelineComponent` to `app/views/loan_applications/show.html.erb` — render `Shared::ActivityTimelineComponent.new(versions: @loan_application.versions.order(created_at: :desc))` in a "Record history" section. Only render if versions exist.
  - [x] 4.2 Add request spec assertions in `spec/requests/loan_applications_spec.rb` for the show action verifying the "Record history" section renders when versions exist.

- [x] Task 5: Add version history to payment detail page (AC: #2)
  - [x] 5.1 Add `Shared::ActivityTimelineComponent` to `app/views/payments/show.html.erb` — render version history in a "Record history" section. Only render if versions exist.
  - [x] 5.2 Add request spec assertion in `spec/requests/payments_spec.rb` for the show action verifying "Record history" renders.

- [x] Task 6: Add version history to borrower detail page (AC: #2)
  - [x] 6.1 Add `Shared::ActivityTimelineComponent` to `app/views/borrowers/show.html.erb` — render version history. Only render if versions exist.
  - [x] 6.2 Add request spec assertion in `spec/requests/borrowers_spec.rb` for the show action.

- [x] Task 7: Comprehensive test coverage (AC: #1, #2, #3)
  - [x] 7.1 Verify all existing PaperTrail whodunnit tests still pass (they already exist in `spec/requests/payments_spec.rb` and `spec/services/`).
  - [x] 7.2 Add a request spec for loan show verifying "Record history" section renders with version entries and actor information.
  - [x] 7.3 Run `bundle exec rspec` green. Run `bundle exec rubocop` green on all touched files.

## Dev Notes

### Epic 6 Cross-Story Context

- **Epic 6** covers portfolio visibility, search, and trusted record history (FR57–FR70, FR73–FR74).
- **Story 6.1** (done) built the action-first dashboard with triage/summary widgets, query objects, controller, components, and nav bar.
- **Story 6.2** (done) added dashboard drill-in filtered views with multi-status support and filter context banners.
- **Story 6.3** (done) completed cross-entity search and linked-record investigation from detail pages.
- **This story (6.4)** adds audit history visibility on detail pages and deletion protection for operational records.
- **Story 6.5** will add derived-state integrity and historical snapshots.

### Functional Requirements Covered

- **FR68:** System can preserve an audit trail for borrower creation, application updates, approval and rejection decisions, disbursement, payment completion, overdue marking, late-fee application, and loan closure.
- **FR69:** System can record who performed each auditable action and when it occurred.
- **FR70:** System can prevent permanent removal of operational and financial records.

### What Already Exists (DO NOT Recreate)

**PaperTrail is already installed and integrated:**
- Gem: `paper_trail ~> 17.0` in Gemfile
- Initializer: `config/initializers/paper_trail.rb` — `PaperTrail.config.enabled = true`
- `versions` table exists in `db/schema.rb` with `item_type`, `item_id`, `event`, `object`, `whodunnit`, `created_at`
- `ApplicationController` already calls `before_action :set_paper_trail_whodunnit` and defines `user_for_paper_trail` returning `Current.user&.id`

**Models already tracking versions:**
- `LoanApplication` — `has_paper_trail`
- `Loan` — `has_paper_trail`
- `Payment` — `has_paper_trail`
- `Invoice` — `has_paper_trail`
- `User` — `has_paper_trail skip: [:password_digest]`
- `DocumentUpload` — `has_paper_trail`
- `ReviewStep` — `has_paper_trail`

**Model MISSING version tracking:**
- `Borrower` — NO `has_paper_trail` (this is the only gap)

**Existing version usage in views:**
- `app/views/payments/show.html.erb` line 118 already queries `@payment.versions.where(event: "update").last` to display "Completed by" actor. This proves the pattern works.

**Existing deletion protection (partial):**
- `ApplicationPolicy#destroy?` returns `false` — Pundit blocks destroy actions at the controller level.
- Routes only define limited actions (no `:destroy` routes for any domain resource).
- `dependent: :restrict_with_exception` on Loan → payments, Loan → invoices, Loan → document_uploads, Borrower → loans, Borrower → loan_applications prevents cascade deletes.
- **GAP:** `LoanApplication` has `dependent: :destroy` on `review_steps` — this MUST be changed.
- **GAP:** No model-level callback prevents `Model.find(id).destroy` from the console or a service. FR70 requires model-level protection, not just route/policy-level.

**Existing whodunnit pattern:**
- `ApplicationController#user_for_paper_trail` returns `Current.user&.id`
- Tests verify whodunnit: `spec/requests/payments_spec.rb` lines 425-452, `spec/services/payments/mark_overdue_spec.rb`, `spec/services/payments/mark_completed_spec.rb`, `spec/services/payments/apply_late_fee_spec.rb`

### Critical Architecture Constraints

- **No new gems.** PaperTrail is already installed. No audit gem additions.
- **No new migrations.** The `versions` table is already complete with all required columns. Adding `has_paper_trail` to Borrower will use the existing table.
- **One new ViewComponent.** `Shared::ActivityTimelineComponent` for the reusable activity timeline. This follows the project's ViewComponent pattern (see `app/components/shared/status_badge_component.rb`, `app/components/dashboard/`).
- **One new concern.** `DeletionProtection` for model-level destroy prevention.
- **No new controllers, routes, or query objects.**
- **Controllers remain thin.** No controller changes needed — `@loan.versions` is accessed directly in views.
- **No new initializers.** PaperTrail initializer already exists.

### Existing Patterns to Follow

1. **ViewComponent pattern** — See `app/components/shared/status_badge_component.rb` for the naming and structure convention. Components live in `app/components/<namespace>/`, with matching `.html.erb` template. Specs live in `spec/components/<namespace>/`.

2. **Version query pattern** — See `app/views/payments/show.html.erb` line 118:
   ```ruby
   last_version = @payment.versions.where(event: "update").last
   whodunnit = last_version&.whodunnit
   completed_by_user = whodunnit.present? ? User.find_by(id: whodunnit) : nil
   ```
   The `ActivityTimelineComponent` should encapsulate this whodunnit-to-email resolution internally, not push it to views.

3. **Card/section styling** — Use `rounded-2xl border border-slate-200 bg-slate-50 p-6` for the timeline container, matching the existing detail page section cards (see loan show, payment show).

4. **Detail page section placement** — New sections go after existing content, before the "Dev Agent Record" footer. The "Record history" section should be a final operational section on each detail page.

5. **Concern pattern** — No existing concerns in `app/models/concerns/` yet, but the Rails convention is: module in `app/models/concerns/`, included via `include ConcernName` in the model. Use `ActiveSupport::Concern` with `included` block.

6. **Shared examples pattern** — If shared examples don't exist yet, create `spec/support/shared_examples/deletion_protection.rb` with `RSpec.shared_examples "deletion protected"`.

7. **Request spec pattern** — See `spec/requests/loans_spec.rb`, `spec/requests/payments_spec.rb`: use `sign_in_as` helper or `post session_path` for authentication, `assert_select` for HTML assertions.

### Files to Create

| Area | File | Purpose |
|------|------|---------|
| Concern | `app/models/concerns/deletion_protection.rb` | Model-level destroy prevention |
| Component | `app/components/shared/activity_timeline_component.rb` | Activity timeline ViewComponent |
| Component | `app/components/shared/activity_timeline_component.html.erb` | Activity timeline template |
| Spec | `spec/components/shared/activity_timeline_component_spec.rb` | Component tests |
| Spec | `spec/models/concerns/deletion_protection_spec.rb` | Concern tests |
| Support | `spec/support/shared_examples/deletion_protection.rb` | Shared example for deletion protection |

### Files to Modify

| Area | File | Changes |
|------|------|---------|
| Model | `app/models/borrower.rb` | Add `has_paper_trail` |
| Model | `app/models/loan_application.rb` | Change `review_steps` dependent from `:destroy` to `:restrict_with_exception`, add `include DeletionProtection` |
| Model | `app/models/borrower.rb` | Add `include DeletionProtection` |
| Model | `app/models/loan.rb` | Add `include DeletionProtection` |
| Model | `app/models/payment.rb` | Add `include DeletionProtection` |
| Model | `app/models/invoice.rb` | Add `include DeletionProtection` |
| Model | `app/models/review_step.rb` | Add `include DeletionProtection` |
| Model | `app/models/document_upload.rb` | Add `include DeletionProtection` |
| View | `app/views/loans/show.html.erb` | Add "Record history" section with ActivityTimelineComponent |
| View | `app/views/loan_applications/show.html.erb` | Add "Record history" section with ActivityTimelineComponent |
| View | `app/views/payments/show.html.erb` | Add "Record history" section with ActivityTimelineComponent |
| View | `app/views/borrowers/show.html.erb` | Add "Record history" section with ActivityTimelineComponent |
| Spec | `spec/models/borrower_spec.rb` | Add PaperTrail version tracking test |
| Spec | `spec/requests/loans_spec.rb` | Add "Record history" section assertion |
| Spec | `spec/requests/loan_applications_spec.rb` | Add "Record history" section assertion |
| Spec | `spec/requests/payments_spec.rb` | Add "Record history" section assertion |
| Spec | `spec/requests/borrowers_spec.rb` | Add "Record history" section assertion |

### Files NOT to Create or Modify

- Do NOT create a new controller for audit/versions — history renders inline on existing detail pages.
- Do NOT create new routes — no new URL endpoints needed.
- Do NOT create a dedicated audit log index page — FR68/FR69 specify audit trail on record detail, not a centralized log viewer.
- Do NOT modify `ApplicationController` — `set_paper_trail_whodunnit` and `user_for_paper_trail` already work correctly.
- Do NOT modify `config/initializers/paper_trail.rb` — configuration is correct.
- Do NOT modify the `versions` migration or schema — table is complete.
- Do NOT add deletion protection to `Session` — sessions must be destroyable for logout (`sessions_controller.rb#destroy`).
- Do NOT add deletion protection to `User` — user management may need deletion.
- Do NOT modify dashboard views or query objects.
- Do NOT add Turbo Frames or Stimulus for timeline rendering — standard server-rendered HTML.

### ActivityTimelineComponent Design

**Input:** `versions:` — an ActiveRecord relation or array of `PaperTrail::Version` records, ordered by `created_at DESC`.

**Rendering logic per version entry:**
- **Event label:** Map `version.event` → human label: `"create" → "Created"`, `"update" → "Updated"`, `"destroy" → "Deleted"`.
- **Timestamp:** `version.created_at.to_fs(:long)` — matches existing timestamp formatting across the app.
- **Actor:** Resolve `version.whodunnit`:
  - If present and looks like a UUID, find `User.find_by(id: whodunnit)&.email_address`.
  - If user found, display email.
  - If whodunnit present but user not found, display "Unknown user".
  - If whodunnit blank/nil, display "System".
- **Changed fields (optional):** If `version.object_changes` is present (PaperTrail tracks this for `update` events when configured), show a brief summary of changed attributes. If not available, skip — do NOT attempt to diff `object` column manually. Keep this simple for MVP.

**Empty state:** If no versions, do not render the component at all (checked in the view before rendering).

**HTML structure (per UX spec "Activity / Timeline Block"):**
```html
<section class="rounded-2xl border border-slate-200 bg-slate-50 p-6">
  <h2 class="text-lg font-semibold text-slate-800 mb-4">Record history</h2>
  <ol class="relative border-l-2 border-slate-200 ml-3 space-y-6">
    <!-- per entry -->
    <li class="ml-6">
      <span class="absolute -left-2.5 mt-1 h-4 w-4 rounded-full border-2 border-white bg-slate-400"></span>
      <p class="text-sm font-medium text-slate-800">Created</p>
      <p class="text-xs text-slate-500">April 18, 2026 12:00 — admin@example.com</p>
    </li>
  </ol>
</section>
```

### DeletionProtection Concern Design

```ruby
# app/models/concerns/deletion_protection.rb
module DeletionProtection
  extend ActiveSupport::Concern

  included do
    before_destroy :prevent_deletion
  end

  private

  def prevent_deletion
    raise ActiveRecord::ReadOnlyRecord, "#{self.class.name} records cannot be deleted"
  end
end
```

**Why `ActiveRecord::ReadOnlyRecord`:** Consistent with the existing `Payment#readonly?` pattern that raises the same error type for completed payments. Using a standard Rails error means existing rescue handlers and test assertions work without custom error classes.

### dependent: :destroy Audit

Models with `dependent:` declarations that MUST be verified:

| Parent | Association | Current dependent | Required Change |
|--------|-------------|-------------------|-----------------|
| LoanApplication | review_steps | `:destroy` | **CHANGE to `:restrict_with_exception`** |
| Borrower | loan_applications | `:restrict_with_exception` | No change |
| Borrower | loans | `:restrict_with_exception` | No change |
| Loan | document_uploads | `:restrict_with_exception` | No change |
| Loan | invoices | `:restrict_with_exception` | No change |
| Loan | payments | `:restrict_with_exception` | No change |
| Payment | invoice | `:restrict_with_exception` | No change |
| User | sessions | `:destroy` | No change — Session is NOT deletion-protected |

### Deferred Work Already Known

From `deferred-work.md`:
- `Payment#readonly?` blocks UPDATE but not DELETE — this story's `DeletionProtection` concern directly addresses the DELETE gap for all protected models.
- PaperTrail whodunnit attributes automated derivations (overdue marking) to the request user rather than "system". This is a known trade-off — do NOT attempt to fix in this story. The timeline component should display whatever whodunnit is recorded.

### Edge Cases

1. **Versions with nil whodunnit:** Background jobs and system-triggered actions (overdue derivation, late fees) may create versions with `whodunnit: nil`. The timeline must handle this gracefully — display "System" as the actor.
2. **Versions with stale whodunnit:** If a user is deleted in future, `User.find_by(id: whodunnit)` returns nil. Display "Unknown user" in this case.
3. **High version count:** A loan with many status transitions could have dozens of versions. For MVP, render all versions in a simple list. Pagination of versions is out of scope.
4. **Concurrent destroy attempts:** `before_destroy` raising an exception will rollback the transaction. This is the standard Rails behavior for destroy callbacks that raise.
5. **FactoryBot and test setup:** Tests that previously relied on `destroy` for cleanup (e.g., `dependent: :destroy` on review_steps) will need updating. Specifically, any test that creates a LoanApplication and expects its review_steps to cascade-delete must be checked. The `restrict_with_exception` change means you cannot delete a LoanApplication that has review_steps — but the DeletionProtection concern already prevents deleting the LoanApplication itself, so this is consistent.
6. **`object_changes` column:** The `versions` table in the schema does NOT have an `object_changes` column — only `object`. This means PaperTrail's `object_changes` tracking is NOT available. The timeline component should only show event type, timestamp, and actor — not field-level changes. Do NOT add the `object_changes` column in this story.

### UX Requirements

- **Activity/Timeline Block (UX spec):** Event label, timestamp, actor, optional note. Compact history list variant. Primarily informational in MVP.
- **Desktop-first:** No mobile layout considerations.
- **WCAG 2.1 Level A:** Timeline entries should use semantic HTML (`<ol>`, `<li>`). Timestamps should be in a parseable format. Actor names should be readable.
- **Visual consistency:** Use the same card styling as other detail page sections (`rounded-2xl border border-slate-200`).

### Library / Framework Requirements

- **PaperTrail ~> 17.0** — already installed, initialized, and integrated across models/controllers.
- **ViewComponent** — already used in the project (`app/components/shared/`, `app/components/dashboard/`).
- **No new gems, no new migrations, no new initializers.**

### Previous Story Intelligence (6.3)

- Story 6.3 added cross-entity phone search and linked-record navigation. No patterns relevant to audit/deletion, but reinforced:
  - Request spec patterns: `sign_in_as` or `post session_path`, `assert_select` for HTML assertions.
  - All 628+ tests pass. New tests must not break existing ones.
  - Rubocop clean on all Ruby files.
- Story 6.3 review deferred items: phone_number_normalized index, duplicated search SQL, test setup duplication — not relevant to this story.

### Git Intelligence

Recent commits:
- `efa2174` **Add cross-entity phone search and linked-record investigation.** (Story 6.3) — linked record patterns.
- `0ef8ffe` **Add dashboard drill-in filtered views with multi-status support.** (Story 6.2)
- `ff3b07d` **Add action-first operational dashboard.** (Story 6.1)

**Preferred commit style:** `"Add audit history timeline and deletion protection for operational records."`

### Non-Goals (Explicit Scope Boundaries)

- **No centralized audit log page.** Audit history renders inline on existing detail pages.
- **No field-level change tracking display.** The `versions` table lacks `object_changes` column. Only event type, timestamp, and actor are shown.
- **No audit search or filtering.** Timeline is a simple chronological list.
- **No audit export.** No CSV or PDF export of audit data.
- **No real-time audit updates.** Standard page-load refresh.
- **No soft-delete pattern.** Records are protected from deletion entirely (hard-block), not soft-deleted.
- **No `object_changes` migration.** Do not add the column — MVP shows event metadata only.
- **No Turbo Frames for timeline.** Standard server-rendered HTML in page.
- **No system actor tracking fix.** The known whodunnit-on-read-derived-changes issue is pre-existing and deferred.

### Project Structure Notes

- New concern at `app/models/concerns/deletion_protection.rb` follows Rails convention.
- New ViewComponent at `app/components/shared/activity_timeline_component.rb` follows existing `app/components/shared/` namespace.
- Shared examples at `spec/support/shared_examples/deletion_protection.rb` follows RSpec convention.
- No new directories created — all paths follow existing structure.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md:958-979` — Story 6.4 acceptance criteria]
- [Source: `_bmad-output/planning-artifacts/prd.md:512-514` — FR68: Audit trail, FR69: Actor/timestamp, FR70: No hard deletion]
- [Source: `_bmad-output/planning-artifacts/architecture.md:80-81` — No hard deletion, audit trail requirements]
- [Source: `_bmad-output/planning-artifacts/architecture.md:90-91` — Immutable history, auditability cross-cutting concerns]
- [Source: `_bmad-output/planning-artifacts/architecture.md:263` — Audit trail for key operational and financial actions]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md:611-619` — Activity/Timeline Block specification]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md:647` — Phase 2 component: activity/timeline block]
- [Source: `app/controllers/application_controller.rb:5,31-32` — PaperTrail whodunnit setup]
- [Source: `app/views/payments/show.html.erb:118-122` — Existing version query pattern for whodunnit resolution]
- [Source: `app/policies/application_policy.rb:35-36` — destroy? returns false by default]
- [Source: `app/models/loan_application.rb:26` — review_steps dependent: :destroy (must change)]
- [Source: `db/schema.rb:228-236` — versions table schema]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:11` — Payment#readonly? blocks UPDATE but not DELETE]
- [Source: `_bmad-output/implementation-artifacts/6-3-search-and-investigate-across-linked-lending-records.md` — Previous story patterns and learnings]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Existing Payment spec expected `ActiveRecord::DeleteRestrictionError` on destroy but DeletionProtection concern's `before_destroy` callback fires first, raising `ActiveRecord::ReadOnlyRecord`. Updated the test to expect the new (correct) error — deletion protection is the primary safeguard now.

### Completion Notes List

- **Task 1:** Added `has_paper_trail` to Borrower model, closing the only audit trail gap. Spec confirms `versions` association and create event tracking.
- **Task 2:** Created `DeletionProtection` concern with `before_destroy` callback raising `ActiveRecord::ReadOnlyRecord`. Included in 7 models (Borrower, LoanApplication, Loan, Payment, Invoice, ReviewStep, DocumentUpload). Changed `LoanApplication#review_steps` from `dependent: :destroy` to `dependent: :restrict_with_exception`. Created shared examples and individual model specs (21 new deletion protection assertions). Updated existing Payment spec.
- **Task 3:** Created `Shared::ActivityTimelineComponent` ViewComponent with event labels (Created/Updated/Deleted), whodunnit-to-email resolution (with System/Unknown user fallbacks), and timestamp display. Added to loans/show.html.erb. 8 component specs cover all rendering paths.
- **Task 4:** Added ActivityTimelineComponent to loan_applications/show.html.erb with request spec assertion.
- **Task 5:** Added ActivityTimelineComponent to payments/show.html.erb with request spec assertion.
- **Task 6:** Added ActivityTimelineComponent to borrowers/show.html.erb with request spec assertion.
- **Task 7:** Full suite: 668 examples, 0 failures, 97.11% line coverage, 84.09% branch coverage. Rubocop clean on all 23 touched files.

### File List

**New files:**
- `app/models/concerns/deletion_protection.rb`
- `app/components/shared/activity_timeline_component.rb`
- `app/components/shared/activity_timeline_component.html.erb`
- `spec/models/concerns/deletion_protection_spec.rb`
- `spec/support/shared_examples/deletion_protection.rb`
- `spec/components/shared/activity_timeline_component_spec.rb`

**Modified files:**
- `app/models/borrower.rb` — added `include DeletionProtection`, `has_paper_trail`
- `app/models/loan_application.rb` — added `include DeletionProtection`, changed `review_steps` dependent to `:restrict_with_exception`
- `app/models/loan.rb` — added `include DeletionProtection`
- `app/models/payment.rb` — added `include DeletionProtection`
- `app/models/invoice.rb` — added `include DeletionProtection`
- `app/models/review_step.rb` — added `include DeletionProtection`
- `app/models/document_upload.rb` — added `include DeletionProtection`
- `app/views/loans/show.html.erb` — added Record history section
- `app/views/loan_applications/show.html.erb` — added Record history section
- `app/views/payments/show.html.erb` — added Record history section
- `app/views/borrowers/show.html.erb` — added Record history section
- `spec/models/borrower_spec.rb` — added deletion protection and version tracking specs
- `spec/models/loan_spec.rb` — added deletion protection spec
- `spec/models/payment_spec.rb` — added deletion protection spec, updated existing destroy error expectation
- `spec/models/invoice_spec.rb` — added deletion protection spec
- `spec/models/review_step_spec.rb` — added deletion protection spec
- `spec/models/document_upload_spec.rb` — added deletion protection spec
- `spec/models/loan_application_spec.rb` — added deletion protection spec
- `spec/requests/loans_spec.rb` — added Record history assertion
- `spec/requests/loan_applications_spec.rb` — added Record history assertion
- `spec/requests/payments_spec.rb` — added Record history assertion
- `spec/requests/borrowers_spec.rb` — added Record history assertion

### Review Findings

- [x] [Review][Patch] N+1 query in `actor_display` — `User.find_by` called per version entry in loop; batch-load users or use a lookup hash [app/components/shared/activity_timeline_component.rb:30] — FIXED: replaced per-entry find_by with batch pluck into lookup hash
- [x] [Review][Patch] Double-wrapped section — views add `rounded-3xl bg-white` container around component's own `rounded-2xl bg-slate-50` section, producing nested borders and padding [app/views/borrowers/show.html.erb, loans/show.html.erb, loan_applications/show.html.erb, payments/show.html.erb] — FIXED: removed outer wrapper section from all 4 views
- [x] [Review][Patch] Redundant `versions.any?` guard in views duplicates component's `render?` check and fires an extra COUNT query [app/views/borrowers/show.html.erb, loans/show.html.erb, loan_applications/show.html.erb, payments/show.html.erb] — FIXED: removed view-level guard, relying on component render?
- [x] [Review][Defer] `DeletionProtection` does not guard `delete`/`delete_all` (bypasses callbacks) — deferred, pre-existing architectural limitation
- [x] [Review][Defer] `deletion_protection_spec.rb` duplicates shared example already in `borrower_spec.rb` — deferred, pre-existing test hygiene

### Change Log

- 2026-04-18: Implemented Story 6.4 — Added audit history timeline and deletion protection for operational records. All 7 tasks completed.
