class CreateTaskCheckpoints < ActiveRecord::Migration[8.1]
  def change
    add_timestamps :books, null: false, default: -> { "CURRENT_TIMESTAMP" }
    add_index :books, [ :updated_at, :id ]

    create_table :task_checkpoints do |t|
      t.string :name, null: false
      t.datetime :processed_through
      t.datetime :last_started_at
      t.datetime :last_finished_at
      t.datetime :last_succeeded_at
      t.string :status, null: false, default: "idle"
      t.integer :books_processed, null: false, default: 0
      t.text :last_error
      t.json :metadata, null: false, default: {}
      t.timestamps
      t.index :name, unique: true
      t.check_constraint "status IN ('idle', 'running', 'succeeded', 'failed')",
        name: "task_checkpoints_status"
      t.check_constraint "books_processed >= 0", name: "task_checkpoints_books_processed"
    end
  end
end
