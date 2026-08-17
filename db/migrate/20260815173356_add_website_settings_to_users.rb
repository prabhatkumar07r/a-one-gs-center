class AddWebsiteSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :website_name, :string
    add_column :users, :website_email, :string
    add_column :users, :website_mobile, :string
    add_column :users, :website_description, :text
    add_column :users, :website_address, :text
  end
end
