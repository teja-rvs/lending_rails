require "rails_helper"

RSpec.describe Documents::Upload do
  describe ".call" do
    def uploaded_file(name = "sample.pdf", content_type = "application/pdf")
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/#{name}"),
        content_type
      )
    end

    it "uploads a document while a loan is in documentation_in_progress" do
      loan = create(:loan, :documentation_in_progress)
      user = create(:user)

      result = described_class.call(
        documentable: loan,
        file: uploaded_file,
        file_name: "Borrower ID",
        description: "Government issued ID.",
        uploaded_by: user
      )

      expect(result).to be_success
      expect(result).not_to be_blocked
      expect(result.document_upload).to be_persisted
      expect(result.document_upload.documentable).to eq(loan)
      expect(result.document_upload.uploaded_by).to eq(user)
      expect(result.document_upload.file).to be_attached
      expect(result.document_upload.status).to eq("active")
    end

    it "uploads a document while a loan is still created" do
      loan = create(:loan, :created)
      user = create(:user)

      result = described_class.call(
        documentable: loan,
        file: uploaded_file,
        file_name: "Sanction letter",
        description: nil,
        uploaded_by: user
      )

      expect(result).to be_success
      expect(result.document_upload).to be_persisted
    end

    it "blocks uploads after disbursement" do
      loan = create(:loan, :active)

      result = described_class.call(
        documentable: loan,
        file: uploaded_file,
        file_name: "Borrower ID",
        description: nil,
        uploaded_by: create(:user)
      )

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("Documents cannot be uploaded to this record in its current state.")
      expect(loan.document_uploads).to be_empty
    end

    it "returns validation errors when the file is missing" do
      result = described_class.call(
        documentable: create(:loan, :documentation_in_progress),
        file: nil,
        file_name: "Borrower ID",
        description: nil,
        uploaded_by: create(:user)
      )

      expect(result).not_to be_success
      expect(result).not_to be_blocked
      expect(result.document_upload.errors[:file]).to include("can't be blank")
    end

    it "returns validation errors when the file is too large" do
      oversized_file = Tempfile.new([ "oversized", ".pdf" ])
      oversized_file.binmode
      oversized_file.write("a" * (10.megabytes + 1))
      oversized_file.rewind

      result = described_class.call(
        documentable: create(:loan, :documentation_in_progress),
        file: Rack::Test::UploadedFile.new(oversized_file.path, "application/pdf"),
        file_name: "Large file",
        description: nil,
        uploaded_by: create(:user)
      )

      expect(result).not_to be_success
      expect(result.document_upload.errors[:file]).to include("must be less than 10MB")
    ensure
      oversized_file&.close!
    end

    it "returns validation errors when the content type is not allowed" do
      result = described_class.call(
        documentable: create(:loan, :documentation_in_progress),
        file: uploaded_file("invalid.exe", "application/octet-stream"),
        file_name: "Executable",
        description: nil,
        uploaded_by: create(:user)
      )

      expect(result).not_to be_success
      expect(result.document_upload.errors[:file]).to include("must be a PDF, image, Word document, spreadsheet, or text file")
    end

    it "returns validation errors when file_name is missing" do
      result = described_class.call(
        documentable: create(:loan, :documentation_in_progress),
        file: uploaded_file,
        file_name: "",
        description: nil,
        uploaded_by: create(:user)
      )

      expect(result).not_to be_success
      expect(result.document_upload.errors[:file_name]).to include("can't be blank")
    end
  end
end
