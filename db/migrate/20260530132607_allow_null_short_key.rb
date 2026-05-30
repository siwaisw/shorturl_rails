class AllowNullShortKey < ActiveRecord::Migration[8.1]
  def change
    change_column_null :short_urls, :short_key, true
  end
end
