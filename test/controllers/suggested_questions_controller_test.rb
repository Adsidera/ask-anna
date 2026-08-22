require "test_helper"

class SuggestedQuestionsControllerTest < ActionDispatch::IntegrationTest
  test "returns only active suggested questions' text, not answers" do
    get suggested_questions_path, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ suggested_questions(:most_exciting_project).question ], body["questions"]
  end
end
