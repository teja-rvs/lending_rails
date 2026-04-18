# Story 6.3: Search and Investigate Across Linked Lending Records

Status: done

## Story

As an admin operator,
I want to search and investigate borrowers, applications, loans, and payments through linked records,
So that I can reconstruct the right operational context quickly.

## Acceptance Criteria

1. **Given** the admin needs to find a specific record
   **When** they search across borrowers, applications, loans, or payments
   **Then** the system supports lookup by the primary identifiers for those entities
   **And** search behavior remains consistent across operational list views

2. **Given** the admin opens a record from search or a filtered list
   **When** the detail page loads
   **Then** linked borrower, application, loan, payment, disbursement, and invoice relationships are visible where relevant
   **And** navigation across those relationships preserves orientation

3. **Given** the product uses shared detail patterns
   **When** the admin investigates linked records
   **Then** entity headers, relationship context, and status indicators stay consistent across entities
   **And** the UI makes record lineage understandable without relying on memory

## Tasks / Subtasks

- [x] Task 1: Add search to loan applications index (AC: #1)
  - [x] 1.1 Add search form to `app/views/loan_applications/index.html.erb` matching the borrowers/loans/payments search pattern: `search_field_tag :q`, `submit_tag "Search applications"`, hidden fields for active `status` param.
  - [x] 1.2 Search should match on `application_number` (ILIKE) and `borrowers.full_name` (ILIKE) — already implemented in `LoanApplications::FilteredListQuery#search_matches`. Controller already reads `@search_query = params[:q].to_s.squish` and passes `search: @search_query`. The view simply needs the search form added.
  - [x] 1.3 Add "Clear search" link when `@search_query.present?`, preserving any active `status` filter.
  - [x] 1.4 Add filtered-empty state for search: when `@has_loan_applications && @search_query.present? && @loan_applications.empty?`, show "No applications match this search" with "Clear search" link.

- [x] Task 2: Add search to payments index (AC: #1)
  - [x] 2.1 Extend `Payments::FilteredListQuery#search_matches` to also match `borrowers.phone_number_normalized ILIKE :query`. Currently it only matches `loans.loan_number` and `borrowers.full_name`. Payments have no record number of their own visible to the user; the most useful secondary identifier is the borrower phone.
  - [x] 2.2 Verify the search form in `app/views/payments/index.html.erb` already exists and correctly preserves `view`, `status`, and `due_window` params via hidden fields. It does — no view changes needed for the search form itself.
  - [x] 2.3 Update search placeholder text to include phone number hint, e.g. `"Loan number, borrower name, or phone"`.

- [x] Task 3: Add borrower phone search to loans and applications search (AC: #1)
  - [x] 3.1 Extend `Loans::FilteredListQuery#search_matches` to also match `borrowers.phone_number_normalized ILIKE :query` in addition to existing `loans.loan_number` and `borrowers.full_name`.
  - [x] 3.2 Extend `LoanApplications::FilteredListQuery#search_matches` to also match `borrowers.phone_number_normalized ILIKE :query` in addition to existing `loan_applications.application_number` and `borrowers.full_name`.
  - [x] 3.3 Update search field placeholder text on loans index to `"Loan number, borrower name, or phone"`.
  - [x] 3.4 Update search field placeholder text on loan applications index to `"Application number, borrower name, or phone"`.
  - [x] 3.5 Update search field placeholder text on borrowers index to reflect current behavior: `"Phone number or name"` (already close — verify label matches).

- [x] Task 4: Add linked-record navigation on loan detail page (AC: #2, #3)
  - [x] 4.1 On `app/views/loans/show.html.erb`, add a "Linked records" section after the loan summary showing:
    - Borrower link (already present in header — ensure it links to `borrower_path`)
    - Linked application link (already present — ensure clickable via `loan_application_path`)
    - Payments summary with link to filtered payments: `payments_path(q: @loan.loan_number)` — this shows all payments for this loan
    - Disbursement invoice link if disbursed (already present in disbursement section)
  - [x] 4.2 Ensure the repayment schedule table "Open payment" links use `from: "loans"` for breadcrumb context (already implemented — verify).

- [x] Task 5: Add linked-record navigation on loan application detail page (AC: #2, #3)
  - [x] 5.1 On `app/views/loan_applications/show.html.erb`, the "Linked loan" section already exists when status is approved and a loan is present. Verify it links to `loan_path(linked_loan)`.
  - [x] 5.2 The "Borrower lending context" section already shows linked applications and loans from `Borrowers::HistoryQuery`. Verify all links are clickable and navigable.
  - [x] 5.3 No new sections needed — the existing detail page already provides linked-record investigation capability.

- [x] Task 6: Add linked-record navigation on payment detail page (AC: #2, #3)
  - [x] 6.1 On `app/views/payments/show.html.erb`, loan and borrower links are already present. Add a link to the loan's application if available: `@payment.loan.loan_application` → `loan_application_path(@payment.loan.loan_application)`.
  - [x] 6.2 Add "View all payments for this loan" link: `payments_path(q: loan.loan_number)`.
  - [x] 6.3 Add the payment's invoice link if present (already shows invoice number — make it visible but not clickable since invoices have no dedicated show page).

- [x] Task 7: Ensure consistent entity headers across detail pages (AC: #3)
  - [x] 7.1 Verify all detail pages follow the shared pattern: breadcrumb → entity header (type label + record number + status badge) → linked context → detail sections. All four entity detail pages (borrower, application, loan, payment) already follow this pattern.
  - [x] 7.2 Add `from` breadcrumb support on loan application show: when `params[:from] == "applications"`, include "Applications" in breadcrumb. This pattern already exists for loans (`from: "loans"`) and payments (`from: "loans"`, `from: "payments"`). Currently loan_applications show already supports `from: "applications"` — verify.

- [x] Task 8: Tests (AC: #1, #2, #3)
  - [x] 8.1 `spec/requests/loan_applications_spec.rb` — Add tests:
    - Search by application number: `get loan_applications_path, params: { q: application.application_number }` returns matching application
    - Search by borrower name: returns applications for matching borrower
    - Search by borrower phone: returns applications for matching borrower
    - Search with active status filter: both search and status applied together
    - Empty search results show "No applications match" message
    - Search form preserves status filter via hidden field
  - [x] 8.2 `spec/requests/loans_spec.rb` — Add tests:
    - Search by borrower phone: `get loans_path, params: { q: phone_number }` returns matching loans
    - Existing loan_number and borrower name search already tested — add phone variant
  - [x] 8.3 `spec/requests/payments_spec.rb` — Add tests:
    - Search by borrower phone: `get payments_path, params: { q: phone_number }` returns matching payments
    - Search with view filter: both search and view applied together
  - [x] 8.4 `spec/requests/loans_spec.rb` — Add test:
    - Loan show page renders linked application link when application exists
    - Loan show page renders "View all payments" link
  - [x] 8.5 `spec/requests/payments_spec.rb` — Add test:
    - Payment show page renders linked application link when loan has application
    - Payment show page renders "View all payments for this loan" link
  - [x] 8.6 Run `bundle exec rspec` green. Run `bundle exec rubocop` green on all touched files. No new gems, no new migrations.

### Review Findings

- [x] [Review][Patch] Missing negative-path test for absent `loan_application` on loan show page [spec/requests/loans_spec.rb] — fixed: added test asserting "Application:" link is absent when `loan_application` is nil
- [x] [Review][Patch] Missing negative-path test for absent `loan_application` on payment show page [spec/requests/payments_spec.rb] — fixed: added test asserting "Linked application" section is absent when `loan.loan_application` is nil
- [x] [Review][Defer] No database index on `borrowers.phone_number_normalized` for ILIKE search — deferred, pre-existing schema concern
- [x] [Review][Defer] Tripled raw SQL search predicate across three query objects — deferred, pre-existing pattern duplication
- [x] [Review][Defer] Test setup duplication: every test creates user with hardcoded email — deferred, pre-existing test pattern
- [x] [Review][Defer] No special-character test for phone search input — deferred, general test hardening

## Dev Notes

### Epic 6 Cross-Story Context

- **Epic 6** covers portfolio visibility, search, and trusted record history (FR57–FR70, FR73–FR74).
- **Story 6.1** (done) built the action-first dashboard with triage/summary widgets, query objects, controller, components, and nav bar.
- **Story 6.2** (done) fixed dashboard drill-in parity, added multi-status filtering, filter-context banners, and drill-in empty states.
- **This story (6.3)** completes search across all entity lists and ensures linked-record investigation from detail pages.
- **Story 6.4** will add audit history visibility and record protection.
- **Story 6.5** will add derived-state integrity and historical snapshots.

### Functional Requirements Covered

- **FR65:** Admin can search borrowers by phone number or name, and can search applications, loans, and payments by the record number shown for each item.
- **FR66:** Admin can investigate linked borrower, application, loan, disbursement, payment, and invoice records from within the product.
- **FR67:** System can maintain linked records across borrowers, applications, loans, disbursements, payments, and invoices.

### What Already Exists (DO NOT Recreate)

The search and linked-record infrastructure is **mostly built**. This story fills gaps:

**Search already works:**
- **Borrowers index:** Search by phone (exact match on normalized) or name (ILIKE). Full search form with clear button. ✅
- **Loans index:** Search by `loan_number` or `borrower.full_name` (ILIKE). Search form present. ✅
- **Payments index:** Search by `loan.loan_number` or `borrower.full_name` (ILIKE). Search form present. ✅
- **Loan applications index:** Search by `application_number` or `borrower.full_name` (ILIKE). **Query supports it but the view has NO search form.** ❌ This is the primary gap.

**Linked records already work on detail pages:**
- **Borrower show:** `Borrowers::HistoryQuery` renders linked applications and loans via `Borrowers::LinkedRecordsPanelComponent`. ✅
- **Loan application show:** Borrower link, borrower lending context section with `HistoryQuery`, linked loan section when approved. ✅
- **Loan show:** Borrower link, linked application link, repayment schedule with payment links, disbursement invoice. ✅
- **Payment show:** Loan link, borrower link. **Missing:** linked application link, "view all payments for this loan" link. ❌

### Gaps This Story Fills

1. **Loan applications index has no search form** — the controller and query already support `q` param search, but the view never renders the search form. Add it matching the pattern from loans/payments.
2. **Phone number search missing from loans, applications, and payments queries** — borrowers use phone as primary lookup, but loans/applications/payments only search by record number and borrower name. Adding `borrowers.phone_number_normalized ILIKE :query` to all three query objects makes search consistent per FR65.
3. **Payment detail page missing linked application** — when a payment's loan was created from an application, that relationship should be visible.
4. **Payment detail page missing "View all payments for this loan"** — cross-payment navigation from a single payment detail.

### Critical Architecture Constraints

- **No new query objects.** Extend existing `FilteredListQuery` classes with phone number search only.
- **No new controllers or routes.** Search uses existing `GET index` with `q` param.
- **No new components.** Search forms and linked-record links are inline ERB.
- **No mutations.** This story is entirely read-side.
- **No new gems, no new migrations, no new initializers.**
- **Controllers remain thin.** No controller changes needed — `@search_query = params[:q].to_s.squish` already exists in all controllers.
- **No new models or associations.** All relationships already exist in the schema.

### Existing Patterns to Follow

1. **Search form pattern** — See `app/views/loans/index.html.erb` for the canonical search form: `form_with url: ..._path, method: :get` → `search_field_tag :q, @search_query` → `submit_tag "Search ...", name: nil` → conditional "Clear search" link. Hidden fields preserve active filters.

2. **Search query pattern** — See `Loans::FilteredListQuery#search_matches`: `sanitize_sql_like(search)` → `ILIKE` with `%query%` → `joins(:borrower)` for cross-table search.

3. **Linked record links on detail pages** — See `app/views/loans/show.html.erb` line 74: `link_to @loan.loan_application.application_number, loan_application_path(@loan.loan_application)`. Use same underline style: `class: "underline decoration-slate-300 underline-offset-4 transition hover:decoration-slate-500"`.

4. **Breadcrumb pattern** — See `app/views/payments/show.html.erb`: conditional breadcrumb segments based on `params[:from]`.

5. **Empty state pattern** — See `app/views/borrowers/index.html.erb` lines 87-98: amber card with "Filtered results" label, message, and "Clear search" + CTA buttons.

6. **Request spec pattern** — See `spec/requests/loans_spec.rb`: `get loans_path, params: { q: "LOAN-0001" }` → `assert_select` for presence/absence. Use `sign_in_as` or `post session_path` per existing spec conventions.

### Files to Modify

| Area | Files | Changes |
|------|--------|---------|
| View | `app/views/loan_applications/index.html.erb` | Add search form (matching loans/payments pattern) |
| Query | `app/queries/loans/filtered_list_query.rb` | Add `borrowers.phone_number_normalized ILIKE` to search_matches |
| Query | `app/queries/loan_applications/filtered_list_query.rb` | Add `borrowers.phone_number_normalized ILIKE` to search_matches |
| Query | `app/queries/payments/filtered_list_query.rb` | Add `borrowers.phone_number_normalized ILIKE` to search_matches |
| View | `app/views/loans/index.html.erb` | Update search placeholder to include "or phone" |
| View | `app/views/payments/index.html.erb` | Update search placeholder to include "or phone" |
| View | `app/views/payments/show.html.erb` | Add linked application link, "View all payments for this loan" link |
| Spec | `spec/requests/loan_applications_spec.rb` | Add search tests (application number, name, phone, with filter, empty state) |
| Spec | `spec/requests/loans_spec.rb` | Add phone search test, linked record assertions on show |
| Spec | `spec/requests/payments_spec.rb` | Add phone search test, linked record assertions on show |

### Files NOT to Create or Modify

- Do NOT create new query objects — extend existing ones only.
- Do NOT modify `Borrowers::LookupQuery` — borrower search logic (exact phone match vs name ILIKE) is deliberately different from the generic ILIKE pattern used by other entities. The borrower search uses `phone_number_normalized` exact match; other entities use ILIKE partial match.
- Do NOT modify `BorrowersController` — borrower search already works.
- Do NOT modify `app/views/borrowers/index.html.erb` — search form already complete.
- Do NOT modify `app/views/borrowers/show.html.erb` — linked records panel already renders via `Borrowers::LinkedRecordsPanelComponent`.
- Do NOT modify any model — no schema or association changes needed.
- Do NOT modify routes — all search uses existing `GET index` with query string.
- Do NOT modify `DashboardController` or dashboard views — those are complete.
- Do NOT add Turbo Frames or Streams — standard page navigation.
- Do NOT create a unified "global search" page — FR65 specifies search on existing list views, not a new cross-entity search surface.

### Search Field Mapping (Per FR65)

| Entity | Search fields | Where implemented |
|--------|---------------|-------------------|
| Borrowers | `phone_number_normalized` (exact), `full_name` (ILIKE) | `Borrowers::LookupQuery` — no changes |
| Loan Applications | `application_number` (ILIKE), `borrowers.full_name` (ILIKE), `borrowers.phone_number_normalized` (ILIKE) | `LoanApplications::FilteredListQuery` — add phone |
| Loans | `loan_number` (ILIKE), `borrowers.full_name` (ILIKE), `borrowers.phone_number_normalized` (ILIKE) | `Loans::FilteredListQuery` — add phone |
| Payments | `loans.loan_number` (ILIKE), `borrowers.full_name` (ILIKE), `borrowers.phone_number_normalized` (ILIKE) | `Payments::FilteredListQuery` — add phone |

### Linked Record Navigation Map

| From | To | How |
|------|----|-----|
| Borrower detail | Applications | `Borrowers::LinkedRecordsPanelComponent` → `loan_application_path` ✅ |
| Borrower detail | Loans | `Borrowers::LinkedRecordsPanelComponent` → `loan_path` ✅ |
| Application detail | Borrower | Header `borrower_path` link ✅ |
| Application detail | Loan | "Linked loan" section → `loan_path` ✅ |
| Application detail | Other applications/loans | Borrower lending context section ✅ |
| Loan detail | Borrower | Header `borrower_path` link ✅ |
| Loan detail | Application | Header `loan_application_path` link ✅ |
| Loan detail | Payments | Repayment schedule table → `payment_path` ✅ |
| Loan detail | Disbursement invoice | Disbursement section (no dedicated page — inline display) ✅ |
| Payment detail | Loan | `loan_path` link ✅ |
| Payment detail | Borrower | `borrower_path` link ✅ |
| Payment detail | Application | **NEW** — add `loan_application_path` when `loan.loan_application` exists |
| Payment detail | Other payments | **NEW** — add `payments_path(q: loan.loan_number)` |
| Payment detail | Invoice | Inline display of `invoice_number` ✅ |

### Edge Cases

1. **Phone search with partial number:** ILIKE `%partial%` will match substrings of `phone_number_normalized` (e.g., searching "98765" will match "+919876543210"). This is intentional for investigation flows — exact match is only used on the borrowers page.
2. **Phone search on borrowers vs other entities:** Borrowers use exact normalized phone match (`phone_number_normalized = ?`). Loans/applications/payments use ILIKE partial match. This is correct per existing design — borrower lookup needs precision; cross-entity search needs flexibility.
3. **Search + status filter together:** Already works in all controllers. The search form includes hidden fields for active filters. Verify loan applications search form follows the same pattern.
4. **Payment with no linked application:** Some loans may have `loan_application: nil` (the association is optional). The linked application link on payment detail must check `loan.loan_application.present?` before rendering.
5. **Loan with no payments:** The "View all payments for this loan" link on payment detail is only relevant when viewing a payment — the loan detail already shows the repayment schedule inline.
6. **Search with special characters:** `sanitize_sql_like` already handles `%`, `_`, and `\` in search input across all query objects.
7. **Multi-status filter + search:** `status=open,in+progress&q=searchterm` should work together. The controller normalizes status independently from search.

### UX Requirements

- **FR65 consistency:** All four entity list views must have a search form with consistent placement, styling, and behavior. Search fields should use the `q` parameter and `autocomplete: "off"`.
- **Search placeholder guidance (UX-DR5):** Placeholders must indicate which identifiers are searchable: "Phone number or name" for borrowers, "Application number, borrower name, or phone" for applications, etc.
- **Linked-record orientation (UX-DR7, UX-DR8):** Detail pages must make related records clickable and clearly labeled. The admin should never need to memorize an identifier and manually search for it — direct links should be available.
- **WCAG 2.1 Level A:** Search inputs must have visible labels. Links must be keyboard navigable.
- **Desktop-first:** No mobile layout considerations.

### Library / Framework Requirements

- **Rails ~> 8.1** — standard param handling, routing, ILIKE queries.
- **No new gems, no new migrations, no new initializers.**
- **ActiveRecord ILIKE** — already in use across all query objects.
- **Phonelib** — borrower phone normalization already handled by `Borrower.normalize_phone_number`. No changes to normalization needed.

### Previous Story Intelligence (6.2)

- Story 6.2 added multi-status filtering with comma-separated params and filter-context banners. These patterns must be preserved when adding search forms.
- Story 6.2 confirmed that search and multi-status filters work together: `status=active,overdue&q=search_term` — the query composition pattern supports this.
- Story 6.2 established the filter-context banner pattern (`bg-slate-50 border border-slate-200 rounded-lg`) — search should not interfere with these banners.
- Story 6.2 review findings noted duplicated `normalized_status_filter` logic — not in scope for this story, but be aware when reading controllers.
- Story 6.2 added 16 tests and updated 3 existing tests. This story's tests should follow the same assertion patterns.

### Git Intelligence

Recent commits and relevance:
- `0ef8ffe` **Add dashboard drill-in filtered views with multi-status support and filter context.** (Story 6.2) — Established filter-context banners and multi-status patterns.
- `ff3b07d` **Add action-first operational dashboard.** (Story 6.1) — Dashboard infrastructure.
- `7d88ce1` **Add end-to-end repayment lifecycle system tests.** — System test patterns.

**Preferred commit style:** `"Add cross-entity search and linked-record investigation."`

### Non-Goals (Explicit Scope Boundaries)

- **No unified global search page.** Search stays on each entity's existing index page.
- **No full-text search engine.** ILIKE with `sanitize_sql_like` is the project standard.
- **No audit history.** Story 6.4 handles audit trail display.
- **No new ViewComponents.** Search forms and links are inline ERB.
- **No pagination.** Pre-existing deferred item — all index pages load full result sets.
- **No auto-complete or typeahead.** Standard form submission.
- **No Turbo Frames or Stimulus for search.** Standard GET form submission.
- **No changes to borrower search logic.** `Borrowers::LookupQuery` uses deliberate exact-phone / name-ILIKE split.
- **No invoice detail page.** Invoices are displayed inline on loan and payment detail pages.

### Project Structure Notes

- All changes align with existing patterns in `app/queries/`, `app/views/`, `spec/requests/`.
- No new directories or architectural patterns introduced.
- Phone search addition to query objects is a single-line extension to each `search_matches` method.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md:935-956` — Story 6.3 acceptance criteria]
- [Source: `_bmad-output/planning-artifacts/prd.md:506-507` — FR65: Search across entities by primary identifiers]
- [Source: `_bmad-output/planning-artifacts/prd.md:507` — FR66: Investigate linked records from within the product]
- [Source: `_bmad-output/planning-artifacts/prd.md:511` — FR67: Maintain linked records across entities]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Query objects in `app/queries/<domain>/`, no mutations]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Searchable encrypted fields; borrower phone normalization strategy]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md:546-554` — Filter Bar: search field, filters, sort controls, keyboard accessible]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md:578-586` — Linked-Record Relationship Panel specification]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md:696-702` — Search and Filtering consistency patterns]
- [Source: `_bmad-output/implementation-artifacts/6-2-drill-from-dashboard-into-filtered-operational-views.md` — Previous story patterns and learnings]
- [Source: `app/queries/loans/filtered_list_query.rb:38-44` — Existing loan search pattern]
- [Source: `app/queries/loan_applications/filtered_list_query.rb:37-43` — Existing application search pattern]
- [Source: `app/queries/payments/filtered_list_query.rb:82-89` — Existing payment search pattern]
- [Source: `app/queries/borrowers/lookup_query.rb` — Deliberate exact phone vs ILIKE name split]
- [Source: `app/views/borrowers/index.html.erb:24-45` — Canonical search form pattern]
- [Source: `app/views/loans/show.html.erb:71-76` — Linked application link pattern]
- [Source: `app/views/payments/show.html.erb:144-148` — Existing loan link on payment detail]

## Dev Agent Record

### Agent Model Used

Opus 4.6

### Debug Log References

None — all tasks completed without halting conditions.

### Completion Notes List

- Task 1 was already complete from a prior story — the loan applications search form, controller support, and empty state were already fully implemented.
- Tasks 2 & 3: Extended all three `FilteredListQuery` classes to include `borrowers.phone_number_normalized ILIKE :query` in their search_matches methods. Updated search labels and placeholders across all four entity index pages to indicate phone search support.
- Task 4: Added a "Linked records" section to the loan detail page with links to borrower, application, and filtered payments view.
- Task 5: Verified all linked-record navigation already works on the loan application detail page — no changes needed.
- Task 6: Added linked application link and "View all payments for this loan" link to the payment detail page.
- Task 7: Verified all four entity detail pages follow consistent header patterns with breadcrumb context support.
- Task 8: Added 11 new request spec tests (6 for loan_applications, 2 for loans, 2 for payments, 1 system test update). All 628 tests pass. Rubocop clean on all Ruby files.
- Also fixed a system test (`loan_application_workflow_spec.rb`) that referenced the old search label.

### Change Log

- 2026-04-18: Implemented cross-entity phone search, linked-record navigation, and search consistency (Story 6.3)

### File List

- `app/queries/loans/filtered_list_query.rb` — Added phone_number_normalized ILIKE to search_matches
- `app/queries/loan_applications/filtered_list_query.rb` — Added phone_number_normalized ILIKE to search_matches
- `app/queries/payments/filtered_list_query.rb` — Added phone_number_normalized ILIKE to search_matches
- `app/views/loan_applications/index.html.erb` — Updated search label and placeholder to include phone
- `app/views/loans/index.html.erb` — Updated search label and placeholder to include phone
- `app/views/payments/index.html.erb` — Updated search label and placeholder to include phone
- `app/views/loans/show.html.erb` — Added "Linked records" section with borrower, application, and payments links
- `app/views/payments/show.html.erb` — Added linked application link and "View all payments for this loan" link
- `spec/requests/loan_applications_spec.rb` — Added 6 tests (phone search, application number search, combined search+status, empty state, hidden field preservation)
- `spec/requests/loans_spec.rb` — Added 3 tests (phone search, linked application link, view all payments link)
- `spec/requests/payments_spec.rb` — Added 4 tests (phone search, combined search+view, linked application link, view all payments link)
- `spec/system/loan_application_workflow_spec.rb` — Updated search label reference to match new placeholder text
