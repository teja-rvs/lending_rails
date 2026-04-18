require "rails_helper"

RSpec.describe Borrowers::LookupQuery do
  describe ".call" do
    it "returns all borrowers ordered by newest first when no search is given" do
      older = create(:borrower, full_name: "Alpha", phone_number: "+919876500001")
      newer = create(:borrower, full_name: "Beta", phone_number: "+919876500002")

      result = described_class.call

      expect(result.to_a).to eq([newer, older])
    end

    it "returns all borrowers when search is blank" do
      create(:borrower, full_name: "Gamma", phone_number: "+919876500003")

      result = described_class.call(search: "   ")

      expect(result.count).to eq(1)
    end

    it "matches borrowers by exact normalized phone number" do
      target = create(:borrower, full_name: "Asha Patel", phone_number: "+919876543210")
      create(:borrower, full_name: "Rahul Singh", phone_number: "+919876500099")

      result = described_class.call(search: "+919876543210")

      expect(result.to_a).to eq([target])
    end

    it "matches borrowers by raw phone input that normalizes to a valid E164" do
      target = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
      create(:borrower, full_name: "Rahul Singh", phone_number: "+919876500099")

      result = described_class.call(search: "98765 43210")

      expect(result.to_a).to eq([target])
    end

    it "matches borrowers by partial name (case-insensitive)" do
      target = create(:borrower, full_name: "Asha Patel", phone_number: "+919876500010")
      create(:borrower, full_name: "Rahul Singh", phone_number: "+919876500011")

      result = described_class.call(search: "asha")

      expect(result.to_a).to eq([target])
    end

    it "matches borrowers by partial name substring" do
      create(:borrower, full_name: "Meera Shah", phone_number: "+919876500020")
      create(:borrower, full_name: "Priya Sharma", phone_number: "+919876500021")

      result = described_class.call(search: "Sha")

      expect(result.count).to eq(2)
    end

    it "returns an empty relation when the phone number does not match any borrower" do
      create(:borrower, full_name: "Asha Patel", phone_number: "+919876543210")

      result = described_class.call(search: "+910000000000")

      expect(result.to_a).to be_empty
    end

    it "returns an empty relation when the name does not match any borrower" do
      create(:borrower, full_name: "Asha Patel", phone_number: "+919876543210")

      result = described_class.call(search: "Nonexistent")

      expect(result.to_a).to be_empty
    end

    it "accepts a custom scope and searches within it" do
      target = create(:borrower, full_name: "Asha Patel", phone_number: "+919876500030")
      excluded = create(:borrower, full_name: "Asha Rao", phone_number: "+919876500031")

      result = described_class.call(scope: Borrower.where(id: target.id), search: "Asha")

      expect(result.to_a).to eq([target])
      expect(result.to_a).not_to include(excluded)
    end

    it "strips and squishes whitespace from the search term" do
      target = create(:borrower, full_name: "Asha Patel", phone_number: "+919876500040")

      result = described_class.call(search: "  Asha   Patel  ")

      expect(result.to_a).to eq([target])
    end

    it "falls back to name search when the phone number cannot be normalized" do
      target = create(:borrower, full_name: "123 Corp", phone_number: "+919876500050")
      create(:borrower, full_name: "Other Corp", phone_number: "+919876500051")

      result = described_class.call(search: "123")

      expect(result.to_a).to eq([target])
    end
  end
end
