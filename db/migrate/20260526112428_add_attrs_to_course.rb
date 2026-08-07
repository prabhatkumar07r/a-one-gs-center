class AddAttrsToCourse < ActiveRecord::Migration[8.1]
  def change
    add_column:courses,:name,:string
    add_column:courses, :fee,:integer
    add_column:courses, :duration,:string
  end
end
