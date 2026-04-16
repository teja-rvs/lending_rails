require "rails_helper"

RSpec.describe "Loans", type: :request do
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

  it "redirects unauthenticated visitors away from the loans list" do
    get loans_path

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from the loan detail page" do
    loan = create(:loan)

    get loan_path(loan)

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from loan updates" do
    loan = create(:loan)

    patch loan_path(loan), params: {
      loan: {
        principal_amount: "45000",
        tenure_in_months: "12",
        repayment_frequency: "monthly",
        interest_mode: "rate",
        interest_rate: "12.5000"
      }
    }

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from begin documentation" do
    loan = create(:loan)

    patch begin_documentation_loan_path(loan)

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from complete documentation" do
    loan = create(:loan, :documentation_in_progress)

    patch complete_documentation_loan_path(loan)

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from attempt disbursement" do
    loan = create(:loan, :ready_for_disbursement, :with_details)

    patch attempt_disbursement_loan_path(loan)

    expect(response).to redirect_to(new_session_path)
  end

  it "renders an empty loans list state for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")

    sign_in_as(user)
    get loans_path

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "Loans | lending_rails"
    assert_select "h1", text: "Loans"
    assert_select "h2", text: "No loans found"
  end

  it "filters the loans list by lifecycle state" do
    user = create(:user, email_address: "admin@example.com")
    matching = create(:loan, :created, loan_number: "LOAN-0101")
    create(:loan, :active, loan_number: "LOAN-0102")

    sign_in_as(user)
    get loans_path, params: { status: "created" }

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{loan_path(matching, from: "loans")}']", text: matching.loan_number
    assert_select "a", text: "LOAN-0102", count: 0
  end

  it "searches the loans list by borrower name" do
    user = create(:user, email_address: "admin@example.com")
    matching_borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    matching = create(:loan, borrower: matching_borrower, loan_number: "LOAN-0111")
    other_borrower = create(:borrower, full_name: "Rahul Singh", phone_number: "91234 56789")
    create(:loan, borrower: other_borrower, loan_number: "LOAN-0222")

    sign_in_as(user)
    get loans_path, params: { q: "Asha" }

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{loan_path(matching, from: "loans")}']", text: matching.loan_number
    assert_select "td", text: "Rahul Singh", count: 0
  end

  it "renders the linked loan lifecycle detail for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    application = create(:loan_application, borrower:, application_number: "APP-0101", status: "approved")
    loan = create(
      :loan,
      borrower:,
      loan_application: application,
      loan_number: "LOAN-2001",
      status: "created",
      borrower_full_name_snapshot: "Asha Patel",
      borrower_phone_number_snapshot: borrower.phone_number_normalized
    )

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "LOAN-2001 | lending_rails"
    assert_select "h1", text: "LOAN-2001"
    assert_select "a[href='#{loans_path}']", text: "Loans"
    assert_select "span.border-slate-200.bg-slate-100.text-slate-700", text: "Created"
    assert_select "a[href='#{borrower_path(borrower)}']", text: borrower.full_name
    assert_select "a[href='#{loan_application_path(application)}']", text: "APP-0101"
    assert_select "h2", text: "Disbursement readiness"
    assert_select "h2", text: "Loan documentation"
    assert_select "h2", text: "Pre-disbursement loan details"
    assert_select "h2", text: "Current loan summary"
    assert_select "input[type='submit'][value='Save loan details']"
    assert_select "form.button_to[action='#{begin_documentation_loan_path(loan, from: "loans")}']"
    assert_select "button[disabled='disabled']", text: "Proceed toward disbursement"
  end

  it "saves editable pre-disbursement details for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :created, loan_number: "LOAN-3001")

    sign_in_as(user)
    patch loan_path(loan), params: {
      from: "loans",
      loan: {
        principal_amount: "45000",
        tenure_in_months: "10",
        repayment_frequency: "bi-weekly",
        interest_mode: "rate",
        interest_rate: "12.5000",
        notes: "Prefers a shorter repayment cycle."
      }
    }

    expect(response).to redirect_to(loan_path(loan, from: "loans"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Loan details saved successfully."
    assert_select "dd", text: "45000.00"
    assert_select "dd", text: "10 months"
    assert_select "dd", text: "Bi-Weekly"
    assert_select "dd", text: "Interest rate"
    assert_select "dd", text: "12.5000%"
    assert_select "dd", text: "Prefers a shorter repayment cycle."
  end

  it "keeps invalid pre-disbursement updates on the loan workspace with actionable feedback" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :created, loan_number: "LOAN-3002")

    sign_in_as(user)
    patch loan_path(loan), params: {
      loan: {
        principal_amount: "",
        tenure_in_months: "",
        repayment_frequency: "daily",
        interest_mode: "rate",
        interest_rate: ""
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    assert_select "h1", text: "LOAN-3002"
    assert_select "h2", text: "Please correct the highlighted loan details."
    assert_select "p", text: "Principal amount can't be blank"
    assert_select "p", text: "Tenure in months can't be blank"
    assert_select "p", text: "Repayment frequency is not included in the list"
    assert_select "p", text: "Interest rate can't be blank"
  end

  it "blocks updates after disbursement and explains the lifecycle boundary" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-3003")

    sign_in_as(user)
    patch loan_path(loan), params: {
      loan: {
        principal_amount: "99999",
        tenure_in_months: "2",
        repayment_frequency: "weekly",
        interest_mode: "total_interest_amount",
        total_interest_amount: "1200"
      }
    }

    expect(response).to redirect_to(loan_path(loan))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "These loan details can no longer be edited after disbursement."
    assert_select "dd", text: "45000.00"
    assert_select "input[type='submit'][value='Save loan details']", count: 0
  end

  it "lets a signed-in admin begin documentation from the created state" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :created, :with_details, loan_number: "LOAN-4001")

    sign_in_as(user)
    patch begin_documentation_loan_path(loan), params: { from: "loans" }

    expect(response).to redirect_to(loan_path(loan, from: "loans"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Documentation stage started for LOAN-4001."
    assert_select "dd", text: "Documentation In Progress"
    expect(loan.reload).to be_documentation_in_progress
  end

  it "guards begin documentation when the state transition is invalid" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-4002")

    sign_in_as(user)
    patch begin_documentation_loan_path(loan)

    expect(response).to redirect_to(loan_path(loan))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "This loan cannot begin documentation from its current state."
    expect(loan.reload).to be_active
  end

  it "lets a signed-in admin complete documentation from documentation_in_progress" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :documentation_in_progress, :with_details, loan_number: "LOAN-4003")

    sign_in_as(user)
    patch complete_documentation_loan_path(loan), params: { from: "loans" }

    expect(response).to redirect_to(loan_path(loan, from: "loans"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Documentation completed for LOAN-4003. Loan is now ready for disbursement."
    assert_select "dd", text: "Ready For Disbursement"
    expect(loan.reload).to be_ready_for_disbursement
  end

  it "shows an enabled proceed action when a loan is ready for disbursement and details are complete" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :ready_for_disbursement, :with_details, loan_number: "LOAN-4003A")

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "form.button_to[action='#{attempt_disbursement_loan_path(loan, from: "loans")}']"
    assert_select "button[disabled='disabled']", text: "Proceed toward disbursement", count: 0
  end

  it "shows readiness as historical context after the loan is already active" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-4003AA")

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "p", text: /already beyond the pre-disbursement phase/
    assert_select "p", text: "Disbursement readiness is shown as historical context."
    assert_select "p", text: "Disbursement is currently blocked.", count: 0
    assert_select "form.button_to[action='#{attempt_disbursement_loan_path(loan, from: "loans")}']", count: 0
  end

  it "blocks a disbursement attempt on the server and explains what is missing" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :created, loan_number: "LOAN-4003B")

    sign_in_as(user)
    patch attempt_disbursement_loan_path(loan), params: { from: "loans" }

    expect(response).to redirect_to(loan_path(loan, from: "loans"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: /Disbursement is blocked because/
    assert_select "p", text: /Complete the missing pre-disbursement loan details/
  end

  it "guards complete documentation when the state transition is invalid" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :created, :with_details, loan_number: "LOAN-4004")

    sign_in_as(user)
    patch complete_documentation_loan_path(loan)

    expect(response).to redirect_to(loan_path(loan))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "This loan cannot complete documentation from its current state."
    expect(loan.reload).to be_created
  end
end
