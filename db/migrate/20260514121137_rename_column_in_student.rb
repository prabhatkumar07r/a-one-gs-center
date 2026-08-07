class RenameColumnInStudent < ActiveRecord::Migration[8.1]
  def change
    rename_column :students, :number, :mobile
  end
end
