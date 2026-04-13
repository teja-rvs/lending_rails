require "rails_helper"

RSpec.describe ReviewStep, type: :model do
  describe "workflow definition" do
    it "exposes the fixed MVP review sequence from one canonical place" do
      expect(described_class.workflow_definition.map(&:step_key)).to eq(
        %w[history_check phone_screening verification]
      )
      expect(described_class.workflow_definition.map(&:label)).to eq(
        [ "History check", "Phone screening", "Verification" ]
      )
    end
  end

  describe "validations" do
    it "accepts only the canonical workflow statuses" do
      review_step = build(:review_step, status: "not started")

      expect(review_step).not_to be_valid
      expect(review_step.errors[:status]).to include("is not included in the list")
    end

    it "enforces unique step keys per loan application" do
      loan_application = create(:loan_application)
      create(
        :review_step,
        loan_application:,
        step_key: "history_check",
        position: 1
      )

      duplicate_step = build(
        :review_step,
        loan_application:,
        step_key: "history_check",
        position: 2
      )

      expect(duplicate_step).not_to be_valid
      expect(duplicate_step.errors[:step_key]).to include("has already been taken")
    end

    it "enforces unique positions per loan application" do
      loan_application = create(:loan_application)
      create(
        :review_step,
        loan_application:,
        step_key: "history_check",
        position: 1
      )

      duplicate_position = build(
        :review_step,
        loan_application:,
        step_key: "phone_screening",
        position: 1
      )

      expect(duplicate_position).not_to be_valid
      expect(duplicate_position.errors[:position]).to include("has already been taken")
    end
  end

  describe ".active_for" do
    it "returns the first non-final step in workflow order" do
      loan_application = create(:loan_application)
      create(
        :review_step,
        loan_application:,
        step_key: "history_check",
        position: 1,
        status: "approved"
      )
      active_step = create(
        :review_step,
        loan_application:,
        step_key: "phone_screening",
        position: 2,
        status: "initialized"
      )
      create(
        :review_step,
        loan_application:,
        step_key: "verification",
        position: 3,
        status: "initialized"
      )

      expect(described_class.active_for(loan_application.review_steps)).to eq(active_step)
    end

    it "returns nil when every review step is already final" do
      loan_application = create(:loan_application)
      create(:review_step, :history_check, loan_application:, status: "approved")
      create(:review_step, :phone_screening, loan_application:, status: "approved")
      create(:review_step, :verification, loan_application:, status: "rejected")

      expect(described_class.active_for(loan_application.review_steps)).to be_nil
    end
  end

  describe "audit history" do
    it "tracks review-step lifecycle changes with paper trail" do
      review_step = create(
        :review_step,
        step_key: "history_check",
        position: 1
      )

      expect(review_step.versions.pluck(:event)).to include("create")

      review_step.update!(status: "approved")

      expect(review_step.versions.order(:created_at).pluck(:event).last).to eq("update")
    end
  end
end
