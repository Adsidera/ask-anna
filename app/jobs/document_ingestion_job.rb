# Chunks a Document's raw_content and embeds each chunk (spec Fase 1).
#
# Re-running this job (e.g. after a Document update) invalidates and
# recreates all of that document's existing chunks from scratch, since
# chunk boundaries and content may have changed.
class DocumentIngestionJob < ApplicationJob
  queue_as :default

  MAX_EMBEDDING_ATTEMPTS = 3

  def perform(document_id)
    document = Document.find(document_id)
    document.chunks.delete_all

    texts = TextChunker.call(document.raw_content)
    client = AI::EmbeddingClient.new
    failed_positions = []

    texts.each_with_index do |text, position|
      embedding = embed_with_retries(client, text)

      if embedding
        document.chunks.create!(content: text, position: position, embedding: embedding)
      else
        failed_positions << position
      end
    end

    return if failed_positions.empty?

    Rails.logger.error(
      "[DocumentIngestionJob] document=#{document_id} failed to embed chunks at positions " \
      "#{failed_positions.join(', ')} after #{MAX_EMBEDDING_ATTEMPTS} attempts each"
    )
  end

  private

  def embed_with_retries(client, text)
    attempts = 0

    begin
      attempts += 1
      client.embed(text)
    rescue AI::EmbeddingClient::Error, Faraday::Error => e
      if attempts < MAX_EMBEDDING_ATTEMPTS
        sleep(0.5 * attempts)
        retry
      end

      Rails.logger.error("[DocumentIngestionJob] embedding failed after #{attempts} attempts: #{e.message}")
      nil
    end
  end
end
