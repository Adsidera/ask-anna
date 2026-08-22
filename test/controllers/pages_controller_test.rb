require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "GET / renders the homepage" do
    get root_path

    assert_response :success
    assert_select "#ask-anna-form"
    assert_select "#ask-anna-input"
  end

  test "GET / shows active suggested questions as clickable chips" do
    get root_path

    assert_response :success
    assert_select "[data-suggested-question=?]", suggested_questions(:most_exciting_project).question
    assert_select "[data-suggested-question=?]", suggested_questions(:inactive_one).question, count: 0
  end
end
