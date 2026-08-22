module Admin
  # Admin UI for curated suggested questions (see SuggestedQuestion,
  # Rag::QueryService).
  class SuggestedQuestionsController < Admin::BaseController
    before_action :set_suggested_question, except: %i[index new create]

    def index
      @suggested_questions = SuggestedQuestion.order(created_at: :desc)
    end

    def show
    end

    def new
      @suggested_question = SuggestedQuestion.new(active: true)
    end

    def create
      @suggested_question = SuggestedQuestion.new(suggested_question_params)

      if @suggested_question.save
        redirect_to admin_suggested_question_path(@suggested_question), notice: "Suggested question created and queued for embedding."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @suggested_question.update(suggested_question_params)
        redirect_to admin_suggested_question_path(@suggested_question), notice: "Suggested question updated and re-queued for embedding."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @suggested_question.destroy
      redirect_to admin_suggested_questions_path, notice: "Suggested question deleted."
    end

    private

    def set_suggested_question
      @suggested_question = SuggestedQuestion.find(params[:id])
    end

    def suggested_question_params
      params.expect(suggested_question: %i[question answer source_url active])
    end
  end
end
