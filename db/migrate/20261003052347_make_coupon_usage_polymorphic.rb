class MakeCouponUsagePolymorphic < ActiveRecord::Migration[8.1]
  def up
    add_reference :coupon_usages,
                  :purchasable,
                  polymorphic: true,
                  index: true

    execute <<~SQL
      UPDATE coupon_usages
      SET
        purchasable_type = 'Enrollment',
        purchasable_id = enrollment_id
      WHERE enrollment_id IS NOT NULL
    SQL

    change_column_null :coupon_usages,
                       :purchasable_type,
                       false

    change_column_null :coupon_usages,
                       :purchasable_id,
                       false

    remove_foreign_key :coupon_usages, :enrollments

    remove_index :coupon_usages,
                 name: "index_coupon_usages_on_enrollment_id"

    remove_column :coupon_usages,
                  :enrollment_id,
                  :bigint
  end

  def down
    add_column :coupon_usages,
                :enrollment_id,
                :bigint

    execute <<~SQL
      UPDATE coupon_usages
      SET enrollment_id = purchasable_id
      WHERE purchasable_type = 'Enrollment'
    SQL

    change_column_null :coupon_usages,
                       :enrollment_id,
                       false

    add_index :coupon_usages,
              :enrollment_id

    add_foreign_key :coupon_usages,
                    :enrollments

    remove_index :coupon_usages,
                 name: "index_coupon_usages_on_purchasable_type_and_purchasable_id"

    remove_column :coupon_usages,
                  :purchasable_type

    remove_column :coupon_usages,
                  :purchasable_id
  end
end