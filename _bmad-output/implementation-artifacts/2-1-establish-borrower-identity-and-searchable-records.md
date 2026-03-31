# Story 2.1: Establish Borrower Identity and Searchable Records

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want borrower records to use a unique, searchable phone-based identity,
so that I can trust that each borrower exists once and can be found reliably.

## Acceptance Criteria

1. **Given** the system is ready for borrower data  
   **When** borrower persistence is introduced  
   **Then** the borrower entity uses UUID-based identity and stores the core borrower fields needed for MVP intake  
   **And** the borrower model supports a normalized phone-based lookup strategy consistent with the architecture

2. **Given** a borrower phone number is recorded  
   **When** the system stores or compares borrower identity  
   **Then** the phone number is normalized consistently  
   **And** the database and application rules prevent duplicate borrower records for the same phone number

3. **Given** a developer or operator inspects the borrower foundation  
   **When** they review the implementation  
   **Then** it supports future borrower search, detail pages, and lending record linkage  
   **And** it does not require unrelated lending entities to be created ahead of need

## Tasks / Subtasks

- [x] Introduce the borrower persistence foundation with UUID identity and a minimal MVP schema (AC: 1, 3)
  - [x] Add a `borrowers` table using UUID primary keys and only the smallest coherent intake fields required by current planning artifacts
  - [x] Treat borrower name and phone identity as the non-negotiable MVP foundation; avoid inventing speculative compliance, banking, or underwriting columns in this story
  - [x] Keep the borrower table independent from loan applications, loans, payments, and invoices so this story can land without creating unrelated lending entities early
  - [x] Ensure the schema leaves a clean path for later borrower history, borrower-linked applications, and borrower snapshotting without locking the team into a premature richer domain model

- [x] Implement a consistent phone normalization and uniqueness strategy (AC: 1, 2)
  - [x] Use the existing `phonelib` dependency to normalize phone values into one canonical lookup form before validation and persistence
  - [x] Store or derive a canonical searchable phone value that can support future borrower lookup and indexing reliably
  - [x] Enforce duplicate prevention in both application validation and the database, so formatting variants of the same logical phone number cannot create separate borrower rows
  - [x] Keep the lookup strategy aligned with the architecture note that search-critical borrower identifiers must remain searchable even if broader PII protection evolves later

- [x] Align the implementation to the repo’s current domain boundaries (AC: 1, 3)
  - [x] Put borrower persistence and simple invariants in `app/models/borrower.rb`
  - [x] Add `app/services/borrowers/*` only if a small application-service seam materially improves normalization or creation orchestration; otherwise do not create empty service scaffolding
  - [x] Add `app/queries/borrowers/*` only if this story introduces a real reusable lookup/read-model abstraction; do not create placeholder query classes with no current caller
  - [x] Do not build borrower controllers, routes, views, or components in this story unless a tiny amount of routing is required purely to support a testable foundation decision

- [x] Add focused automated coverage for the borrower identity foundation (AC: 1, 2, 3)
  - [x] Add model specs that prove the borrower uses UUID identity, validates the minimal intake foundation, and normalizes phone numbers consistently
  - [x] Prove duplicate-phone protection for format variants through both model-level behavior and database-backed uniqueness enforcement
  - [x] If a borrower service or query object is introduced, add the matching unit-level specs in the architecture-aligned spec locations
  - [x] Avoid low-value request or system specs here unless the implementation intentionally adds an HTTP or UI surface, which Story `2.1` does not require

### Review Findings

- [x] [Review][Patch] Translate duplicate-phone write races into a handled application outcome [`app/models/borrower.rb`] — fixed by adding `Borrowers::Create` so borrower creation can return a normal duplicate-phone error when the unique index wins a concurrent write race.
- [x] [Review][Patch] Missing invalid-phone coverage for the normalization guard [`spec/models/borrower_spec.rb`] — fixed by adding a model example that exercises the invalid-phone path and asserts the borrower remains invalid with a clear phone error.

## Dev Notes

### Story Intent

