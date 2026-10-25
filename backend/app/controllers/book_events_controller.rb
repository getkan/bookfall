class BookEventsController < ApplicationController
  def index
    render json: Timeline::Page.call(cursor: params[:cursor])
  end
end
