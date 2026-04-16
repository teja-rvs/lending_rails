# Story 4.3: Complete Loan Documentation and Manage Supporting Documents

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want to complete documentation and manage supporting files before disbursement,
So that I can satisfy the required readiness stage without losing document history.

## Acceptance Criteria

1. **Given** a loan is approved but not ready for disbursement
   **When** the admin enters the documentation stage
   **Then** the system treats documentation as a distinct operational stage
   **And** the loan cannot bypass it silently

2. **Given** the admin needs to attach supporting documents
   **When** they upload a document to the lending record
   **Then** the system stores the upload against the appropriate record
   **And** the document becomes part of the operational history

3. **Given** a document must be replaced or reuploaded
   **When** the admin uploads a new version
   **Then** the system preserves the historical document context
   **And** treats the new upload as the latest active version rather than overwriting history

## Tasks / Subtasks

- [x] Task 1: Install Active Storage and add `active_storage_validations` gem (AC: #2)
  - [x] 1.1 Run `bin/rails active_storage:install` to generate Active Storage migration
  - [x] 1.2 Run migrations in both development and test environments
  - [x] 1.3 Add `gem "active_storage_validations", "~> 3.0"` to Gemfile and `bundle install`
  - [x] 1.4 Verify `db/schema.rb` now contains `active_storage_blobs`, `active_storage_attachments`, and `active_storage_variant_records` tables
- [x] Task 2: Create `DocumentUpload` model and migration (AC: #2, #3)
  - [x] 2.1 Create migration for `document_uploads` table with UUID PK, polymorphic `documentable` (type + id), `file_name` (string, not null), `description` (text, nullable), `status` (string, not null, default "active"), `superseded_at` (datetime, nullable), `superseded_by_id` (UUID FK to self, nullable), `uploaded_by_id` (UUID FK to users, not null), timestamps
  - [x] 2.2 Add indexes: `documentable` polymorphic composite, `status`, `uploaded_by_id`, `superseded_by_id`
  - [x] 2.3 Add FK constraints: `uploaded_by_id` references `users`, `superseded_by_id` references `document_uploads`
  - [x] 2.4 Create `DocumentUpload` model with `belongs_to :documentable, polymorphic: true`, `belongs_to :uploaded_by, class_name: "User"`, `belongs_to :superseded_by, class_name: "DocumentUpload", optional: true`, `has_one_attached :file`, `has_paper_trail`
  - [x] 2.5 Add validations: `file_name` presence, `status` presence + inclusion in `STATUSES`, `file` attached validation using `active_storage_validations`, content type allowlist (PDF, images, Word docs, spreadsheets), max size 10MB
  - [x] 2.6 Add `STATUSES = ["active", "superseded"].freeze` constant
  - [x] 2.7 Add scopes: `scope :active, -> { where(status: "active") }`, `scope :superseded, -> { where(status: "superseded") }`, `scope :ordered, -> { order(created_at: :desc) }`
  - [x] 2.8 Add `#active?` and `#superseded?` convenience methods
  - [x] 2.9 Run migration in both development and test environments
- [x] Task 3: Add `has_many :document_uploads` association to `Loan` model (AC: #2)
  - [x] 3.1 Add `has_many :document_uploads, as: :documentable, dependent: :restrict_with_exception` to `Loan`
  - [x] 3.2 Add `#active_documents` convenience method: `document_uploads.active.ordered`
  - [x] 3.3 Add `#has_documents?` convenience: `document_uploads.active.exists?`
  - [x] 3.4 Add `#documentation_uploadable?` helper: true when loan is in a pre-disbursement state (same states as `editable_details?`)
- [x] Task 4: Create `Documents::Upload` service (AC: #2)
  - [x] 4.1 Implement following established `Result` struct pattern with `success?`, `blocked?` methods
  - [x] 4.2 Accept `documentable:`, `file:`, `file_name:`, `description:`, `uploaded_by:` parameters
  - [x] 4.3 Guard: return blocked result if documentable does not respond to `documentation_uploadable?` or returns false
  - [x] 4.4 Use `documentable.with_lock` for thread safety
  - [x] 4.5 Create `DocumentUpload` with `status: "active"`, attach the file via Active Storage
  - [x] 4.6 Return document_upload on success; return validation errors on failure
- [x] Task 5: Create `Documents::ReplaceActiveVersion` service (AC: #3)
  - [x] 5.1 Implement following established `Result` struct pattern
  - [x] 5.2 Accept `existing_document:`, `file:`, `file_name:` (optional, defaults to existing), `description:` (optional), `uploaded_by:` parameters
  - [x] 5.3 Guard: return blocked result if the parent documentable is not uploadable
  - [x] 5.4 Guard: return blocked result if existing_document is already superseded
  - [x] 5.5 Use `existing_document.documentable.with_lock` for thread safety
  - [x] 5.6 In a transaction: mark existing document as `superseded` (set `status`, `superseded_at`), create new document with `status: "active"`, set `superseded_by_id` on old document to new document's ID, attach file
  - [x] 5.7 Return new document_upload on success
- [x] Task 6: Create `DocumentsController` (AC: #2, #3)
  - [x] 6.1 Create `app/controllers/documents_controller.rb` with `create` and `replace` actions
  - [x] 6.2 `create`: find parent loan via `Loan.find(params[:loan_id])`, call `Documents::Upload`, redirect on success with flash, re-render loan show on failure
  - [x] 6.3 `replace`: find `DocumentUpload.find(params[:id])`, call `Documents::ReplaceActiveVersion`, redirect on success with flash
  - [x] 6.4 Follow thin-controller pattern: find → service.call → redirect + flash
  - [x] 6.5 Strong params: permit `:file`, `:file_name`, `:description`
- [x] Task 7: Add `complete_documentation` action to `LoansController` (AC: #1)
  - [x] 7.1 Add `complete_documentation` member action following the exact `begin_documentation` pattern
  - [x] 7.2 Use `@loan.with_lock`, check `@loan.may_complete_documentation?`, call `@loan.complete_documentation!`
  - [x] 7.3 Redirect with success flash on transition, alert flash if invalid state
  - [x] 7.4 Add `complete_documentation` to `before_action :set_loan` list
- [x] Task 8: Update routes (AC: #1, #2, #3)
  - [x] 8.1 Add `patch :complete_documentation` to loans member block (alongside `begin_documentation`)
  - [x] 8.2 Nest document routes under loans: `resources :documents, only: :create, controller: "documents"` inside the loans block
  - [x] 8.3 Add standalone document route for replace: `resources :documents, only: [] do member do patch :replace end end` (or nest replacement under loans)
- [x] Task 9: Expand loan show page with documentation section and document management UI (AC: #1, #2, #3)
  - [x] 9.1 Add a "Loan documentation" section between the loan header/lifecycle section and the pre-disbursement details form
  - [x] 9.2 When loan is in `documentation_in_progress`: show a "Complete documentation" button (primary action with turbo_confirm) alongside the document upload form
  - [x] 9.3 Document upload form: file input (`direct_upload: true` for performance), file_name text field, optional description textarea, submit button — only shown when `@loan.documentation_uploadable?`
  - [x] 9.4 Document list: show all active documents with file name, description, upload date, uploaded by, download link, and a "Replace" action button for each
  - [x] 9.5 Show superseded documents in a collapsible "Document history" section with muted styling — each showing file name, superseded date, and "superseded by" reference
  - [x] 9.6 Show a locked callout when loan is post-disbursement: "Documents can no longer be uploaded after disbursement."
  - [x] 9.7 When no documents exist, show an informational empty state: "No documents uploaded yet."
  - [x] 9.8 Document replace flow: clicking "Replace" shows a file input form (inline or Turbo Frame) to upload the replacement file
- [x] Task 10: Preload associations in controller for N+1 prevention (AC: #2)
  - [x] 10.1 Update `set_loan` in `LoansController` to include `document_uploads` with attached file blobs: `Loan.includes(:borrower, :loan_application).find(params[:id])` → add `document_uploads: { file_attachment: :blob }`
- [x] Task 11: Create factory and write tests (AC: #1, #2, #3)
  - [x] 11.1 Create `spec/factories/document_uploads.rb` with proper associations, file attachment via `Rack::Test::UploadedFile` or Active Storage fixture helpers
  - [x] 11.2 Model specs for `DocumentUpload`: validations (file_name presence, status inclusion, file attached), scopes (active, superseded, ordered), associations, `active?`/`superseded?` methods
  - [x] 11.3 Model specs for `Loan`: `has_many :document_uploads`, `active_documents`, `has_documents?`, `documentation_uploadable?`
  - [x] 11.4 Service specs for `Documents::Upload`: successful upload in pre-disbursement state, blocked in post-disbursement state, validation failure on missing file, validation failure on invalid content type
  - [x] 11.5 Service specs for `Documents::ReplaceActiveVersion`: successful replacement marks old as superseded, creates new active, sets superseded_by_id; blocked when document already superseded; blocked when parent is post-disbursement
  - [x] 11.6 Request specs: `POST /loans/:id/documents` creates document; `PATCH /documents/:id/replace` replaces document; `PATCH /loans/:id/complete_documentation` transitions state; auth guards on all new endpoints
  - [x] 11.7 System specs: end-to-end flow — navigate to loan → begin documentation → upload document → verify document appears → replace document → verify history preserved → complete documentation → verify state transition to ready_for_disbursement → verify upload locked

## Dev Notes

### Critical Architecture Constraints

- **Domain services own all mutations.** `Documents::Upload` and `Documents::ReplaceActiveVersion` handle document operations — controllers must not create or update documents directly. [Source: architecture.md — "Domain logic boundaries"]
- **AASM for state machines.** The `complete_documentation` event is already defined on the Loan AASM: `transitions from: :documentation_in_progress, to: :ready_for_disbursement`. Do NOT modify the AASM definition. [Source: architecture.md — Core Architectural Decisions; Loan model]
- **Service result pattern.** Follow the established `Result = Struct.new(:entity, :error, keyword_init: true)` with `success?` and `blocked?` methods. See `Loans::UpdateDetails` for the canonical example. [Source: architecture.md — Service boundaries]
- **`with_lock` for transitions.** All state-changing services must acquire a pessimistic lock. [Source: architecture.md — Concurrency patterns]
- **`paper_trail` for audit.** Add `has_paper_trail` to `DocumentUpload` for version tracking. PaperTrail whodunnit is already configured in `ApplicationController`. [Source: prd.md — FR68, FR69]
- **UUID primary keys.** All domain entities use UUID PKs. The `document_uploads` table must use `id: :uuid`. [Source: architecture.md — UUID identity strategy]
- **No hard delete.** Never destroy document upload records. Superseded documents remain in the system. [Source: prd.md — FR70]
- **Pre-disbursement = uploadable window.** Documents can be uploaded while the loan is in `created`, `documentation_in_progress`, or `ready_for_disbursement`. After disbursement (state `active` or later), document uploads become locked. [Source: prd.md — FR71, FR33]
- **Active Storage for files.** Use Rails Active Storage (`has_one_attached :file`) for document storage. The Disk service is configured for development and test. [Source: architecture.md — Infrastructure]
- **Polymorphic documentable.** Per architecture, `DocumentUpload` uses a polymorphic `documentable` association to support future attachment to applications or other entities. For this story, only `Loan` is the documentable target. [Source: architecture.md — `document_upload.rb`]
- **No `double_entry` postings.** This story does NOT touch double-entry accounting. That belongs to Story 4.5 (disbursement). [Source: architecture.md — "Only money-moving domain services should create double_entry postings"]

### Active Storage Setup

Active Storage tables have NOT been installed yet. The migration must be run as part of this story:

```bash
bin/rails active_storage:install
bin/rails db:migrate
RAILS_ENV=test bin/rails db:migrate
```

This creates three tables: `active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records`.

Active Storage is already available via `rails/all` in this Rails 8.1 app. The `storage.yml` config defines `test` (tmp/storage) and `local` (storage/) disk services. Environment configs already set `active_storage.service` to the appropriate backend.

### `active_storage_validations` Gem

Add to Gemfile:

```ruby
gem "active_storage_validations", "~> 3.0"
```

Latest stable version: **3.0.4** (released March 2026). Use for content type and file size validations on `DocumentUpload`:

```ruby
validates :file, attached: true,
  content_type: {
    in: %w[
      application/pdf
      image/png image/jpeg image/gif image/webp
      application/msword
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/vnd.ms-excel
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      text/plain text/csv
    ],
    message: "must be a PDF, image, Word document, spreadsheet, or text file"
  },
  size: { less_than: 10.megabytes, message: "must be less than 10MB" }
```

### DocumentUpload Model Design

| Column | Type | Nullable | Notes |
|--------|------|----------|-------|
| `id` | uuid | no | PK, `gen_random_uuid()` |
| `documentable_type` | string | no | Polymorphic type (e.g., "Loan") |
| `documentable_id` | uuid | no | Polymorphic FK |
| `file_name` | string | no | Display label for the document |
| `description` | text | yes | Optional notes about the document |
| `status` | string | no | "active" or "superseded", default "active" |
| `superseded_at` | datetime | yes | When this document was replaced |
| `superseded_by_id` | uuid | yes | FK to the replacement document_upload |
| `uploaded_by_id` | uuid | no | FK to users |
| `created_at` | datetime | no | |
| `updated_at` | datetime | no | |

File is stored via Active Storage `has_one_attached :file` (no column in this table — Active Storage uses its own `active_storage_attachments` join table).

### DocumentUpload Model Implementation

File: `app/models/document_upload.rb`

```ruby
class DocumentUpload < ApplicationRecord
  STATUSES = ["active", "superseded"].freeze

  belongs_to :documentable, polymorphic: true
  belongs_to :uploaded_by, class_name: "User"
  belongs_to :superseded_by, class_name: "DocumentUpload", optional: true

  has_one_attached :file
  has_paper_trail

  normalizes :file_name, with: ->(value) { value.to_s.squish.presence }
  normalizes :description, with: ->(value) { value.to_s.squish.presence }
  normalizes :status, with: ->(value) { value.to_s.squish.presence&.downcase }

  validates :file_name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :file, attached: true,
    content_type: {
      in: %w[
        application/pdf
        image/png image/jpeg image/gif image/webp
        application/msword
        application/vnd.openxmlformats-officedocument.wordprocessingml.document
        application/vnd.ms-excel
        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
        text/plain text/csv
      ],
      message: "must be a PDF, image, Word document, spreadsheet, or text file"
    },
    size: { less_than: 10.megabytes, message: "must be less than 10MB" }

  scope :active, -> { where(status: "active") }
  scope :superseded, -> { where(status: "superseded") }
  scope :ordered, -> { order(created_at: :desc) }

  def active?
    status == "active"
  end

  def superseded?
    status == "superseded"
  end
end
```

### Service: `Documents::Upload`

File: `app/services/documents/upload.rb`

```ruby
module Documents
  class Upload < ApplicationService
    Result = Struct.new(:document_upload, :error, keyword_init: true) do
      def success? = error.blank? && document_upload&.errors&.none?
      def blocked? = error.present?
    end

    def initialize(documentable:, file:, file_name:, description: nil, uploaded_by:)
      @documentable = documentable
      @file = file
      @file_name = file_name
      @description = description
      @uploaded_by = uploaded_by
    end

    def call
      unless documentable.respond_to?(:documentation_uploadable?) && documentable.documentation_uploadable?
        return Result.new(document_upload: nil, error: "Documents cannot be uploaded to this record in its current state.")
      end

      documentable.with_lock do
        unless documentable.documentation_uploadable?
          return Result.new(document_upload: nil, error: "Documents cannot be uploaded to this record in its current state.")
        end

        doc = documentable.document_uploads.build(
          file_name: file_name,
          description: description,
          status: "active",
          uploaded_by: uploaded_by
        )
        doc.file.attach(file)
        doc.save

        Result.new(document_upload: doc)
      end
    end

    private
      attr_reader :documentable, :file, :file_name, :description, :uploaded_by
  end
end
```

### Service: `Documents::ReplaceActiveVersion`

File: `app/services/documents/replace_active_version.rb`

```ruby
module Documents
  class ReplaceActiveVersion < ApplicationService
    Result = Struct.new(:document_upload, :error, keyword_init: true) do
      def success? = error.blank? && document_upload&.errors&.none?
      def blocked? = error.present?
    end

    def initialize(existing_document:, file:, file_name: nil, description: nil, uploaded_by:)
      @existing_document = existing_document
      @file = file
      @file_name = file_name
      @description = description
      @uploaded_by = uploaded_by
    end

    def call
      return Result.new(document_upload: nil, error: "This document has already been superseded.") if existing_document.superseded?

      documentable = existing_document.documentable
      unless documentable.respond_to?(:documentation_uploadable?) && documentable.documentation_uploadable?
        return Result.new(document_upload: nil, error: "Documents cannot be modified on this record in its current state.")
      end

      documentable.with_lock do
        unless documentable.documentation_uploadable?
          return Result.new(document_upload: nil, error: "Documents cannot be modified on this record in its current state.")
        end

        new_doc = documentable.document_uploads.build(
          file_name: file_name.presence || existing_document.file_name,
          description: description.presence || existing_document.description,
          status: "active",
          uploaded_by: uploaded_by
        )
        new_doc.file.attach(file)

        ActiveRecord::Base.transaction do
          new_doc.save!
          existing_document.update!(
            status: "superseded",
            superseded_at: Time.current,
            superseded_by: new_doc
          )
        end

        Result.new(document_upload: new_doc)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(document_upload: e.record, error: nil)
    end

    private
      attr_reader :existing_document, :file, :file_name, :description, :uploaded_by
  end
end
```

### Controller: `DocumentsController`

File: `app/controllers/documents_controller.rb`

Follow the thin-controller pattern. Nest under loans for create, use standalone for replace.

```ruby
class DocumentsController < ApplicationController
  def create
    @loan = Loan.find(params[:loan_id])
    result = Documents::Upload.call(
      documentable: @loan,
      file: document_params[:file],
      file_name: document_params[:file_name],
      description: document_params[:description],
      uploaded_by: Current.user
    )

    if result.success?
      redirect_to loan_redirect_path(@loan), notice: "Document '#{result.document_upload.file_name}' uploaded successfully."
    elsif result.blocked?
      redirect_to loan_redirect_path(@loan), alert: result.error
    else
      redirect_to loan_redirect_path(@loan), alert: result.document_upload.errors.full_messages.to_sentence
    end
  end

  def replace
    @document = DocumentUpload.find(params[:id])
    @loan = @document.documentable
    result = Documents::ReplaceActiveVersion.call(
      existing_document: @document,
      file: document_params[:file],
      file_name: document_params[:file_name],
      description: document_params[:description],
      uploaded_by: Current.user
    )

    if result.success?
      redirect_to loan_redirect_path(@loan), notice: "Document replaced. Previous version preserved in history."
    elsif result.blocked?
      redirect_to loan_redirect_path(@loan), alert: result.error
    else
      redirect_to loan_redirect_path(@loan), alert: result.document_upload&.errors&.full_messages&.to_sentence || "Document replacement failed."
    end
  end

  private
    def document_params
      params.require(:document).permit(:file, :file_name, :description)
    end

    def loan_redirect_path(loan)
      if params[:from].present?
        loan_path(loan, from: params[:from])
      else
        loan_path(loan)
      end
    end
end
```

### LoansController: `complete_documentation` Action

Add to `LoansController` following the exact `begin_documentation` pattern:

```ruby
def complete_documentation
  @loan.with_lock do
    if @loan.may_complete_documentation?
      @loan.complete_documentation!
      redirect_to loan_redirect_path, notice: "Documentation completed for #{@loan.loan_number}. Loan is now ready for disbursement."
    else
      redirect_to loan_redirect_path, alert: "This loan cannot complete documentation from its current state."
    end
  end
end
```

Update `before_action :set_loan` to include `complete_documentation`:

```ruby
before_action :set_loan, only: %i[show update begin_documentation complete_documentation]
```

### Routes

```ruby
resources :loans, only: %i[index show update], constraints: { id: UUID_REGEX } do
  member do
    patch :begin_documentation
    patch :complete_documentation
  end
  resources :documents, only: :create, controller: "documents"
end

resources :documents, only: [] do
  member do
    patch :replace
  end
end
```

Where `UUID_REGEX` is the existing regex pattern `/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/`.

### Loan Show Page — Documentation Section

Add a new section **between** the loan header/lifecycle card and the "Pre-disbursement loan details" section. This section handles:

1. **Documentation stage action**: "Complete documentation" button when `@loan.may_complete_documentation?` — styled as primary action with `turbo_confirm` explaining the consequence (moves loan to `ready_for_disbursement`).

2. **Document upload form**: Visible when `@loan.documentation_uploadable?`. Contains:
   - File input with `direct_upload: true`
   - Text field for `file_name` (required)
   - Optional textarea for `description`
   - Submit button

3. **Active documents list**: Table/list of active documents showing file name (linked to download via `rails_blob_path(doc.file, disposition: "attachment")`), description, upload date (`created_at`), uploaded by (user email). Each row has a "Replace" button that reveals/navigates to a replacement form.

4. **Document history**: Collapsible section showing superseded documents with muted styling — file name, superseded date, "Replaced by: [new doc name]" reference.

5. **Locked state callout**: When loan is post-disbursement (`!@loan.documentation_uploadable?` and not in the editable states), show: "Documents can no longer be uploaded after disbursement."

6. **Empty state**: When no documents exist: "No documents have been uploaded yet."

### File Upload — UX Considerations

- Use `direct_upload: true` on the file field to prevent slow uploads from consuming Puma workers.
- Show a clear progress indication via Turbo. Active Storage direct uploads emit JS events that can be used for progress feedback.
- The form should prevent submission without a file selected.
- Content type and size errors from `active_storage_validations` surface through model validation and appear in the redirect flash.
- Follow the product's calm, trust-oriented feedback tone for upload success/failure messages.

### N+1 Prevention

Update `set_loan` in `LoansController` to eager load documents:

```ruby
def set_loan
  @loan = Loan.includes(:borrower, :loan_application, document_uploads: { file_attachment: :blob })
              .find(params[:id])
end
```

### Previous Story Intelligence

From Story 4.2 (prepare and review loan details):
- **Pattern:** `Loans::UpdateDetails` uses `Result` struct with `success?`, `blocked?`, `locked?`. Document services should follow the same Result pattern (skip `locked?` unless needed — use `blocked?` for state guards).
- **Review finding applied:** Interest mode switching was fixed in 4.2 with `normalized_attributes` in the service. No interaction with document upload.
- **Controller pattern:** `find → service.call → redirect + flash`. `DocumentsController` should follow the same thin pattern.
- **`begin_documentation`** action already exists — `complete_documentation` must mirror it exactly.
- **Testing:** 226 examples passing after Story 4.2. Do not break existing tests.
- **SimpleCov:** The repo enforces 80% minimum coverage per run. Focused spec runs may exit non-zero under SimpleCov; validate with the full suite.
- **PostgreSQL/Docker:** Ensure DB is running before test suite.
- **Stimulus controllers:** The `interest_mode_toggle_controller.js` pattern shows how Stimulus is wired. If a file upload progress controller is needed, follow the same registration pattern via `eagerLoadControllersFrom`.

From Story 4.1 (create loan from approved application):
- **AASM pattern:** `may_complete_documentation?` and `complete_documentation!` are already defined on the model. Use `may_*?` for view guards and `*!` (bang) for transitions.
- **`with_lock`:** All state transitions use pessimistic locking inside the controller action.

### Git Intelligence

Recent commits follow the pattern: `Add <feature description>.` with focused, single-story changes. The last commit (`f6eb7d0`) touched 19 files for Story 4.2. Keep changes focused on this story's scope.

### Project Structure Notes

Files to create:
- `db/migrate/YYYYMMDDHHMMSS_create_active_storage_tables.active_storage.rb` (generated by `rails active_storage:install`)
- `db/migrate/YYYYMMDDHHMMSS_create_document_uploads.rb`
- `app/models/document_upload.rb`
- `app/services/documents/upload.rb`
- `app/services/documents/replace_active_version.rb`
- `app/controllers/documents_controller.rb`
- `spec/factories/document_uploads.rb`
- `spec/models/document_upload_spec.rb`
- `spec/services/documents/upload_spec.rb`
- `spec/services/documents/replace_active_version_spec.rb`
- `spec/requests/documents_spec.rb`

Files to modify:
- `Gemfile` — add `active_storage_validations`
- `app/models/loan.rb` — add `has_many :document_uploads`, helper methods
- `app/controllers/loans_controller.rb` — add `complete_documentation` action, update `set_loan` eager loading
- `config/routes.rb` — add `complete_documentation`, document routes
- `app/views/loans/show.html.erb` — add documentation section with upload form, document list, history, complete_documentation button
- `db/schema.rb` — auto-updated by migrations
- `spec/factories/loans.rb` — no changes needed (existing traits cover all states)
- `spec/models/loan_spec.rb` — add specs for new associations and helper methods
- `spec/requests/loans_spec.rb` — add spec for `complete_documentation` endpoint
- `spec/system/loan_detail_flow_spec.rb` — extend with document upload and documentation completion flow

Files NOT to touch:
- Do not modify `Loans::CreateFromApplication` or `LoanApplications::Approve`
- Do not modify `Loans::UpdateDetails` (loan detail editing is separate from document management)
- Do not add disbursement readiness checks (that's Story 4.4)
- Do not add disbursement execution or `double_entry` postings (that's Story 4.5)
- Do not modify the AASM state/event definitions (fully defined in Story 4.1)
- Do not add document upload to borrowers or applications (future scope beyond this story)

### Testing Requirements

- **Model specs for `DocumentUpload`:** validations (file_name presence, status inclusion, file attached, content type allowlist, max size), scopes (active, superseded, ordered), associations (belongs_to documentable polymorphic, belongs_to uploaded_by, belongs_to superseded_by optional), `active?`/`superseded?` methods, `paper_trail` versioning
- **Model specs for `Loan` (additions):** `has_many :document_uploads` association, `active_documents` returns only active ordered docs, `has_documents?` returns true/false, `documentation_uploadable?` returns true for pre-disbursement states and false for post-disbursement
- **Service specs for `Documents::Upload`:** Successful upload in `documentation_in_progress` state; successful upload in `created` state; blocked upload in `active` (post-disbursement) state; validation failure on missing file; validation failure on oversized file; validation failure on disallowed content type; validation failure on missing file_name
- **Service specs for `Documents::ReplaceActiveVersion`:** Successful replacement creates new active document; old document becomes superseded with correct `superseded_at` and `superseded_by_id`; blocked when existing document is already superseded; blocked when parent loan is post-disbursement; file_name defaults to existing when not provided
- **Request specs for `DocumentsController`:** `POST /loans/:id/documents` creates document and redirects; `POST /loans/:id/documents` with invalid file redirects with error flash; `PATCH /documents/:id/replace` replaces document; auth guards on all new endpoints
- **Request specs for `LoansController` (additions):** `PATCH /loans/:id/complete_documentation` transitions from `documentation_in_progress` to `ready_for_disbursement`; blocked from other states; auth guard
- **System specs:** Navigate from workspace → loans list → open loan → begin documentation → upload a document (PDF) → verify document appears in active list → replace document → verify old doc appears in history as superseded → verify new doc is active → complete documentation → verify state is `ready_for_disbursement` → verify upload form is hidden (still uploadable in ready_for_disbursement) → navigate back to list

### References

- [Source: architecture.md — Document handling: `document_upload.rb`, `documents_controller.rb`, `Documents::Upload`, `Documents::ReplaceActiveVersion`]
- [Source: architecture.md — Active Storage with `active_storage_validations` for document uploads]
- [Source: architecture.md — Polymorphic `documentable` association pattern]
- [Source: architecture.md — Service boundaries and Result pattern]
- [Source: architecture.md — Pre-disbursement editable vs post-disbursement locked]
- [Source: prd.md — FR33: Documentation as a distinct stage after approval and before disbursement]
- [Source: prd.md — FR75: Admin can upload generic documents to lending records]
- [Source: prd.md — FR76: System preserves rejected document uploads and treats reuploads as latest active version]
- [Source: prd.md — FR70: No hard deletion of operational or financial records]
- [Source: prd.md — FR71: Prevent editing of loan records after disbursement]
- [Source: epics.md — Epic 4, Story 4.3 acceptance criteria]
- [Source: ux-design-specification.md — Form Patterns, Feedback Patterns, Button Hierarchy, Blocked-State Callout]

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- `bin/rails active_storage:install`
- `bin/rails db:migrate`
- `RAILS_ENV=test bin/rails db:migrate` (migration applied successfully; command exits non-zero in isolation because SimpleCov enforces coverage when booting the test environment)
- `bundle exec rspec` (270 examples, 0 failures)
- `bundle exec rubocop app/models/document_upload.rb app/models/loan.rb app/services/documents/upload.rb app/services/documents/replace_active_version.rb app/controllers/documents_controller.rb app/controllers/loans_controller.rb config/routes.rb spec/models/document_upload_spec.rb spec/models/loan_spec.rb spec/services/documents/upload_spec.rb spec/services/documents/replace_active_version_spec.rb spec/requests/documents_spec.rb spec/requests/loans_spec.rb spec/system/loan_detail_flow_spec.rb`

### Completion Notes List

- Installed Active Storage, added `active_storage_validations`, and created the `document_uploads` table with UUID identities, audit history, and replacement linkage.
- Added `DocumentUpload`, loan document associations/helpers, `Documents::Upload`, and `Documents::ReplaceActiveVersion` to preserve active-versus-superseded document history behind thin controllers.
- Expanded the loan detail page with the documentation stage UI, direct-upload forms, replacement history, locked post-disbursement messaging, and the `complete_documentation` lifecycle action.
- Added model, service, request, and system coverage for uploads, replacements, lifecycle transitions, and authentication guards; full RSpec suite passes.

### File List

- `Gemfile`
- `Gemfile.lock`
- `_bmad-output/implementation-artifacts/4-3-complete-loan-documentation-and-manage-supporting-documents.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `app/controllers/documents_controller.rb`
- `app/controllers/loans_controller.rb`
- `app/javascript/application.js`
- `app/models/document_upload.rb`
- `app/models/loan.rb`
- `app/services/documents/replace_active_version.rb`
- `app/services/documents/upload.rb`
- `app/views/loans/show.html.erb`
- `config/importmap.rb`
- `config/routes.rb`
- `db/migrate/20260415161147_create_active_storage_tables.active_storage.rb`
- `db/migrate/20260415172000_create_document_uploads.rb`
- `db/schema.rb`
- `spec/factories/document_uploads.rb`
- `spec/fixtures/files/invalid.exe`
- `spec/fixtures/files/replacement.pdf`
- `spec/fixtures/files/sample.pdf`
- `spec/models/document_upload_spec.rb`
- `spec/models/loan_spec.rb`
- `spec/requests/documents_spec.rb`
- `spec/requests/loans_spec.rb`
- `spec/services/documents/replace_active_version_spec.rb`
- `spec/services/documents/upload_spec.rb`
- `spec/system/loan_detail_flow_spec.rb`

### Change Log

- 2026-04-15: Implemented Story 4.3 with Active Storage-backed document uploads, replacement history preservation, documentation-stage UI/actions, and end-to-end automated coverage.

### Status

done
