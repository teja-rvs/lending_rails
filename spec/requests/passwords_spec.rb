require "rails_helper"

RSpec.describe "Passwords", type: :request do
  include ActiveJob::TestHelper

  before do
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it "delivers a reset email with a valid token link" do
    user = create(:user)

    perform_enqueued_jobs do
      post passwords_path, params: { email_address: user.email_address }
    end

    expect(response).to redirect_to(new_session_path)
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.last.to).to contain_exactly(user.email_address)
    expect(ActionMailer::Base.deliveries.last.body.encoded).to match(%r{http://example\.com/passwords/.+/edit})
  end
end
