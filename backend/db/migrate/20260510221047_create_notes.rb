class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :content

      t.timestamps
    end

    # Composite index used by listings (per-user, newest first) and cursor pagination.
    add_index :notes, [ :user_id, :created_at, :id ]
  end
end
