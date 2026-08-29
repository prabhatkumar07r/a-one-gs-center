class CreateCourseDiscounts < ActiveRecord::Migration[8.1]
  def change
    create_table :course_discounts do |t|
      t.references :course, null: false, foreign_key: true
      t.references :discount, null: false, foreign_key: true

      t.timestamps
    end
  end
end
