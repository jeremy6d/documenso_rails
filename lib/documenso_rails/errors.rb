module DocumensoRails
  class Error < StandardError; end

  class ApiError < Error
    attr_reader :status_code, :body

    def initialize(message = nil, status_code: nil, body: nil)
      super(message)
      @status_code = status_code
      @body = body
    end
  end
end
