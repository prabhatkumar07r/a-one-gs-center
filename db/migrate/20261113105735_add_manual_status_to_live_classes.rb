class AddManualStatusToLiveClasses < ActiveRecord::Migration[8.1]
  def change
    add_column :live_classes,
               :manual_status,
               :boolean,
               default: false,
               null: false
  end
end