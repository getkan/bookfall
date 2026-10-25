module Timeline
  class Error < StandardError
    attr_reader :code, :status

    def initialize(code, message, status)
      @code = code
      @status = status
      super(message)
    end
  end
end
