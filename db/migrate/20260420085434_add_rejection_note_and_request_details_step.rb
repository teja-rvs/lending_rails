class AddRejectionNoteAndRequestDetailsStep < ActiveRecord::Migration[8.0]
  def up
    add_column :review_steps, :rejection_note, :text

    ReviewStep.where(step_key: "verification").update_all(position: 4)
  end

  def down
    ReviewStep.where(step_key: "verification").update_all(position: 3)
    ReviewStep.where(step_key: "request_details").delete_all

    remove_column :review_steps, :rejection_note
  end
end
