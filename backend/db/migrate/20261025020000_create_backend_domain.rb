class CreateBackendDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :password_digest, null: false
      t.boolean :is_admin, null: false, default: false
      t.index :username, unique: true
    end

    create_table :books do |t|
      t.string :user_id
      t.string :title, null: false
      t.string :author, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :rating
      t.string :review
      t.index :started_at
      t.check_constraint "finished_at IS NULL OR finished_at >= started_at",
        name: "books_finish_after_start"
      t.check_constraint "rating IS NULL OR rating BETWEEN 1 AND 5",
        name: "books_rating_range"
    end

    create_table :book_events do |t|
      t.references :book, null: false, foreign_key: true
      t.string :type, null: false
      t.datetime :date, null: false
      t.integer :start_rank, null: false
      t.index [ :book_id, :type ], unique: true
      t.index [ :date, :type, :start_rank, :book_id ], name: "index_book_events_for_timeline"
      t.check_constraint "type IN ('START', 'FINISH')", name: "book_events_type"
      t.check_constraint "start_rank BETWEEN 1 AND 12", name: "book_events_rank"
    end
  end
end
