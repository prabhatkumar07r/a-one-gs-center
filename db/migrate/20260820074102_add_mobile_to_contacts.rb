class AddMobileToContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :contacts, :mobile, :string
  end
end
