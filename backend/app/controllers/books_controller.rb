class BooksController < ApplicationController
  before_action :require_admin

  def index
    books = Book.order(:id).map do |book|
      fields = %w[id user_id title author started_at finished_at]
      fields.concat(%w[rating review]) if book.finished_at.present?
      book.as_json(only: fields)
    end
    render json: { books: books }
  end

  def show
    raise FeatureNotImplemented, "Admin book detail is reserved for Stage 3"
  end

  def create
    raise FeatureNotImplemented, "Admin book creation is reserved for Stage 3"
  end

  def update
    raise FeatureNotImplemented, "Admin book updates are reserved for Stage 3"
  end

  def destroy
    raise FeatureNotImplemented, "Admin book deletion is reserved for Stage 3"
  end
end
