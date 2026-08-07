class AddFieldsToDemos < ActiveRecord::Migration[8.1]
  def change
    add_column :demos, :phone, :string
    add_column :demos, :email, :string
    add_column :demos, :course, :string
    add_column :demos, :batch, :string
    add_column :demos, :city, :string
    add_column :demos, :preferred_time, :string
    add_column :demos, :status, :string, default: "Pending"
  end
end
