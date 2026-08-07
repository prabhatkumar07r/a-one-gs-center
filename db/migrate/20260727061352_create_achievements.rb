class CreateAchievements < ActiveRecord::Migration[8.1]
  def change
    create_table :achievements do |t|
      t.string :title
      t.text :description
      t.string :rank
      t.string :year
      t.boolean :status

      t.timestamps
    end
  end
end
