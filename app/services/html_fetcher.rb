# Fetches a URL and strips it down to plain text, for Document ingestion
# from a URL (spec: "Deve essere possibile ingest da: testo incollato
# diretto, o URL (fetch + strip HTML)").
class HtmlFetcher
  class Error < StandardError; end

  MAX_REDIRECTS = 3

  def self.fetch_text(url)
    new.fetch_text(url)
  end

  def fetch_text(url)
    html = fetch_html(url)
    strip_html(html)
  end

  private

  def fetch_html(url, redirects_remaining: MAX_REDIRECTS)
    response = connection.get(url)

    if response.status.in?([ 301, 302, 303, 307, 308 ]) && response.headers["location"].present?
      raise Error, "Too many redirects fetching #{url}" if redirects_remaining <= 0

      return fetch_html(response.headers["location"], redirects_remaining: redirects_remaining - 1)
    end

    raise Error, "Failed to fetch #{url} (#{response.status})" unless response.success?

    response.body
  end

  def strip_html(html)
    doc = Nokogiri::HTML(html)
    doc.css("script, style, nav, header, footer, noscript").remove

    text = doc.at_css("main, article") || doc.at_css("body") || doc

    text.text
      .gsub(/[ \t]+/, " ")
      .gsub(/\n{3,}/, "\n\n")
      .split("\n").map(&:strip).join("\n")
      .strip
  end

  def connection
    @connection ||= Faraday.new do |f|
      f.options.timeout = 15
      f.headers["User-Agent"] = "AskAnnaBot/1.0 (+document ingestion)"
      f.adapter Faraday.default_adapter
    end
  end
end
