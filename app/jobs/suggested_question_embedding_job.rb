# Embeds a SuggestedQuestion's question text so it can be matched against
# incoming questions by cosine similarity (see Rag::QueryService#match_suggested_question).
class SuggestedQuestionEmbeddingJob < ApplicationJob
  queue_as :default
  retry_on AI::EmbeddingClient::Error, wait: :polynomially_longer, attempts: 3

  def perform(suggested_question_id)
    suggested_question = SuggestedQuestion.find(suggested_question_id)
    suggested_question.update!(embedding: AI::EmbeddingClient.new.embed(suggested_question.question))
  end
end
