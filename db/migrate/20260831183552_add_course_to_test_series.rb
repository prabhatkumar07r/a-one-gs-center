class AddCourseToTestSeries < ActiveRecord::Migration[8.1]
  def change
    add_reference :test_series,
                  :course,
                  null: true,
                  foreign_key: true
  end
end