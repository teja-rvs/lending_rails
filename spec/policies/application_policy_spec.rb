require "rails_helper"

RSpec.describe ApplicationPolicy do
  describe "default permissions" do
    it "exposes the user and record and denies base policy actions" do
      user = build_stubbed(:user)
      record = double("record")
      policy = described_class.new(user, record)

      expect(policy.user).to eq(user)
      expect(policy.record).to eq(record)
      expect(policy.index?).to be(false)
      expect(policy.show?).to be(false)
      expect(policy.create?).to be(false)
      expect(policy.new?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.edit?).to be(false)
      expect(policy.destroy?).to be(false)
    end
  end

  describe described_class::Scope do
    it "exposes the provided context and requires subclasses to implement resolve" do
      user = build_stubbed(:user)
      scope_object = double("scope")
      scope = described_class.new(user, scope_object)

      expect(scope.send(:user)).to eq(user)
      expect(scope.send(:scope)).to eq(scope_object)
      expect { scope.resolve }.to raise_error(NoMethodError, /You must define #resolve/)
    end
  end
end
