class AddUniqueIndexToCouponUsages < ActiveRecord::Migration[8.1]
  def change
    add_index :coupon_usages,
              [:coupon_id, :user_id],
              unique: true,
              name: "index_coupon_usages_on_coupon_and_user"
  end
end