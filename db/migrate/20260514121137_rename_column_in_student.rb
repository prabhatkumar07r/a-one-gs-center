class RenameColumnInStudent < ActiveRecord::Migration[8.1]
  def change
    rename_column:Students,:number,:mobile
  end
end
