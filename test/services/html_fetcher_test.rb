require "test_helper"

class HtmlFetcherTest < ActiveSupport::TestCase
  URL = "https://blog.test/post"

  test "returns the page's main content as plain text, without scripts, styles or navigation" do
    stub_request(:get, URL).to_return(body: <<~HTML)
      <html>
        <head><style>body { color: red }</style></head>
        <body>
          <header>Site header</header>
          <nav>Home | About</nav>
          <main>
            <h1>Why I built Ask Anna</h1>
            <script>alert("hi")</script>
            <p>First    paragraph.</p>



            <p>Second paragraph.</p>
          </main>
          <aside>Sidebar outside main</aside>
          <footer>Site footer</footer>
        </body>
      </html>
    HTML

    assert_equal "Why I built Ask Anna\n\nFirst paragraph.\n\nSecond paragraph.", HtmlFetcher.fetch_text(URL)
  end

  test "falls back to the body when there's no main or article element" do
    stub_request(:get, URL).to_return(body: "<html><body><nav>Menu</nav><p>Just a body.</p></body></html>")

    assert_equal "Just a body.", HtmlFetcher.fetch_text(URL)
  end

  test "identifies itself with its User-Agent" do
    stub_request(:get, URL).with(headers: { "User-Agent" => "AskAnnaBot/1.0 (+document ingestion)" }).to_return(body: "<p>ok</p>")

    assert_equal "ok", HtmlFetcher.fetch_text(URL)
  end

  test "follows redirects" do
    stub_request(:get, URL).to_return(status: 301, headers: { "Location" => "https://blog.test/moved" })
    stub_request(:get, "https://blog.test/moved").to_return(body: "<p>Moved here.</p>")

    assert_equal "Moved here.", HtmlFetcher.fetch_text(URL)
  end

  test "follows up to MAX_REDIRECTS redirects, then gives up" do
    hops = (0..HtmlFetcher::MAX_REDIRECTS + 1).map { |i| "https://blog.test/hop#{i}" }
    hops.each_cons(2) do |from, to|
      stub_request(:get, from).to_return(status: 302, headers: { "Location" => to })
    end
    stub_request(:get, hops.last).to_return(body: "<p>Too far.</p>")

    error = assert_raises(HtmlFetcher::Error) { HtmlFetcher.fetch_text(hops.first) }
    assert_match "Too many redirects", error.message

    assert_equal "Too far.", HtmlFetcher.fetch_text(hops.second), "exactly MAX_REDIRECTS hops is still fine"
  end

  test "treats a redirect status without a Location header as a failed fetch" do
    stub_request(:get, URL).to_return(status: 302)

    error = assert_raises(HtmlFetcher::Error) { HtmlFetcher.fetch_text(URL) }
    assert_match "Failed to fetch #{URL} (302)", error.message
  end

  test "raises on an error status" do
    stub_request(:get, URL).to_return(status: 404)

    error = assert_raises(HtmlFetcher::Error) { HtmlFetcher.fetch_text(URL) }
    assert_match "Failed to fetch #{URL} (404)", error.message
  end
end
