class MakeCouponCourseOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :coupons, :course_id, true
  end
end