# Public, read-only: lets the widget (loaded on a third-party page, so it
# can't use server-rendered @suggested_questions like the homepage does)
# fetch the list of suggested questions to show as clickable chips.
# Answers aren't included -- clicking one just submits it through the
# normal /ask flow, which matches it server-side.
class SuggestedQuestionsController < ApplicationController
  def index
    render json: { questions: SuggestedQuestion.active.order(:created_at).pluck(:question) }
  end
end
