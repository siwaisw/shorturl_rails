class SetShortUrlsIdSequenceStart < ActiveRecord::Migration[8.1]
  START = 1001

  def up
    case connection.adapter_name
    when "PostgreSQL"
      execute "ALTER SEQUENCE short_urls_id_seq RESTART WITH #{START};"
    when "SQLite"
      execute "INSERT OR REPLACE INTO sqlite_sequence (name, seq) VALUES ('short_urls', #{START - 1});"
    end
  end

  def down
    case connection.adapter_name
    when "PostgreSQL"
      execute "ALTER SEQUENCE short_urls_id_seq RESTART WITH 1;"
    when "SQLite"
      execute "INSERT OR REPLACE INTO sqlite_sequence (name, seq) VALUES ('short_urls', 0);"
    end
  end
end
