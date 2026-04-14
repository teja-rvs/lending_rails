class AddBorrowerSnapshotsToLoans < ActiveRecord::Migration[8.1]
  def change
    add_column :loans, :borrower_full_name_snapshot, :string
    add_column :loans, :borrower_phone_number_snapshot, :string

    reversible do |direction|
      direction.up do
        safety_assured do
          execute <<~SQL
            UPDATE loans
            SET borrower_full_name_snapshot = COALESCE(loans.borrower_full_name_snapshot, borrowers.full_name),
                borrower_phone_number_snapshot = COALESCE(loans.borrower_phone_number_snapshot, borrowers.phone_number_normalized)
            FROM borrowers
            WHERE borrowers.id = loans.borrower_id
              AND (
                loans.borrower_full_name_snapshot IS NULL
                OR loans.borrower_phone_number_snapshot IS NULL
              )
          SQL
        end
      end
    end
  end
end
