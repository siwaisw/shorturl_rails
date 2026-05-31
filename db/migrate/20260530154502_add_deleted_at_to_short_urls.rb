class AddDeletedAtToShortUrls < ActiveRecord::Migration[8.1]
  def change
    add_column :short_urls, :deleted_at, :datetime

    # Single-column indexes for fast scoped lookups
    add_index :short_urls, :expires_at
    add_index :short_urls, :deleted_at

    # Compound index used by the cleanup job:
    # WHERE expires_at < NOW() AND deleted_at IS NOT NULL
    add_index :short_urls, [ :expires_at, :deleted_at ],
              name: "index_short_urls_on_cleanup_condition"
  end
end
