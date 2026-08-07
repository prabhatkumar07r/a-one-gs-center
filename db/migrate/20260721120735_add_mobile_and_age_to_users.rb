class AddMobileAndAgeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :mobile, :string
    add_column :users, :age, :integer
  end
end
