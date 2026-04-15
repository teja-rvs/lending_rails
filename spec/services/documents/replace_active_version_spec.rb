require "rails_helper"

RSpec.describe Documents::ReplaceActiveVersion do
  describe ".call" do
    def uploaded_file(name = "replacement.pdf", content_type = "application/pdf")
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/#{name}"),
        content_type
      )
    end

    it "creates a new active document and supersedes the existing one" do
      loan = create(:loan, :documentation_in_progress)
      existing_document = create(
        :document_upload,
        documentable: loan,
        file_name: "Original document",
        description: "First upload."
      )

      result = described_class.call(
        existing_document: existing_document,
        file: uploaded_file,
        file_name: "Replacement document",
        description: "Updated upload.",
        uploaded_by: create(:user)
      )

      expect(result).to be_success
      expect(result).not_to be_blocked
      expect(result.document_upload).to be_persisted
      expect(result.document_upload.status).to eq("active")
      expect(result.document_upload.file_name).to eq("Replacement document")
      expect(existing_document.reload).to be_superseded
      expect(existing_document.superseded_at).to be_present
      expect(existing_document.superseded_by).to eq(result.document_upload)
    end

    it "defaults the replacement file name to the existing document name" do
      existing_document = create(:document_upload, file_name: "Original document")

      result = described_class.call(
        existing_document: existing_document,
        file: uploaded_file,
        uploaded_by: create(:user)
      )

      expect(result).to be_success
      expect(result.document_upload.file_name).to eq("Original document")
    end

    it "blocks replacing a document that is already superseded" do
      existing_document = create(
        :document_upload,
        status: "superseded",
        superseded_at: Time.current
      )

      result = described_class.call(
        existing_document: existing_document,
        file: uploaded_file,
        uploaded_by: create(:user)
      )

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("This document has already been superseded.")
    end

    it "blocks replacements after the parent documentable is no longer uploadable" do
      existing_document = create(:document_upload, documentable: create(:loan, :active))

      result = described_class.call(
        existing_document: existing_document,
        file: uploaded_file,
        uploaded_by: create(:user)
      )

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("Documents cannot be modified on this record in its current state.")
    end
  end
end