This story is the borrower data-model foundation for Epic 2, not the borrower intake UI itself. It should establish a trustworthy borrower identity model that later stories can build on for intake, search, borrower detail, application linkage, and borrower history visibility. The most important outcome is a single canonical borrower per real phone number, with a minimal schema and search-ready normalization strategy that will not need to be reinvented once borrower flows become visible in the UI.

### Epic Context and Downstream Dependencies

- Epic 2 is about borrower intake and borrower history, and Story `2.1` is the prerequisite for Stories `2.2` through `2.5`.
- Story `2.2` depends on this story’s normalization and duplicate-prevention rules so the borrower intake form can create records and return actionable duplicate-phone errors.
- Story `2.3` depends on this story’s phone-first, name-secondary identity model so borrower lookup can be fast and predictable.
- Story `2.4` depends on a stable borrower entity that later-linked applications and loans can hang from.
- Story `2.5` later evaluates whether a borrower can start a new application, but this story must not pull application or loan entities forward just to simulate that behavior.
- Epic 3 and later lending flows will rely on borrower identity being stable enough to support linked applications, borrower history during review, and eventual borrower snapshotting onto applications and loans.

### Current Codebase Signals

- The current database schema has UUID-backed `users` and `sessions`, but no `borrowers` table yet.
- The repo already includes `phonelib`, `paper_trail`, `pundit`, and `strong_migrations`, so this story should reuse the approved stack rather than introducing alternate phone-validation or uniqueness libraries.
- `app/models/user.rb` is the clearest current normalization example in the repo: it uses `normalizes` plus model-level uniqueness. Borrower phone identity should follow the same spirit while accounting for phone-format variation.
- `app/services/application_service.rb` provides the current `.call` service pattern if this story benefits from a borrower application-service seam.
- The architecture doc names future borrower files such as `app/models/borrower.rb`, `app/services/borrowers/*`, and `app/queries/borrowers/*`, but the runtime code does not contain them yet. This story should create only the pieces that are genuinely needed now.

### Scope Boundaries

- Deliver borrower identity persistence, normalization, uniqueness, and search-ready foundations. Do not build the borrower intake form here; that belongs to Story `2.2`.
- Do not create loan applications, loans, borrower snapshots, or borrower history UI in this story.
- Do not invent a larger regulated identity model than the planning artifacts justify. Avoid speculative fields such as government ID, KYC status, bank account data, or underwriting attributes.
- Keep the story small enough that later borrower form, list, detail, and eligibility stories can layer on top of it cleanly.

### Developer Guardrails

- Prefer the smallest coherent borrower schema that supports the current planning baseline. At minimum, the borrower foundation must support a human-readable borrower name and a phone-based identity that can be normalized and searched.
- The canonical phone lookup value must be deterministic and indexable. Do not store only a display-formatted phone number and hope later search logic reconstructs equivalence correctly.
- Do not blindly encrypt a search-critical borrower phone field in a way that breaks lookup. The architecture explicitly warns that searchable encrypted fields need a deliberate design such as deterministic encryption or a separate normalized/indexed strategy.
- Put hard identity invariants in both Ruby and PostgreSQL. App-level validation alone is not enough for one-borrower-per-phone trust.
- Keep business logic out of controllers and JavaScript. This story is primarily data-model and domain-foundation work.

### Technical Requirements

- The borrower entity must use UUID-based identity consistent with the project’s existing domain entities.
- The borrower persistence layer must support a phone-first lookup strategy and a name-based secondary lookup path for later stories.
- Phone normalization must collapse formatting variants of the same logical number into one canonical identity value before uniqueness checks run.
- Duplicate borrower creation for the same logical phone number must be blocked by both database rules and application-level behavior.
- The borrower foundation must remain compatible with later borrower search, borrower detail, borrower-linked lending records, and borrower snapshotting.
- The implementation must not require loan applications, loans, payments, or invoices to exist just to persist a borrower.

### Architecture Compliance

