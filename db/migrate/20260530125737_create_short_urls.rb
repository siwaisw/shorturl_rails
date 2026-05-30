class CreateShortUrls < ActiveRecord::Migration[8.1]
  def change
    create_table :short_urls do |t|
      t.string :short_key, limit: 10, null: false
      t.text :original_url, null: false
      t.references :user, null: true, foreign_key: true
      t.integer :click_count, null: false, default: 0
      t.datetime :expires_at, null: false

      t.timestamps
    end
    add_index :short_urls, :short_key, unique: true
  end
end
