module Admin
  # Fase 1 admin UI for Document CRUD. Ingestion itself (chunking +
  # embedding) still happens the same way it always has -- via
  # DocumentIngestionJob, triggered by Document's after_commit callback --
  # this controller just gives an admin a way to create/edit documents
  # without the Rails console.
  class DocumentsController < Admin::BaseController
    before_action :set_document, except: %i[index new create]

    def index
      @documents = Document.includes(:chunks).order(created_at: :desc)
    end

    def show
    end

    def new
      @document = Document.new
    end

    def create
      @document = Document.new(document_params.except(:pdf_file, :raw_content))
      @document.raw_content = resolved_raw_content

      if @document.save
        redirect_to admin_document_path(@document), notice: "Document created and queued for ingestion."
      else
        render :new, status: :unprocessable_content
      end
    rescue HtmlFetcher::Error, PdfTextExtractor::Error => e
      @document.errors.add(:base, e.message)
      render :new, status: :unprocessable_content
    end

    def edit
    end

    def update
      if @document.update(document_params)
        redirect_to admin_document_path(@document), notice: "Document updated and re-queued for ingestion."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @document.destroy
      redirect_to admin_documents_path, notice: "Document deleted."
    end

    private

    def set_document
      @document = Document.find(params[:id])
    end

    def document_params
      params.expect(document: %i[title source_type source_url raw_content published_at pdf_file])
    end

    # On create, raw_content can come from one of three places, in this
    # priority order: an uploaded PDF, a source_url (fetched + HTML-stripped)
    # when no text was pasted, or pasted text directly.
    def resolved_raw_content
      if document_params[:pdf_file].present?
        PdfTextExtractor.call(document_params[:pdf_file].to_io)
      elsif document_params[:source_url].present? && document_params[:raw_content].blank?
        HtmlFetcher.fetch_text(document_params[:source_url])
      else
        document_params[:raw_content]
      end
    end
  end
end
