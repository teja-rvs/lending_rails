require "rails_helper"

RSpec.describe "Borrowers", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "redirects unauthenticated visitors to sign in" do
    get new_borrower_path

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from the borrower list" do
    get borrowers_path

    expect(response).to redirect_to(new_session_path)
  end

  it "renders the borrower list for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")
    older_borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    newer_borrower = create(:borrower, full_name: "Bhavya Rao", phone_number: "98765 43211")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get borrowers_path

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "Borrowers | lending_rails"
    assert_select "h1", text: "Borrowers"
    assert_select "form[action='#{borrowers_path}'][method='get']" do
      assert_select "label", text: "Search by phone number or name"
      assert_select "input[name='q']"
      assert_select "input[type='submit'][value='Search borrowers']"
    end
    assert_select "table" do
      assert_select "tbody tr", count: 2
      assert_select "a", text: "Asha Patel"
      assert_select "a", text: "Bhavya Rao"
    end

    borrower_links = css_select("tbody tr td:first-child a").map(&:text)
    expect(borrower_links).to eq([ newer_borrower.full_name, older_borrower.full_name ])
  end

  it "renders the borrower intake form for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get new_borrower_path

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "Create borrower | lending_rails"
    assert_select "h1", text: "Create borrower"
    assert_select "form[action='#{borrowers_path}']" do
      assert_select "label", text: "Full name"
      assert_select "input[name='borrower[full_name]']"
      assert_select "label", text: "Phone number"
      assert_select "input[name='borrower[phone_number]']"
      assert_select "input[type='submit'][value='Create borrower']"
    end
  end

  it "creates a borrower and redirects to the confirmation page" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }

    expect {
      post borrowers_path, params: { borrower: { full_name: "Asha Patel", phone_number: "98765 43210" } }
    }.to change(Borrower, :count).by(1)

    borrower = Borrower.order(:created_at).last

    expect(response).to redirect_to(borrower_path(borrower))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "h1", text: "Borrower record"
    assert_select "dd", text: "Asha Patel"
    assert_select "dd", text: "+919876543210"
  end

  it "returns not found for malformed borrower ids" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get "/borrowers/not-a-uuid"

    expect(response).to have_http_status(:not_found)
  end

  it "keeps invalid phone submissions on the intake page with actionable feedback" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }

    expect {
      post borrowers_path, params: { borrower: { full_name: "Asha Patel", phone_number: "bad-phone" } }
    }.not_to change(Borrower, :count)

    expect(response).to have_http_status(:unprocessable_content)
    assert_select "h1", text: "Create borrower"
    assert_select "p", text: "Phone number is invalid"
    assert_select "div[role='alert'][aria-live='assertive']"
    assert_select "input[name='borrower[phone_number]'][aria-invalid='true'][aria-describedby='borrower_phone_number_hint borrower_phone_number_error']"
    assert_select "input[name='borrower[full_name]'][value='Asha Patel']"
    assert_select "input[name='borrower[phone_number]'][value='bad-phone']"
  end

  it "keeps duplicate phone submissions on the intake page with actionable feedback" do
    user = create(:user, email_address: "admin@example.com")
    create(:borrower, phone_number: "98765 43210")

    post session_path, params: { email_address: user.email_address, password: "password123!" }

    expect {
      post borrowers_path, params: { borrower: { full_name: "Asha Patel", phone_number: "+91 98765 43210" } }
    }.not_to change(Borrower, :count)

    expect(response).to have_http_status(:unprocessable_content)
    assert_select "h1", text: "Create borrower"
    assert_select "p", text: "Phone number has already been taken"
    assert_select "input[name='borrower[full_name]'][value='Asha Patel']"
    assert_select "input[name='borrower[phone_number]'][value='+91 98765 43210']"
  end

  it "finds borrowers by normalized phone number when the submitted query is formatted differently" do
    user = create(:user, email_address: "admin@example.com")
    matching_borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    create(:borrower, full_name: "Bhavya Rao", phone_number: "98765 43211")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get borrowers_path, params: { q: "(+91) 98765-43210" }

    expect(response).to have_http_status(:ok)
    assert_select "tbody tr", count: 1
    assert_select "a[href='#{borrower_path(matching_borrower)}']", text: "Asha Patel"
    assert_select "td", text: "+919876543210"
    assert_select "input[name='q'][value='(+91) 98765-43210']"
  end

  it "supports name search as a secondary lookup path" do
    user = create(:user, email_address: "admin@example.com")
    matching_borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    create(:borrower, full_name: "Bhavya Rao", phone_number: "98765 43211")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get borrowers_path, params: { q: "asha" }

    expect(response).to have_http_status(:ok)
    assert_select "tbody tr", count: 1
    assert_select "a[href='#{borrower_path(matching_borrower)}']", text: "Asha Patel"
  end

  it "shows a clear empty state when no borrowers exist yet" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get borrowers_path

    expect(response).to have_http_status(:ok)
    assert_select "h2", text: "No borrowers yet"
    assert_select "a[href='#{new_borrower_path}']", text: "Create borrower"
  end

  it "shows a filtered empty state and preserves the submitted query when no borrowers match" do
    user = create(:user, email_address: "admin@example.com")
    create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get borrowers_path, params: { q: "no match" }

    expect(response).to have_http_status(:ok)
    assert_select "h2", text: "No borrowers match this search"
    assert_select "p", text: /Try a phone number first, adjust the name search, or create a new borrower/
    assert_select "input[name='q'][value='no match']"
    assert_select "a[href='#{borrowers_path}']", text: "Clear search"
    assert_select "a[href='#{new_borrower_path}']", text: "Create borrower"
  end

  it "treats whitespace-only search input as a blank search in both results and UI state" do
    user = create(:user, email_address: "admin@example.com")
    create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get borrowers_path, params: { q: "   " }

    expect(response).to have_http_status(:ok)
    assert_select "tbody tr", count: 1
    assert_select "input[name='q'][value='']"
    assert_select "a", text: "Clear search", count: 0
    assert_select "p", text: /available in the protected workspace/
    assert_select "p", text: /Showing results for/, count: 0
  end
end
