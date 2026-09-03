class RemoveCourseFromTestSeries < ActiveRecord::Migration[8.1]
  def change
    remove_reference :test_series, :course, null: false, foreign_key: true
  end
end
