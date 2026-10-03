class AddApplicableToToCoupons < ActiveRecord::Migration[8.1]
  def change
    add_column :coupons,
              :applicable_to,
              :string,
              null: false,
              default: "courses"

    add_index :coupons, :applicable_to
  end
end