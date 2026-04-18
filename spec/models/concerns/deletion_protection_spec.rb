require 'rails_helper'

RSpec.describe DeletionProtection, type: :model do
  describe "using Borrower as a representative protected model" do
    subject { create(:borrower) }

    it_behaves_like "deletion protected"
  end
end
