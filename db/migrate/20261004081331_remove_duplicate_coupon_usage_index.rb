class RemoveDuplicateCouponUsageIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :coupon_usages,
                 name: "index_coupon_usages_on_coupon_id_and_user_id"
  end
end