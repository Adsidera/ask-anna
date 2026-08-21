require "test_helper"

module Admin
  class DocumentsControllerTest < ActionDispatch::IntegrationTest
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
      get admin_documents_path
      assert_response :unauthorized
    end

    test "with wrong credentials, requests are rejected" do
      get admin_documents_path, headers: auth_headers(password: "wrong")
      assert_response :unauthorized
    end

    test "with correct credentials, the document list renders" do
      get admin_documents_path, headers: auth_headers
      assert_response :success
      assert_select "h1", "Documents"
    end

    test "the admin panel is locked out with 503 when ADMIN_PASSWORD isn't configured" do
      ENV["ADMIN_PASSWORD"] = nil
      get admin_documents_path, headers: auth_headers
      assert_response :service_unavailable
    end

    test "creating a document from pasted text enqueues ingestion" do
      assert_enqueued_with(job: DocumentIngestionJob) do
        post admin_documents_path,
          params: { document: { title: "New", source_type: "cv", raw_content: "hello there" } },
          headers: auth_headers
      end

      document = Document.last
      assert_redirected_to admin_document_path(document)
      assert_equal "hello there", document.raw_content
    end

    test "creating a document with only a source_url fetches and strips HTML" do
      HtmlFetcher.stub(:fetch_text, "fetched plain text") do
        post admin_documents_path,
          params: { document: { title: "From URL", source_type: "blog_post", source_url: "https://example.com/post" } },
          headers: auth_headers
      end

      document = Document.last
      assert_redirected_to admin_document_path(document)
      assert_equal "fetched plain text", document.raw_content
      assert_equal "https://example.com/post", document.source_url
    end

    test "pasted content takes priority over source_url when both are given" do
      post admin_documents_path,
        params: { document: { title: "Both", source_type: "cv", source_url: "https://example.com/x", raw_content: "pasted" } },
        headers: auth_headers

      assert_equal "pasted", Document.last.raw_content
    end

    test "creating a document from an uploaded PDF extracts its text" do
      post admin_documents_path,
        params: {
          document: {
            title: "From PDF", source_type: "cv",
            pdf_file: fixture_file_upload("sample.pdf", "application/pdf")
          }
        },
        headers: auth_headers

      document = Document.last
      assert_redirected_to admin_document_path(document)
      assert_equal "Hello Anna", document.raw_content
    end

    test "an uploaded PDF takes priority over source_url and pasted text" do
      post admin_documents_path,
        params: {
          document: {
            title: "Priority", source_type: "cv",
            source_url: "https://example.com/x", raw_content: "pasted text",
            pdf_file: fixture_file_upload("sample.pdf", "application/pdf")
          }
        },
        headers: auth_headers

      assert_equal "Hello Anna", Document.last.raw_content
    end

    test "an unreadable PDF re-renders the new form with an error" do
      post admin_documents_path,
        params: {
          document: {
            title: "Broken PDF", source_type: "cv",
            pdf_file: fixture_file_upload("invalid.pdf", "application/pdf")
          }
        },
        headers: auth_headers

      assert_response :unprocessable_content
      assert_select ".text-red-700"
    end

    test "a fetch failure re-renders the new form with an error" do
      HtmlFetcher.stub(:fetch_text, ->(_url) { raise HtmlFetcher::Error, "404" }) do
        post admin_documents_path,
          params: { document: { title: "Broken", source_type: "blog_post", source_url: "https://example.com/missing" } },
          headers: auth_headers
      end

      assert_response :unprocessable_content
      assert_select ".text-red-700"
    end

    test "updating raw_content re-enqueues ingestion" do
      document = documents(:cv)

      assert_enqueued_with(job: DocumentIngestionJob, args: [ document.id ]) do
        patch admin_document_path(document), params: { document: { raw_content: "updated content" } }, headers: auth_headers
      end

      assert_redirected_to admin_document_path(document)
    end

    test "destroying a document removes it and its chunks" do
      document = documents(:cv)

      assert_difference -> { Document.count }, -1 do
        delete admin_document_path(document), headers: auth_headers
      end

      assert_redirected_to admin_documents_path
    end

    private

    def auth_headers(username: "test-admin", password: "test-password")
      { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password) }
    end
  end
end
