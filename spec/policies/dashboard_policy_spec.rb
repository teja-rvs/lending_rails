require "rails_helper"

RSpec.describe DashboardPolicy do
  describe "#show?" do
    it "returns true for authenticated admin user" do
      user = build_stubbed(:user)
      policy = described_class.new(user, :dashboard)

      expect(policy.show?).to be(true)
    end
  end
end
