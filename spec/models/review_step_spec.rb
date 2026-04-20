require "rails_helper"

RSpec.describe ReviewStep, type: :model do
  describe "deletion protection" do
    subject { create(:review_step) }

    it_behaves_like "deletion protected"
  end

  describe "workflow definition" do
    it "exposes the fixed review sequence from one canonical place" do
      expect(described_class.workflow_definition.map(&:step_key)).to eq(
        %w[history_check phone_screening request_details verification]
      )
      expect(described_class.workflow_definition.map(&:label)).to eq(
        [ "History check", "Phone screening", "Request details", "Verification" ]
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
        step_key: "request_details",
        position: 3,
        status: "initialized"
      )
      create(
        :review_step,
        loan_application:,
        step_key: "verification",
        position: 4,
        status: "initialized"
      )

      expect(described_class.active_for(loan_application.review_steps)).to eq(active_step)
    end

    it "returns nil when every review step is already final" do
      loan_application = create(:loan_application)
      create(:review_step, :history_check, loan_application:, status: "approved")
      create(:review_step, :phone_screening, loan_application:, status: "approved")
      create(:review_step, :request_details, loan_application:, status: "approved")
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

  describe ".definition_for" do
    it "returns the definition for a known step key" do
      definition = described_class.definition_for("history_check")

      expect(definition).to be_present
      expect(definition.step_key).to eq("history_check")
      expect(definition.label).to eq("History check")
      expect(definition.position).to eq(1)
    end

    it "returns nil for an unknown step key" do
      expect(described_class.definition_for("nonexistent_step")).to be_nil
    end
  end

  describe "#label" do
    it "returns the human-readable label from the workflow definition" do
      review_step = build(:review_step, :phone_screening)

      expect(review_step.label).to eq("Phone screening")
    end

    it "falls back to humanizing the step_key for unknown keys" do
      review_step = build(:review_step, step_key: "custom_step", position: 1)

      expect(review_step.label).to eq("Custom step")
    end
  end

  describe "#active_candidate?" do
    it "returns true for initialized status" do
      review_step = build(:review_step, status: "initialized")

      expect(review_step).to be_active_candidate
    end

    it "returns true for 'waiting for details' status" do
      review_step = build(:review_step, status: "waiting for details")

      expect(review_step).to be_active_candidate
    end

    it "returns false for approved status" do
      review_step = build(:review_step, status: "approved")

      expect(review_step).not_to be_active_candidate
    end

    it "returns false for rejected status" do
      review_step = build(:review_step, status: "rejected")

      expect(review_step).not_to be_active_candidate
    end
  end

  describe "#final?" do
    it "returns true for approved status" do
      review_step = build(:review_step, status: "approved")

      expect(review_step).to be_final
    end

    it "returns true for rejected status" do
      review_step = build(:review_step, status: "rejected")

      expect(review_step).to be_final
    end

    it "returns false for initialized status" do
      review_step = build(:review_step, status: "initialized")

      expect(review_step).not_to be_final
    end

    it "returns false for 'waiting for details' status" do
      review_step = build(:review_step, status: "waiting for details")

      expect(review_step).not_to be_final
    end
  end
end
