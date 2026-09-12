class AddBatchTimeToDemos < ActiveRecord::Migration[8.1]
  def change
    add_column :demos, :batch_time, :string
  end
end
