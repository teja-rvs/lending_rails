class AddProcessingFeeToLoans < ActiveRecord::Migration[8.1]
  def change
    add_column :loans, :processing_fee_cents, :bigint, null: false, default: 0
  end
end
