RSpec.shared_examples "deletion protected" do
  it "raises ActiveRecord::ReadOnlyRecord on destroy" do
    expect { subject.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord, /cannot be deleted/)
  end

  it "raises ActiveRecord::ReadOnlyRecord on destroy!" do
    expect { subject.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord, /cannot be deleted/)
  end

  it "persists the record after the failed destroy attempt" do
    begin
      subject.destroy
    rescue ActiveRecord::ReadOnlyRecord
      # expected
    end

    expect(subject.class.exists?(subject.id)).to be true
  end
end
