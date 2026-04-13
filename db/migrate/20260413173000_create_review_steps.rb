class CreateReviewSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :review_steps, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :loan_application, null: false, foreign_key: true, type: :uuid
      t.string :step_key, null: false
      t.integer :position, null: false
      t.string :status, null: false
      t.timestamps
    end

    add_index :review_steps, %i[loan_application_id step_key], unique: true
    add_index :review_steps, %i[loan_application_id position], unique: true
    add_index :review_steps, :status
  end
end
