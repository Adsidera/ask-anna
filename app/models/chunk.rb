class Chunk < ApplicationRecord
  belongs_to :document

  has_neighbors :embedding, dimensions: ENV.fetch("EMBEDDING_DIMENSIONS", 768).to_i

  validates :content, presence: true
  validates :position, presence: true, uniqueness: { scope: :document_id }
end
