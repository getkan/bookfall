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

ActiveRecord::Schema[8.1].define(version: 2026_10_25_030000) do
  create_table "book_events", force: :cascade do |t|
    t.integer "book_id", null: false
    t.string "type", null: false
    t.datetime "date", null: false
    t.integer "start_rank", null: false
    t.index ["book_id", "type"], name: "index_book_events_on_book_id_and_type", unique: true
    t.index ["book_id"], name: "index_book_events_on_book_id"
    t.index ["date", "type", "start_rank", "book_id"], name: "index_book_events_for_timeline"
    t.check_constraint "start_rank BETWEEN 1 AND 12", name: "book_events_rank"
    t.check_constraint "type IN ('START', 'FINISH')", name: "book_events_type"
  end

  create_table "books", force: :cascade do |t|
    t.string "user_id"
    t.string "title", null: false
    t.string "author", null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.integer "rating"
    t.string "review"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["started_at"], name: "index_books_on_started_at"
    t.index ["updated_at", "id"], name: "index_books_on_updated_at_and_id"
    t.check_constraint "finished_at IS NULL OR finished_at >= started_at", name: "books_finish_after_start"
    t.check_constraint "rating IS NULL OR rating BETWEEN 1 AND 5", name: "books_rating_range"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", limit: 1024, null: false
    t.binary "value", limit: 536870912, null: false
    t.datetime "created_at", null: false
    t.integer "key_hash", limit: 8, null: false
    t.integer "byte_size", limit: 4, null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "task_checkpoints", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "processed_through"
    t.datetime "last_started_at"
    t.datetime "last_finished_at"
    t.datetime "last_succeeded_at"
    t.string "status", default: "idle", null: false
    t.integer "books_processed", default: 0, null: false
    t.text "last_error"
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_task_checkpoints_on_name", unique: true
    t.check_constraint "books_processed >= 0", name: "task_checkpoints_books_processed"
    t.check_constraint "status IN ('idle', 'running', 'succeeded', 'failed')", name: "task_checkpoints_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "password_digest", null: false
    t.boolean "is_admin", default: false, null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "book_events", "books"
end
