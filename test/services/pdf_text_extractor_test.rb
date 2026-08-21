require "test_helper"

class PdfTextExtractorTest < ActiveSupport::TestCase
  test "extracts text from a valid PDF" do
    File.open(file_fixture("sample.pdf"), "rb") do |file|
      assert_equal "Hello Anna", PdfTextExtractor.call(file)
    end
  end

  test "raises a PdfTextExtractor::Error for a malformed PDF" do
    File.open(file_fixture("invalid.pdf"), "rb") do |file|
      assert_raises(PdfTextExtractor::Error) { PdfTextExtractor.call(file) }
    end
  end
end
