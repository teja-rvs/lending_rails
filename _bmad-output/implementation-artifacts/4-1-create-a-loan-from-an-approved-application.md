# Story 4.1: Create a Loan from an Approved Application

Status: done

## Story

As an admin operator,
I want an approved application to become a loan record with explicit lifecycle states,
So that lending work can progress from decisioning into controlled execution.

## Acceptance Criteria

1. **Given** an application has been approved  
   **When** the system performs the approval-to-loan transition  
   **Then** it creates a linked loan record from the approved application  
   **And** loan approval remains distinct from actual disbursement

2. **Given** the loan is newly created  
   **When** the admin views it  
   **Then** the loan uses the agreed lifecycle vocabulary for pre-disbursement states  
   **And** the current state is shown clearly in the loan UI

3. **Given** the loan exists  
   **When** the system records lifecycle movement  
   **Then** transitions are driven by valid business events rather than ad hoc manual state toggles  
   **And** the loan remains linked to its source application

## Tasks / Subtasks

- [x] Task 1: Expand Loan model lifecycle states and add AASM (AC: #1, #2, #3)
  - [x] 1.1 Create migration to add borrower snapshot columns and any missing loan fields to `loans` table
  - [x] 1.2 Update `Loan` model: replace string-based `STATUSES` with full AASM state machine
  - [x] 1.3 Define AASM states: `created`, `documentation_in_progress`, `ready_for_disbursement`, `active`, `overdue`, `closed`
  - [x] 1.4 Define AASM events: `begin_documentation`, `complete_documentation`, `disburse`, `mark_overdue`, `resolve_overdue`, `close`
  - [x] 1.5 Add `has_paper_trail` to Loan model for audit
  - [x] 1.6 Add borrower snapshot fields and proper validations
  - [x] 1.7 Update `status_tone` and `status_label` for new states
  - [x] 1.8 Add a convenience `#loan` method on `LoanApplication` (the model already has `has_many :loans`) to return the single expected loan
- [x] Task 2: Create `Loans::CreateFromApplication` service (AC: #1)
  - [x] 2.1 Implement service with `Result` struct pattern (matching existing convention)
  - [x] 2.2 Validate application is approved and has no existing loan
  - [x] 2.3 Create loan with `status: "created"`, linked `loan_application_id`, `borrower_id`, borrower snapshots
  - [x] 2.4 Auto-generate `loan_number` using `LOAN-NNNN` sequence pattern
  - [x] 2.5 Use `with_lock` on the loan application to prevent race conditions
- [x] Task 3: Wire loan creation into the application approval flow (AC: #1)
  - [x] 3.1 Update `LoanApplications::Approve` service to call `Loans::CreateFromApplication` after successful approval
  - [x] 3.2 Wrap both operations in a transaction so approval + loan creation are atomic
  - [x] 3.3 Extend `Approve::Result` struct to include `loan` field and return loan on success for flash/redirect use
- [x] Task 4: Update Loan show page with lifecycle state display (AC: #2)
  - [x] 4.1 Expand loan detail view to show lifecycle state clearly with appropriate badge
  - [x] 4.2 Show linked application details and borrower snapshot data
  - [x] 4.3 Display next valid action context (for story 4.1: informational only, future stories add actions)
- [x] Task 5: Add loan link on approved application detail page (AC: #1, #2)
  - [x] 5.1 After approval, show the linked loan on the application show page
  - [x] 5.2 Provide navigation link from application to its loan
- [x] Task 6: Update routes if needed (AC: #2)
  - [x] 6.1 Verify `loans#show` route exists (it does), no new routes needed for this story
- [x] Task 7: Update factory and write tests (AC: #1, #2, #3)
  - [x] 7.1 Update loan factory with new default state `created` and traits for each lifecycle state
  - [x] 7.2 Write model specs for AASM states, events, transitions, and guards
  - [x] 7.3 Write service specs for `Loans::CreateFromApplication` (happy path + blocked paths)
  - [x] 7.4 Update `LoanApplications::Approve` service specs to verify loan creation side effect
  - [x] 7.5 Write request specs for loan show with new lifecycle states
  - [x] 7.6 Write system specs for approval-to-loan flow end-to-end

### Review Findings

- [x] [Review][Patch] Serialize `loan_number` allocation so concurrent approvals on different applications cannot compute the same next value and fail the approval transaction. [`app/models/loan.rb:53`]
- [x] [Review][Patch] Backfill borrower snapshot columns for existing loans before the new presence validations apply, otherwise pre-existing rows can become unsaveable after this migration. [`db/migrate/20260414173000_add_borrower_snapshots_to_loans.rb:1`]
- [x] [Review][Patch] Fix `Loan#next_lifecycle_stage_label` for overdue loans; it currently reports `Closed` even though the model still allows `resolve_overdue!` back to `Active`. [`app/models/loan.rb:87`]

## Dev Notes

### Critical Architecture Constraints

- **Domain services own all mutations.** The `Loans::CreateFromApplication` service must handle loan creation — controllers and jobs must not create loans directly. [Source: architecture.md — "Domain logic boundaries"]
- **AASM for state machines.** Use `aasm` gem (already in Gemfile `~> 5.5`) for loan lifecycle states instead of manual string management. [Source: architecture.md — Core Architectural Decisions]
- **Service result pattern.** Follow the established `Result = Struct.new(:entity, :error, keyword_init: true)` with `success?` and `blocked?` methods. See `LoanApplications::Approve` for the canonical example.
- **`with_lock` for transitions.** All state-changing services must acquire a pessimistic lock. This is already the pattern in `LoanApplications::Approve`.
- **`paper_trail` for audit.** Add `has_paper_trail` to `Loan` model. PaperTrail whodunnit is already configured in `ApplicationController`.
- **UUID primary keys.** All domain entities use UUID PKs — the `loans` table already has `id: :uuid`.
- **Borrower snapshots.** Per PRD: "Borrower information should be snapshotted onto applications and loans so later borrower edits do not rewrite historical decision context." Copy `borrower.full_name` and `borrower.phone_number_normalized` at loan creation time, exactly as `LoanApplication` does.
- **No hard delete.** Never destroy loan records. [Source: prd.md — "No hard deletion of operational or financial records"]

### Loan Lifecycle States (Full Vocabulary)

Per architecture and PRD, the canonical loan lifecycle states are:

| State | Meaning | Entered Via |
|-------|---------|-------------|
| `created` | Loan exists but no work started | Application approval → `Loans::CreateFromApplication` |
| `documentation_in_progress` | Documentation stage active | Story 4.3 (future) |
| `ready_for_disbursement` | All pre-disbursement checks passed | Story 4.4 (future) |
| `active` | Disbursed and in repayment | Story 4.5 (future) |
| `overdue` | At least one payment past due | Story 5.5 (future) |
| `closed` | All payments completed | Story 5.6 (future) |

**This story implements only the `created` state entry point.** Define all states and events in AASM now for architectural completeness, but only the `created` initial state and the `begin_documentation` event guard need full implementation. Other events will be fleshed out by their respective stories.

### AASM Implementation Guide

```ruby
class Loan < ApplicationRecord
  include AASM

  aasm column: :status, whiny_transitions: true do
    state :created, initial: true
    state :documentation_in_progress
    state :ready_for_disbursement
    state :active
    state :overdue
    state :closed

    event :begin_documentation do
      transitions from: :created, to: :documentation_in_progress
    end

    event :complete_documentation do
      transitions from: :documentation_in_progress, to: :ready_for_disbursement
    end

    event :disburse do
      transitions from: :ready_for_disbursement, to: :active
    end

    event :mark_overdue do
      transitions from: :active, to: :overdue
    end

    event :resolve_overdue do
      transitions from: :overdue, to: :active
    end

    event :close do
      transitions from: [:active, :overdue], to: :closed
    end
  end
end
```

**Key `aasm` patterns:**
- Use `loan.may_begin_documentation?` in views/services to check if an event is valid
- Use `loan.begin_documentation!` (bang) in services to persist + raise on invalid transition
- `whiny_transitions: true` raises `AASM::InvalidTransition` on illegal transitions
- The `status` column already exists as a string — AASM reads/writes it directly

### Breaking Change: Loan Model Statuses

The current `Loan` model defines `STATUSES = ["active", "closed", "overdue"]` and the factory defaults to `status { "active" }`. This story **replaces** that constant with the full AASM lifecycle. The factory default must change from `"active"` to `"created"`. Update all existing specs that create loans with `status: "active"` — verify they still pass with the new AASM initial state or add explicit `status` overrides where needed. The existing loan show system spec (`spec/system/loan_detail_flow_spec.rb` if it exists) must be updated.

### Migration Requirements

Add to `loans` table:

```ruby
add_column :loans, :borrower_full_name_snapshot, :string
add_column :loans, :borrower_phone_number_snapshot, :string
```

**Do NOT change the default value of `status` at the DB level** — AASM handles the initial state. However, ensure the existing migration/schema does not set a DB-level default that conflicts.

### Service: `Loans::CreateFromApplication`

File: `app/services/loans/create_from_application.rb`

```ruby
module Loans
  class CreateFromApplication < ApplicationService
    Result = Struct.new(:loan, :error, keyword_init: true) do
      def success? = error.blank?
      def blocked? = error.present?
    end

    def initialize(loan_application:)
      @loan_application = loan_application
    end

    def call
      loan_application.with_lock do
        return blocked_result("Application is not approved.") unless loan_application.status == "approved"
        return blocked_result("A loan already exists for this application.") if loan_application.loan.present?

        loan = Loan.create!(
          loan_application: loan_application,
          borrower: loan_application.borrower,
          loan_number: Loan.next_loan_number,
          status: "created",
          borrower_full_name_snapshot: loan_application.borrower.full_name,
          borrower_phone_number_snapshot: loan_application.borrower.phone_number_normalized
        )

        Result.new(loan:)
      end
    end

    private
      attr_reader :loan_application

      def blocked_result(error)
        Result.new(loan: nil, error:)
      end
  end
end
```

### Updating `LoanApplications::Approve`

The existing approve service at `app/services/loan_applications/approve.rb` must be updated to create the loan atomically after approval.

**Step 1 — Extend the Result struct** to include a `loan` field:

```ruby
Result = Struct.new(:loan_application, :loan, :error, keyword_init: true) do
  def success? = error.blank?
  def blocked? = error.present?
end
```

**Step 2 — Update `call`** to create the loan inline (avoids nested `with_lock` deadlock):

```ruby
def call
  loan_application.with_lock do
    return blocked_result(blocked_error) unless loan_application.approvable?

    loan_application.update!(status: "approved")

    loan = create_loan!

    Result.new(loan_application:, loan:)
  end
end

private

  def create_loan!
    Loan.create!(
      loan_application:,
      borrower: loan_application.borrower,
      loan_number: Loan.next_loan_number,
      status: "created",
      borrower_full_name_snapshot: loan_application.borrower.full_name,
      borrower_phone_number_snapshot: loan_application.borrower.phone_number_normalized
    )
  end
```

**Important:** The loan creation logic lives inline in `Approve` (inside the same `with_lock` transaction) to avoid nested lock deadlocks. `Loans::CreateFromApplication` remains as a standalone service for any future edge case where a loan must be created independently of the approval flow. Both paths produce the same loan shape.

**Step 3 — Update the controller** flash to include the loan number:

```ruby
if result.success?
  redirect_to loan_application_path(result.loan_application),
    notice: "Application approved. Loan #{result.loan.loan_number} created."
else
  redirect_to loan_application_path(result.loan_application),
    alert: result.error
end
```

### Loan Number Generation

Follow the same pattern as `LoanApplication.next_application_number`:

```ruby
def self.next_loan_number
  highest = where("loan_number LIKE ?", "LOAN-%")
    .pluck(:loan_number)
    .filter_map { |v| v.delete_prefix("LOAN-").to_i if v.match?(/\ALOAN-\d+\z/) }
    .max

  "LOAN-#{((highest || 0) + 1).to_s.rjust(4, '0')}"
end
```

This already matches the factory pattern `sequence(:loan_number) { |n| "LOAN-#{n.to_s.rjust(4, '0')}" }`.

### LoanApplication Model Update

The model already has `has_many :loans, dependent: :restrict_with_exception`. Do NOT add a duplicate `has_one :loan` — that would create conflicting association APIs. Instead, add a convenience method for the one-to-one business rule:

```ruby
def loan
  loans.first
end
```

Uniqueness is enforced at the service level (`Loans::CreateFromApplication` checks `loan_application.loans.exists?` before creating). The `has_many` stays because Rails uses it for the FK relationship, and `restrict_with_exception` prevents orphaned loans.

### UI Updates

**Loan show page** (`app/views/loans/show.html.erb`):
- Replace the placeholder text "This read-only loan page exists so borrower history links resolve..." with proper lifecycle state display
- Show: loan number, lifecycle state badge, borrower snapshot, linked application link, creation timestamp
- Show informational text about next lifecycle stage (documentation)
- Use existing `Shared::StatusBadgeComponent` with updated `status_tone` mapping

**Application show page** (`app/views/loan_applications/show.html.erb`):
- After the "Application decision" section, if status is `approved` and a loan exists, show a linked loan card with navigation to the loan detail page
- Text: "A loan has been created from this approved application"
- Link: "View loan → LOAN-NNNN"

### Status Tone Mapping (Updated)

```ruby
def status_tone
  case aasm.current_state
  when :created
    :neutral
  when :documentation_in_progress
    :warning
  when :ready_for_disbursement
    :success
  when :active
    :success
  when :overdue
    :danger
  when :closed
    :neutral
  else
    :neutral
  end
end
```

`Shared::StatusBadgeComponent` supports `:success`, `:danger`, `:warning`, and `:neutral`. Use `:neutral` for `created` and `closed`.

### Project Structure Notes

Files to create:
- `app/services/loans/create_from_application.rb`
- `db/migrate/YYYYMMDDHHMMSS_add_snapshot_and_lifecycle_fields_to_loans.rb`
- `spec/services/loans/create_from_application_spec.rb`

Files to modify:
- `app/models/loan.rb` — AASM, paper_trail, snapshots, validations, `next_loan_number`
- `app/services/loan_applications/approve.rb` — add loan creation after approval
- `app/views/loans/show.html.erb` — expanded lifecycle UI
- `app/views/loan_applications/show.html.erb` — linked loan card after approval
- `spec/factories/loans.rb` — traits for each lifecycle state, default to `created`
- `spec/models/loan_spec.rb` — AASM transitions, validations
- `spec/services/loan_applications/approve_spec.rb` — verify loan creation side effect
- `spec/requests/loans_spec.rb` — lifecycle state display
- `spec/system/` — approval-to-loan flow

Files NOT to touch:
- Do not modify `LoanApplications::Create` or `LoanApplications::InitializeReviewWorkflow`
- Do not add loan list/index views (that's Story 4.2)
- Do not add documentation or disbursement logic (Stories 4.3–4.5)
- Do not add `double_entry` postings (only for money-moving services, which start at Story 4.5)

### Testing Requirements

- **Model specs:** AASM state definitions, valid transitions, invalid transition rejection, `next_loan_number` generation, validations, associations, `paper_trail` versioning
- **Service specs for `Loans::CreateFromApplication`:** Approved app creates loan with correct attributes; non-approved app returns blocked result; duplicate loan creation returns blocked result; borrower snapshots are captured correctly
- **Service specs for `LoanApplications::Approve` (update):** Successful approval also creates a linked loan; loan has `status: "created"`; loan `borrower_id` matches application's borrower; loan snapshots match borrower data
- **Request specs:** `GET /loans/:id` returns correct lifecycle state badge and linked application
- **System specs:** End-to-end flow — approve an application → verify loan created → navigate to loan → verify lifecycle state display → navigate back to application → verify loan link visible

### Previous Story Intelligence

From Story 3.5 (approve/reject/cancel):
- **Pattern:** Services use `with_lock` + `Result` struct. Follow exactly.
- **Controller pattern:** `find → authorize → service.call → redirect + flash`. The loans controller currently only has `show` — no new controller actions needed for this story.
- **Testing:** 176 examples passing as of last commit. Do not break existing tests.
- **Gotcha:** PostgreSQL/Docker connectivity was an issue in previous stories. Ensure DB is running before test suite.
- **Flash messages:** Use clear, action-oriented language. E.g., "Application approved. Loan LOAN-NNNN created." on successful approval.

### Git Intelligence

Recent commits follow the pattern: `Add <feature description>.` with focused, single-story changes. The last 5 commits touched 10–17 files each. Keep changes focused on this story's scope.

### References

- [Source: architecture.md — Loan lifecycle states: FR34, FR35]
- [Source: architecture.md — Service boundaries and `Loans::CreateFromApplication`]
- [Source: architecture.md — AASM for canonical workflow state transitions]
- [Source: prd.md — FR30: Loan creation from approved application]
- [Source: prd.md — FR31: Keep loan approval distinct from disbursement]
- [Source: prd.md — FR34: Explicit loan lifecycle states]
- [Source: prd.md — FR74: Preserve borrower details on loans for historical integrity]
- [Source: epics.md — Epic 4, Story 4.1 acceptance criteria]
- [Source: ux-design-specification.md — Lifecycle Status Badge, Entity Header, Linked-Record Panel]

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- 2026-04-14: Loaded BMad config directly from `_bmad/bmm/config.yaml` after the local `bmad_init.py load` fast-path failed because the Python `yaml` module is not installed in this environment.
- 2026-04-14: Added the loan borrower snapshot migration, ran `bin/rails db:migrate` and `RAILS_ENV=test bin/rails db:migrate`, and refreshed `db/schema.rb`.
- 2026-04-14: Focused Story 4.1 spec runs passed but exited non-zero under SimpleCov because the repo enforces an 80% minimum coverage threshold on each run; final validation used the full suite.
- 2026-04-14: Final validation passed with `bundle exec rspec` (`195 examples, 0 failures`), targeted `bundle exec rubocop` on changed Ruby files, and `ReadLints` on edited files.

### Completion Notes List

- Implemented the `Loan` AASM lifecycle with the full pre- and post-disbursement vocabulary, borrower snapshot validation, `paper_trail`, display helpers, and `Loan.next_loan_number`.
- Added `Loans::CreateFromApplication`, updated `LoanApplications::Approve` to create the linked loan atomically, and surfaced the loan number in the approval success flash.
- Expanded the loan detail page to show lifecycle state, borrower snapshot data, linked application context, and next-stage guidance; added the linked-loan card to approved application detail pages.
- Updated the loan factory and added focused model, service, request, and system coverage for the approval-to-loan flow and lifecycle UI.

### File List

- `_bmad-output/implementation-artifacts/4-1-create-a-loan-from-an-approved-application.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/controllers/loan_applications_controller.rb`
- `app/models/loan.rb`
- `app/models/loan_application.rb`
- `app/services/loan_applications/approve.rb`
- `app/services/loans/create_from_application.rb`
- `app/views/loan_applications/show.html.erb`
- `app/views/loans/show.html.erb`
- `db/migrate/20260414173000_add_borrower_snapshots_to_loans.rb`
- `db/schema.rb`
- `spec/factories/loans.rb`
- `spec/models/loan_spec.rb`
- `spec/requests/loan_applications_spec.rb`
- `spec/requests/loans_spec.rb`
- `spec/services/loan_applications/approve_spec.rb`
- `spec/services/loans/create_from_application_spec.rb`
- `spec/system/loan_application_workflow_spec.rb`
- `spec/system/loan_detail_flow_spec.rb`

### Change Log

- 2026-04-14: Added the approval-to-loan transition flow, full loan lifecycle state machine scaffolding, borrower snapshots, linked loan/application UI, and focused automated coverage for Story 4.1.