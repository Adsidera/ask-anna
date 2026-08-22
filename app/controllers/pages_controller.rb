class PagesController < ApplicationController
  def home
    @suggested_questions = SuggestedQuestion.active.order(:created_at)
  end
end
