require "test_helper"

class SuggestedQuestionTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    suggested_question = SuggestedQuestion.new(question: "What's your stack?", answer: "Rails and PostgreSQL.")
    assert suggested_question.valid?
  end

  test "invalid without a question" do
    suggested_question = SuggestedQuestion.new(answer: "An answer")
    assert_not suggested_question.valid?
    assert_includes suggested_question.errors[:question], "can't be blank"
  end

  test "invalid without an answer" do
    suggested_question = SuggestedQuestion.new(question: "A question")
    assert_not suggested_question.valid?
    assert_includes suggested_question.errors[:answer], "can't be blank"
  end

  test "invalid with a malformed source_url" do
    suggested_question = SuggestedQuestion.new(question: "Q", answer: "A", source_url: "not a url")
    assert_not suggested_question.valid?
    assert_includes suggested_question.errors[:source_url], "is invalid"
  end

  test "active scope only returns active entries" do
    assert_includes SuggestedQuestion.active, suggested_questions(:most_exciting_project)
    assert_not_includes SuggestedQuestion.active, suggested_questions(:inactive_one)
  end

  test "creating a suggested question enqueues SuggestedQuestionEmbeddingJob" do
    assert_enqueued_with(job: SuggestedQuestionEmbeddingJob) do
      SuggestedQuestion.create!(question: "New question", answer: "New answer")
    end
  end

  test "updating the question re-enqueues SuggestedQuestionEmbeddingJob" do
    suggested_question = suggested_questions(:most_exciting_project)

    assert_enqueued_with(job: SuggestedQuestionEmbeddingJob, args: [ suggested_question.id ]) do
      suggested_question.update!(question: "A rephrased question?")
    end
  end

  test "updating the answer alone does not re-enqueue embedding" do
    suggested_question = suggested_questions(:most_exciting_project)

    assert_no_enqueued_jobs only: SuggestedQuestionEmbeddingJob do
      suggested_question.update!(answer: "A different answer")
    end
  end
end
