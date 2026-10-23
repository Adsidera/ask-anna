require "test_helper"

class PdfTextExtractorTest < ActiveSupport::TestCase
  test "extracts text from a valid PDF" do
    File.open(file_fixture("sample.pdf"), "rb") do |file|
      assert_equal "Hello Anna", PdfTextExtractor.call(file)
    end
  end

  test "raises a PdfTextExtractor::Error when the PDF has no extractable text" do
    blank_page = Struct.new(:text).new("  \n ")
    reader = Struct.new(:pages).new([ blank_page ])

    PDF::Reader.stub(:new, reader) do
      error = assert_raises(PdfTextExtractor::Error) { PdfTextExtractor.call(StringIO.new) }
      assert_match "no extractable text", error.message
    end
  end

  test "raises a PdfTextExtractor::Error for a malformed PDF" do
    File.open(file_fixture("invalid.pdf"), "rb") do |file|
      assert_raises(PdfTextExtractor::Error) { PdfTextExtractor.call(file) }
    end
  end
end
