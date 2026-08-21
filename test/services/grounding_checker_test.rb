require "test_helper"

class GroundingCheckerTest < ActiveSupport::TestCase
  test "keeps a URL that appears in the context" do
    result = GroundingChecker.call(
      answer: "See https://example.com/post for details.",
      context_chunks: [ "More info at https://example.com/post." ]
    )

    assert_equal "See https://example.com/post for details.", result.answer
    assert_equal [ "https://example.com/post" ], result.verified_sources
    assert_empty result.discarded_urls
  end

  test "strips a URL that does not appear in the context" do
    result = GroundingChecker.call(
      answer: "See https://made-up.example.com for details.",
      context_chunks: [ "Anna works with Ruby on Rails." ]
    )

    assert_equal "See [fonte non verificata] for details.", result.answer
    assert_empty result.verified_sources
    assert_equal [ "https://made-up.example.com" ], result.discarded_urls
  end

  test "handles a mix of verified and unverified URLs" do
    result = GroundingChecker.call(
      answer: "Real: https://example.com/real. Fake: https://example.com/fake.",
      context_chunks: [ "The project is at https://example.com/real." ]
    )

    assert_equal "Real: https://example.com/real. Fake: [fonte non verificata]", result.answer
    assert_equal [ "https://example.com/real" ], result.verified_sources
    assert_equal [ "https://example.com/fake" ], result.discarded_urls
  end

  test "returns the answer unchanged when there are no URLs" do
    result = GroundingChecker.call(answer: "No links here.", context_chunks: [ "context" ])

    assert_equal "No links here.", result.answer
    assert_empty result.verified_sources
    assert_empty result.discarded_urls
  end
end
