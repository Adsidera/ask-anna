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

ActiveRecord::Schema[8.1].define(version: 2026_08_21_172524) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "chunks", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.vector "embedding", limit: 768
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "position"], name: "index_chunks_on_document_id_and_position", unique: true
    t.index ["document_id"], name: "index_chunks_on_document_id"
    t.index ["embedding"], name: "index_chunks_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
  end

  create_table "documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "published_at"
    t.text "raw_content", null: false
    t.string "source_type", null: false
    t.string "source_url"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["source_type"], name: "index_documents_on_source_type"
  end

  create_table "suggested_questions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "answer", null: false
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 768
    t.string "question", null: false
    t.string "source_url"
    t.datetime "updated_at", null: false
    t.index ["embedding"], name: "index_suggested_questions_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
  end

  add_foreign_key "chunks", "documents"
end
