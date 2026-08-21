class Document < ApplicationRecord
  SOURCE_TYPES = %w[cv blog_post project talk].freeze

  has_many :chunks, dependent: :destroy

  validates :title, presence: true
  validates :source_type, presence: true, inclusion: { in: SOURCE_TYPES }
  validates :raw_content, presence: true
  validates :source_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true

  after_commit :enqueue_ingestion, on: [ :create, :update ], if: :saved_change_to_raw_content?

  # Ingests a document from a URL: fetches the page and strips HTML down to
  # plain text before storing it as raw_content.
  def self.ingest_from_url!(url:, title:, source_type:, published_at: nil)
    create!(
      title: title,
      source_type: source_type,
      source_url: url,
      published_at: published_at,
      raw_content: HtmlFetcher.fetch_text(url)
    )
  end

  private

  def enqueue_ingestion
    DocumentIngestionJob.perform_later(id)
  end
end
