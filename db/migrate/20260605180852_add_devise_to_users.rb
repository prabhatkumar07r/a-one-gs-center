# frozen_string_literal: true

class AddDeviseToUsers < ActiveRecord::Migration[8.1]
  def self.up
    change_table :users do |t|
      # Database authenticatable
      # email already exists, so don't add again
      t.string :encrypted_password, null: false, default: ""

      # Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      # Rememberable
      t.datetime :remember_created_at

      # Trackable (optional - uncomment if needed)
      # t.integer  :sign_in_count, default: 0, null: false
      # t.datetime :current_sign_in_at
      # t.datetime :last_sign_in_at
      # t.string   :current_sign_in_ip
      # t.string   :last_sign_in_ip
    end

    # Only add index for reset_password_token
    add_index :users, :reset_password_token, unique: true
    
    # Don't add email index if email column already has index
    # or if email column doesn't exist in this migration
  end

  def self.down
    remove_column :users, :encrypted_password if column_exists?(:users, :encrypted_password)
    remove_column :users, :reset_password_token if column_exists?(:users, :reset_password_token)
    remove_column :users, :reset_password_sent_at if column_exists?(:users, :reset_password_sent_at)
    remove_column :users, :remember_created_at if column_exists?(:users, :remember_created_at)
  end
end