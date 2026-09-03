class AddHindiTextToTestSeriesOptions < ActiveRecord::Migration[8.1]
  def change
    add_column :test_series_options, :option_text_hindi, :text
  end
end
