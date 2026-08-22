# Curated question/answer pairs shown as clickable suggestions in the UI
# (homepage/widget) and matched by embedding similarity against whatever
# the user actually types, so paraphrases of a suggested question hit the
# same hand-written answer instead of leaving synthesis to the (small,
# unreliable) generation model every time. See Rag::QueryService.
class SuggestedQuestion < ApplicationRecord
  has_neighbors :embedding, dimensions: ENV.fetch("EMBEDDING_DIMENSIONS", 768).to_i

  validates :question, presence: true
  validates :answer, presence: true
  validates :source_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true

  scope :active, -> { where(active: true) }

  after_commit :enqueue_embedding, on: [ :create, :update ], if: :saved_change_to_question?

  private

  def enqueue_embedding
    SuggestedQuestionEmbeddingJob.perform_later(id)
  end
end
