class AddGrantedByForeignKeyToEbookAccessGrants < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :ebook_access_grants, :users,
                    column: :granted_by_id
  end
end