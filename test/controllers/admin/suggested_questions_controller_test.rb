require "test_helper"

module Admin
  class SuggestedQuestionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @original_admin_username = ENV["ADMIN_USERNAME"]
      @original_admin_password = ENV["ADMIN_PASSWORD"]
      ENV["ADMIN_USERNAME"] = "test-admin"
      ENV["ADMIN_PASSWORD"] = "test-password"
    end

    teardown do
      ENV["ADMIN_USERNAME"] = @original_admin_username
      ENV["ADMIN_PASSWORD"] = @original_admin_password
    end

    test "without credentials, requests are rejected" do
      get admin_suggested_questions_path
      assert_response :unauthorized
    end

    test "with correct credentials, the list renders" do
      get admin_suggested_questions_path, headers: auth_headers
      assert_response :success
      assert_select "h1", "Suggested questions"
    end

    test "creating a suggested question enqueues embedding" do
      assert_enqueued_with(job: SuggestedQuestionEmbeddingJob) do
        post admin_suggested_questions_path,
          params: { suggested_question: { question: "New question?", answer: "New answer.", active: "1" } },
          headers: auth_headers
      end

      suggested_question = SuggestedQuestion.last
      assert_redirected_to admin_suggested_question_path(suggested_question)
      assert_equal "New question?", suggested_question.question
      assert suggested_question.active?
    end

    test "rejects a suggested question without an answer" do
      post admin_suggested_questions_path,
        params: { suggested_question: { question: "Missing answer?", answer: "" } },
        headers: auth_headers

      assert_response :unprocessable_content
      assert_select ".text-red-700"
    end

    test "updating the question re-enqueues embedding" do
      suggested_question = suggested_questions(:most_exciting_project)

      assert_enqueued_with(job: SuggestedQuestionEmbeddingJob, args: [ suggested_question.id ]) do
        patch admin_suggested_question_path(suggested_question),
          params: { suggested_question: { question: "Rephrased?" } },
          headers: auth_headers
      end

      assert_redirected_to admin_suggested_question_path(suggested_question)
    end

    test "destroying a suggested question removes it" do
      suggested_question = suggested_questions(:most_exciting_project)

      assert_difference -> { SuggestedQuestion.count }, -1 do
        delete admin_suggested_question_path(suggested_question), headers: auth_headers
      end

      assert_redirected_to admin_suggested_questions_path
    end

    private

    def auth_headers(username: "test-admin", password: "test-password")
      { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password) }
    end
  end
end
