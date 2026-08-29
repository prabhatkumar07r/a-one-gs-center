class AddUniqueIndexToFeesEnrollment < ActiveRecord::Migration[8.1]
  def change
    remove_index :fees, name: "index_fees_on_enrollment_id"

    add_index :fees,
              :enrollment_id,
              unique: true,
              name: "index_fees_on_enrollment_id"
  end
end

