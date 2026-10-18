class CreateEbookAccessGrants < ActiveRecord::Migration[8.1]
 def change
  create_table :ebook_access_grants do |t|
    t.references :user, null: false, foreign_key: true
    t.references :ebook, null: false, foreign_key: true
    t.bigint :granted_by_id, null: false
    t.text :reason
    t.datetime :revoked_at

    t.timestamps
  end

  add_index :ebook_access_grants,
            [:user_id, :ebook_id],
            unique: true

  add_index :ebook_access_grants, :granted_by_id
end
end
