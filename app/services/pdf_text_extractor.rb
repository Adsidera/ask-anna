require "pdf/reader"

# Extracts plain text from an uploaded PDF for Document ingestion (admin
# panel "upload a PDF" mode), alongside pasted text and URL ingestion.
class PdfTextExtractor
  class Error < StandardError; end

  def self.call(io)
    new(io).call
  end

  def initialize(io)
    @io = io
  end

  def call
    text = PDF::Reader.new(@io).pages.map(&:text).join("\n\n")
    raise Error, "no extractable text found (is it a scanned image?)" if text.blank?

    text
      .gsub(/[ \t]+/, " ")
      .gsub(/\n{3,}/, "\n\n")
      .split("\n").map(&:strip).join("\n")
      .strip
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
    raise Error, "could not read PDF (#{e.message})"
  end
end