- `db/migrate/*_create_borrowers.rb`: create the borrower table and DB-level uniqueness/index strategy using safe Rails migrations.
- `app/models/borrower.rb`: canonical home for borrower persistence, normalization hooks, associations when genuinely needed, and simple invariants.
- `app/services/borrowers/*`: optional application-service home if normalization or create/update orchestration is cleaner there than in controllers or callers.
- `app/queries/borrowers/*`: optional read-model home if a real reusable lookup abstraction is introduced now.
- `app/policies/borrower_policy.rb`: not required to satisfy the current ACs, but keep later authorization alignment in mind if an HTTP surface unexpectedly appears.
- `spec/models/borrower_spec.rb`: primary proof surface for normalization, uniqueness, and schema-driven borrower behavior.
- `spec/services/borrowers/*` and `spec/queries/borrowers/*`: only if those runtime abstractions are introduced for real in this story.

### File Structure Requirements

Likely implementation touchpoints based on the current repo state:

- `db/migrate/*_create_borrowers.rb`
- `db/schema.rb`
- `app/models/borrower.rb`
- optionally `app/services/borrowers/*.rb`
- optionally `app/queries/borrowers/*.rb`
- `spec/models/borrower_spec.rb`
- optionally `spec/services/borrowers/*`
- optionally `spec/queries/borrowers/*`
- `spec/factories/borrowers.rb`

Avoid touching these in Story `2.1` unless a concrete implementation decision truly requires it:

- `config/routes.rb`
- `app/controllers/borrowers_controller.rb`
- `app/views/borrowers/*`
- `app/components/borrowers/*`
- `app/models/loan_application.rb`
- `app/models/loan.rb`

### Data Modeling Guidance

- Use a borrower name field that clearly supports later display and secondary lookup. Default to a single `full_name`-style field unless there is a strong planning-backed reason to split names earlier.
- Keep both user-facing and canonical phone concerns explicit. A practical MVP foundation is a user-facing phone field plus a canonical normalized lookup field such as `phone_number_normalized` or `phone_e164`.
- Index the canonical lookup field uniquely.
- If the implementation introduces additional borrower metadata beyond name and phone, it should be directly justifiable from the planned intake experience and not speculative domain expansion.

### UX Requirements to Preserve

- Even though this story is primarily backend foundation, it exists to support a future borrower intake form that must feel straightforward, duplicate-aware, and calm.
- The future borrower create/edit flow is described as “simple, explicit data-entry” with special emphasis on phone uniqueness and actionable validation messages.
- Search later needs to be phone-first and name-second, so the data model should preserve those priorities.
- Future borrower forms and lists must remain desktop-first, accessible, and consistent with the shared filter-bar and data-table patterns.

### Testing Requirements

- Add model specs for phone normalization across input variants such as spaces, punctuation, and different human-entered formatting.
- Add model and/or database-backed specs proving duplicate borrower creation is blocked for normalized-equivalent numbers.
- Verify UUID identity and the borrower schema’s minimum required fields in model-level coverage.
- If a canonical lookup column is added, test that it is populated consistently and stays aligned with persisted borrower identity behavior.
- If a borrower service or query is introduced, test it directly rather than relying on later request specs to incidentally cover the logic.
- Keep tests focused on the foundation story. Borrower form, list, and detail request/system coverage belongs in later borrower stories unless this story explicitly introduces those surfaces.

### Git Intelligence Summary

- Recent repo history is still concentrated on completing Epic 1 auth/workspace work: `Complete Epic 1 retrospective.`, `Add auth coverage reporting and browser specs.`, and `Complete authenticated workspace entry and logout flow.`.
- Use this story to shift into the first real lending-domain persistence work, but keep the same small-step discipline: add borrower identity foundations without bundling the intake UI, search UI, or application linkage.

### Latest Technical Information

