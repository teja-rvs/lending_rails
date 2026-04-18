require "rails_helper"

RSpec.describe DocumentUpload, type: :model do
  subject(:document_upload) { build(:document_upload) }

  it { is_expected.to validate_presence_of(:file_name) }
  it { is_expected.to belong_to(:uploaded_by).class_name("User") }
  it { is_expected.to belong_to(:superseded_by).class_name("DocumentUpload").optional }

  describe "deletion protection" do
    subject { create(:document_upload) }

    it_behaves_like "deletion protected"
  end

  describe "associations" do
    it "belongs to a polymorphic documentable" do
      loan = create(:loan, :documentation_in_progress)
      document = create(:document_upload, documentable: loan)

      expect(document.documentable).to eq(loan)
    end
  end

  describe "validations" do
    it "requires a supported status" do
      document_upload.status = "archived"

      expect(document_upload).not_to be_valid
      expect(document_upload.errors[:status]).to include("is not included in the list")
    end

    it "requires a file attachment" do
      document_upload.file.detach

      expect(document_upload).not_to be_valid
      expect(document_upload.errors[:file]).to include("can't be blank")
    end

    it "rejects unsupported content types" do
      document_upload.file.attach(
        io: StringIO.new("not allowed"),
        filename: "invalid.exe",
        content_type: "application/octet-stream"
      )

      expect(document_upload).not_to be_valid
      expect(document_upload.errors[:file]).to include("must be a PDF, image, Word document, spreadsheet, or text file")
    end

    it "rejects files larger than 10MB" do
      document_upload.file.attach(
        io: StringIO.new("a" * (10.megabytes + 1)),
        filename: "large.pdf",
        content_type: "application/pdf"
      )

      expect(document_upload).not_to be_valid
      expect(document_upload.errors[:file]).to include("must be less than 10MB")
    end
  end

  describe "scopes" do
    it "returns active documents" do
      active_document = create(:document_upload, status: "active")
      create(:document_upload, status: "superseded", superseded_at: Time.current)

      expect(described_class.active).to contain_exactly(active_document)
    end

    it "returns superseded documents" do
      superseded_document = create(:document_upload, status: "superseded", superseded_at: Time.current)
      create(:document_upload, status: "active")

      expect(described_class.superseded).to contain_exactly(superseded_document)
    end

    it "orders documents newest first" do
      older_document = create(:document_upload, created_at: 2.days.ago)
      newer_document = create(:document_upload, created_at: 1.day.ago)

      expect(described_class.ordered).to start_with(newer_document, older_document)
    end
  end

  describe "#active?" do
    it "returns true when the document is active" do
      expect(build(:document_upload, status: "active")).to be_active
    end
  end

  describe "#superseded?" do
    it "returns true when the document is superseded" do
      expect(build(:document_upload, status: "superseded")).to be_superseded
    end
  end

  describe "audit history" do
    it "tracks create and update events with paper trail" do
      document = create(:document_upload)

      expect(document.versions.pluck(:event)).to include("create")

      document.update!(status: "superseded", superseded_at: Time.current)

      expect(document.versions.order(:created_at).pluck(:event).last).to eq("update")
    end
  end
end
