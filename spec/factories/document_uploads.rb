FactoryBot.define do
  factory :document_upload do
    association :documentable, factory: :loan
    association :uploaded_by, factory: :user
    file_name { "Supporting document" }
    description { "Borrower submitted a supporting document." }
    status { "active" }
    superseded_at { nil }
    superseded_by { nil }

    after(:build) do |document_upload|
      next if document_upload.file.attached?

      document_upload.file.attach(
        io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/sample.pdf"))),
        filename: "supporting-document.pdf",
        content_type: "application/pdf"
      )
    end
  end
end
