class BooksController < ApplicationController
  before_action :require_admin
  before_action :set_book, only: %i[show update destroy]

  rescue_from ActiveRecord::RecordNotFound do
    render_error("not_found", "Book not found", :not_found)
  end

  rescue_from ActionController::ParameterMissing, ActionController::BadRequest do
    render_error("invalid_parameters", "A book object with scalar attributes is required", :bad_request)
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_error("validation_failed", error.record.errors.full_messages.join(", "), :unprocessable_entity)
  end

  def index
    books = Book.order(:id).map { |book| serialize_book(book) }
    render json: { books: books }
  end

  def show
    render json: { book: serialize_book(@book) }
  end

  def create
    book = Book.create!(book_params)
    render json: { book: serialize_book(book) }, status: :created
  end

  def update
    Book.transaction do
      @book.update!(book_params)
      @book.book_events.each do |event|
        date = event.type == "START" ? @book.started_at : @book.finished_at
        date ? event.update!(date: date) : event.destroy!
      end
    end
    render json: { book: serialize_book(@book) }
  end

  def destroy
    @book.destroy!
    head :no_content
  end

  private
    def set_book
      @book = Book.find(params[:id])
    end

    def book_params
      attributes = params.require(:book)
      raise ActionController::BadRequest unless attributes.is_a?(ActionController::Parameters)

      fields = %w[user_id title author started_at finished_at rating review]
      attributes.slice(*fields).each do |key, value|
        valid = value.nil? || value.is_a?(String) || (key == "rating" && value.is_a?(Numeric))
        raise ActionController::BadRequest unless valid
      end
      attributes.permit(*fields)
    end

    def serialize_book(book)
      fields = %w[id user_id title author started_at finished_at]
      fields.concat(%w[rating review]) if book.finished_at.present?
      book.as_json(only: fields)
    end
end
