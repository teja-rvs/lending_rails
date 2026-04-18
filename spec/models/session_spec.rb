require "rails_helper"

RSpec.describe Session, type: :model do
  it { is_expected.to belong_to(:user) }

  it "can be created with valid attributes" do
    user = create(:user)

    session = Session.create!(
      user: user,
      user_agent: "RSpec/1.0",
      ip_address: "127.0.0.1"
    )

    expect(session).to be_persisted
    expect(session.user).to eq(user)
    expect(session.user_agent).to eq("RSpec/1.0")
    expect(session.ip_address).to eq("127.0.0.1")
  end

  it "requires a user" do
    session = Session.new(user: nil, user_agent: "RSpec", ip_address: "127.0.0.1")

    expect(session).not_to be_valid
    expect(session.errors[:user]).to be_present
  end

  it "allows multiple sessions per user" do
    user = create(:user)

    session_a = Session.create!(user: user, user_agent: "Browser A", ip_address: "10.0.0.1")
    session_b = Session.create!(user: user, user_agent: "Browser B", ip_address: "10.0.0.2")

    expect(user.sessions.count).to eq(2)
    expect(user.sessions).to include(session_a, session_b)
  end

  it "is destroyed when explicitly deleted without affecting the user" do
    user = create(:user)
    session = Session.create!(user: user, user_agent: "RSpec", ip_address: "127.0.0.1")

    session.destroy!

    expect(Session.exists?(session.id)).to be(false)
    expect(User.exists?(user.id)).to be(true)
  end
end
