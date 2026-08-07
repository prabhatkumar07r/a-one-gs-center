class CreateCertificates < ActiveRecord::Migration[8.1]
  def change
    create_table :certificates do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.string :certificate_no
      t.date :issued_on

      t.timestamps
    end
  end
end
