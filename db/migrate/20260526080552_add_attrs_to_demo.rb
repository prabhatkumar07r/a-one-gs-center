class AddAttrsToDemo < ActiveRecord::Migration[8.1]
  def change
    add_column :demos, :name, :string
  end
end
