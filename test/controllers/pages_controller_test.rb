require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "GET / renders the homepage" do
    get root_path

    assert_response :success
    assert_select "#ask-anna-form"
    assert_select "#ask-anna-input"
  end
end
