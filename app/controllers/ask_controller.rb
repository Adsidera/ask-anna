# POST /ask -- spec Fase 2. Public, unauthenticated JSON endpoint called by
# the widget (Fase 3), so it neither relies on nor sets a session cookie.
class AskController < ApplicationController
  skip_forgery_protection

  MIN_QUESTION_LENGTH = 3
  MAX_QUESTION_LENGTH = 500

  def create
    question = params[:question].to_s.strip

    unless question.length.between?(MIN_QUESTION_LENGTH, MAX_QUESTION_LENGTH)
      return render json: {
        error: "question must be between #{MIN_QUESTION_LENGTH} and #{MAX_QUESTION_LENGTH} characters"
      }, status: :unprocessable_content
    end

    result = Rag::QueryService.call(question)
    render json: { answer: result.answer, sources: result.sources }
  rescue AI::EmbeddingClient::Error, AI::GenerationClient::Error => e
    Rails.logger.error("[AskController] #{e.class}: #{e.message}")
    render json: { error: "the assistant is temporarily unavailable, please try again shortly" },
           status: :service_unavailable
  end
end