- The repo already pins `phonelib` at `~> 0.10.17`, which matches the current stable release. Reuse it for deterministic phone normalization rather than adding another parsing/validation layer.
- Current Rails guidance for searchable encrypted fields still centers on deterministic encryption for fields that must support equality queries. If borrower phone encryption is introduced, it must remain queryable and index-compatible; otherwise prefer a simpler normalized/indexed lookup foundation now and evolve encryption deliberately later.
- `strong_migrations` remains available in development and test, so borrower migration/index changes should follow its safer migration expectations.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` - Epic 2, Story 2.1, Stories 2.2-2.5, Epic 3 dependency context
- `/_bmad-output/planning-artifacts/prd.md` - Persona: Admin Operator, Journey 1, FR4-FR8, FR65, FR67, FR74, borrower duplicate-prevention requirement, performance targets
- `/_bmad-output/planning-artifacts/architecture.md` - Data Architecture, Authentication & Security, searchable encrypted fields guidance, Project Structure & Boundaries, Requirements to Structure Mapping
- `/_bmad-output/planning-artifacts/ux-design-specification.md` - borrower form guidance, search and filtering patterns, data table patterns, accessibility strategy
- `/_bmad-output/planning-artifacts/ux-wireframes-pages/05-5-create-edit-borrower.html` - borrower create/edit wireframe and duplicate-awareness note
- `app/models/user.rb`
- `app/services/application_service.rb`
- `db/schema.rb`
- `Gemfile`

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-03-31T22:37:26+0530
- BMad config loaded from `_bmad/bmm/config.yaml`
- Sprint auto-discovery selected `2-1-establish-borrower-identity-and-searchable-records` as the first backlog story
- No `project-context.md` file was found in the workspace during story preparation
- Planning context gathered from Epic 2, the PRD, the architecture document, the UX specification, the borrower form wireframe, and current borrower-related codebase state
- Current runtime code contains no borrower model, borrower table, borrower services, borrower queries, or borrower specs yet
- Sprint tracking updated to `in-progress` before implementation work began
- Added borrower persistence with UUID identity, minimal schema, E.164-style canonical phone normalization, and duplicate protection at both model and database layers
- Ran `bin/rails db:migrate` and `bundle exec rspec` successfully after implementation (`41 examples, 0 failures`)

### Implementation Plan

- Add the borrower persistence layer with UUID identity, a minimal borrower schema, and a canonical phone normalization strategy.
- Enforce one-borrower-per-phone through model behavior plus database constraints so later borrower intake and search flows inherit reliable identity rules.
- Add focused model-level coverage for normalization, uniqueness, and any real borrower service/query seams introduced by the implementation.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- This story should leave the repo with a real borrower domain foundation but no borrower UI or lending-entity coupling yet.
- The highest-risk implementation mistake is choosing a phone storage strategy that looks fine in one model spec but cannot support fast, reliable borrower lookup later.
- The safest scope for this story is borrower identity and lookup readiness, not borrower intake screens or borrower history rendering.
- Added a `borrowers` table with UUID primary keys and the minimal MVP borrower foundation: `full_name`, `phone_number`, and `phone_number_normalized`.
- Implemented canonical borrower phone lookup in `app/models/borrower.rb` using `phonelib`, storing a normalized searchable value and preventing duplicates before persistence.
- Kept the story scoped to the borrower domain foundation only: no borrower controllers, routes, views, services, queries, or lending-entity dependencies were introduced.
- Added focused model coverage for UUID identity, phone normalization across formatting variants, model-level duplicate prevention, and DB-backed uniqueness enforcement.
- Added a small `Borrowers::Create` service seam so borrower creation can translate duplicate-phone unique-index races into a normal validation-style error for future write flows.
- Added explicit invalid-phone model coverage and service-level coverage for the borrower creation seam.

### File List

- `_bmad-output/implementation-artifacts/2-1-establish-borrower-identity-and-searchable-records.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/models/borrower.rb`
- `app/services/borrowers/create.rb`
- `db/migrate/20260331181000_create_borrowers.rb`
- `db/schema.rb`
- `spec/factories/borrowers.rb`
- `spec/models/borrower_spec.rb`
- `spec/services/borrowers/create_spec.rb`

### Change Log

- 2026-03-31: Added the borrower persistence foundation with UUID identity, canonical phone normalization, duplicate-phone protection, and focused model specs. Updated story and sprint status to `review`.
- 2026-03-31: Completed code review follow-up by adding a borrower creation service seam for duplicate-phone race handling, adding invalid-phone coverage, and moving the story to `done`.
