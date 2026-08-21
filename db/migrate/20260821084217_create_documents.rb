class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string :title, null: false
      t.string :source_type, null: false
      t.string :source_url
      t.text :raw_content, null: false
      t.date :published_at

      t.timestamps
    end

    add_index :documents, :source_type
  end
end
