# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_31_000001) do
  create_table "short_urls", force: :cascade do |t|
    t.integer "click_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "expires_at", null: false
    t.text "original_url", null: false
    t.string "short_key", limit: 10
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["deleted_at"], name: "index_short_urls_on_deleted_at"
    t.index ["expires_at", "deleted_at"], name: "index_short_urls_on_cleanup_condition"
    t.index ["expires_at"], name: "index_short_urls_on_expires_at"
    t.index ["short_key"], name: "index_short_urls_on_short_key", unique: true
    t.index ["user_id"], name: "index_short_urls_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "api_key"
    t.datetime "created_at", null: false
    t.string "email", limit: 255, null: false
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.integer "url_limit"
    t.index ["api_key"], name: "index_users_on_api_key", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "short_urls", "users"
end
