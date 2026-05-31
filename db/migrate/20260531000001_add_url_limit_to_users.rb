class AddUrlLimitToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :url_limit, :integer
  end
end
