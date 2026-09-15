class CreateTestimonials < ActiveRecord::Migration[8.1]
  def change
    create_table :testimonials do |t|
      t.string :student_name, null: false
      t.text :message, null: false
      t.integer :rating, default: 5
      t.string :status, default: "Active", null: false
      t.integer :display_order, default: 0, null: false

      t.timestamps
    end
  end
end