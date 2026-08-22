class CreateSuggestedQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :suggested_questions do |t|
      t.string :question, null: false
      t.text :answer, null: false
      t.string :source_url
      t.boolean :active, null: false, default: true
      t.vector :embedding, limit: ENV.fetch("EMBEDDING_DIMENSIONS", 768).to_i

      t.timestamps
    end

    # HNSW index for fast approximate cosine-distance nearest-neighbor
    # search, same as chunks.embedding (see CreateChunks).
    add_index :suggested_questions, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
