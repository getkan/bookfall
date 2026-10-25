class BookEventsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do
    render_error("not_found", "Book event not found", :not_found)
  end

  rescue_from Timeline::Error do |error|
    render_error(error.code, error.message, error.status)
  end

  def index
    names = URI.decode_www_form(request.query_string).map(&:first)
      .select { |name| %w[cursor before after].include?(name) }
    if names.uniq.size != names.size
      raise Timeline::Error.new("invalid_parameters", "Duplicate timeline parameters are not allowed", :bad_request)
    end
    render json: Timeline::Page.call(cursor: params[:cursor], before: params[:before], after: params[:after])
  end

  def show
    event = BookEvent.with_book_details.find(params[:id])
    render json: { book_event: event.timeline_payload }
  end
end
