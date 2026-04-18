require "rails_helper"

RSpec.describe "Dashboard", type: :request do
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

  def formatted_money(cents)
    ApplicationController.helpers.humanized_money_with_symbol(Money.new(cents, "INR"))
  end

  it "redirects unauthenticated user to login" do
    get dashboard_path

    expect(response).to redirect_to(new_session_path)
  end

  it "renders the dashboard page for authenticated user" do
    user = create(:user, email_address: "admin@example.com")

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "Dashboard | lending_rails"
    assert_select "h1", text: "Dashboard"
  end

  it "renders overdue payments widget with correct count" do
    user = create(:user, email_address: "admin@example.com")
    create(:payment, :overdue)
    create(:payment, :overdue)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    assert_select "article[aria-label='Overdue payments']" do
      assert_select "p", text: "2"
    end
  end

  it "renders upcoming payments widget with correct count" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details)
    create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.current + 3.days)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    assert_select "article[aria-label='Upcoming payments']" do
      assert_select "p", text: "1"
    end
  end

  it "renders open applications widget with correct count" do
    user = create(:user, email_address: "admin@example.com")
    create(:loan_application)
    create(:loan_application, :in_progress)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    assert_select "article[aria-label='Open applications']" do
      assert_select "p", text: "2"
    end
  end

  it "renders active loans widget with correct count" do
    user = create(:user, email_address: "admin@example.com")
    create(:loan, :active, :with_details)
    create(:loan, :overdue, :with_details)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    assert_select "article[aria-label='Active loans']" do
      assert_select "p", text: "2"
    end
  end

  it "renders closed loans count" do
    user = create(:user, email_address: "admin@example.com")
    create(:loan, :closed, :with_details)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    assert_select "article[aria-label='Closed loans']" do
      assert_select "p", text: "1"
    end
  end

  it "renders total disbursed amount" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details)
    create(:invoice, :disbursement, loan: loan, amount_cents: 4_500_000)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    assert_select "article[aria-label='Total disbursed']" do
      assert_select "p", text: formatted_money(4_500_000)
    end
  end

  it "renders total repayment amount" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details)
    payment = create(:payment, :completed, loan: loan, installment_number: 1)
    create(:invoice, :payment, payment: payment, loan: loan, amount_cents: 421_875)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    assert_select "article[aria-label='Total repayment']" do
      assert_select "p", text: formatted_money(421_875)
    end
  end

  it "renders drill-in links to the correct filtered list paths" do
    user = create(:user, email_address: "admin@example.com")

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{payments_path(view: "overdue")}']", text: "View all"
    assert_select "a[href='#{payments_path(view: "upcoming")}']", text: "View all"
    assert_select "a[href='#{loan_applications_path(status: "open")}']", text: "View all"
    assert_select "a[href='#{loans_path(status: "active")}']", text: "View all"
    assert_select "a[href='#{loans_path(status: "closed")}']", text: "View all"
  end

  it "renders navigation links" do
    user = create(:user, email_address: "admin@example.com")

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    assert_select "nav[aria-label='Main navigation']" do
      assert_select "a", text: "Dashboard"
      assert_select "a", text: "Borrowers"
      assert_select "a", text: "Applications"
      assert_select "a", text: "Loans"
      assert_select "a", text: "Payments"
      assert_select "button", text: "Sign out"
    end
  end

  it "resolves root path to the dashboard" do
    user = create(:user, email_address: "admin@example.com")

    sign_in_as(user)
    get root_path

    expect(response).to have_http_status(:ok)
    assert_select "h1", text: "Dashboard"
  end
end
