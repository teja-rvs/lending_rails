require "rails_helper"

RSpec.describe "Documents", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123!" }
  end

  def uploaded_file(name = "sample.pdf", content_type = "application/pdf")
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/#{name}"),
      content_type
    )
  end

  it "redirects unauthenticated visitors away from document creation" do
    post loan_documents_path(create(:loan))

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from document replacement" do
    patch replace_document_path(create(:document_upload))

    expect(response).to redirect_to(new_session_path)
  end

  it "creates a document for a signed-in admin" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :documentation_in_progress, :with_details)

    sign_in_as(user)

    expect do
      post loan_documents_path(loan), params: {
        from: "loans",
        document: {
          file: uploaded_file,
          file_name: "Borrower ID",
          description: "Government issued ID."
        }
      }
    end.to change(DocumentUpload, :count).by(1)

    expect(response).to redirect_to(loan_path(loan, from: "loans"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Document 'Borrower ID' uploaded successfully."
    assert_select "a", text: "Borrower ID"
  end

  it "re-renders the loan detail page when document validation fails" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :documentation_in_progress, :with_details)

    sign_in_as(user)

    post loan_documents_path(loan), params: {
      document: {
        file: uploaded_file("invalid.exe", "application/octet-stream"),
        file_name: "Executable",
        description: "Should fail."
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    assert_select "h2", text: "Loan documentation"
    assert_select "p", text: "Document could not be uploaded."
    assert_select "li", text: "File must be a PDF, image, Word document, spreadsheet, or text file"
  end

  it "replaces an existing document for a signed-in admin" do
    user = create(:user, email_address: "admin@example.com")
    document = create(:document_upload, documentable: create(:loan, :documentation_in_progress))

    sign_in_as(user)

    patch replace_document_path(document), params: {
      from: "loans",
      document: {
        file: uploaded_file("replacement.pdf"),
        file_name: "Updated document",
        description: "Updated scan."
      }
    }

    expect(response).to redirect_to(loan_path(document.documentable, from: "loans"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Document replaced. Previous version preserved in history."
    expect(document.reload).to be_superseded
    expect(document.superseded_by.file_name).to eq("Updated document")
  end
end
