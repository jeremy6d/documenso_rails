require "net/http"
require "json"
require "uri"

module DocumensoRails
  class Connection
    MAX_RETRIES = 2

    def initialize(base_url:, api_key:)
      @base_url = base_url.to_s.chomp("/")
      @api_key = api_key
    end

    def get(path)
      request(Net::HTTP::Get, path)
    end

    def get_raw(path)
      request(Net::HTTP::Get, path, parse_json: false)
    end

    def post_json(path, payload)
      request(Net::HTTP::Post, path, json_body: payload)
    end

    def post_multipart(path, payload:, files: [])
      uri = URI("#{@base_url}#{path}")
      http_request = Net::HTTP::Post.new(uri)
      http_request["Authorization"] = @api_key

      form_data = [["payload", payload.to_json]]
      files.each do |file|
        form_data << [
          "files",
          file.fetch(:io),
          { filename: file.fetch(:filename), content_type: file.fetch(:content_type, "application/pdf") }
        ]
      end
      http_request.set_form(form_data, "multipart/form-data")

      execute(uri, http_request)
    end

    private

    def request(method_class, path, json_body: nil, parse_json: true)
      uri = URI("#{@base_url}#{path}")
      http_request = method_class.new(uri)
      http_request["Authorization"] = @api_key

      if json_body
        http_request["Content-Type"] = "application/json"
        http_request.body = json_body.to_json
      end

      execute(uri, http_request, parse_json: parse_json)
    end

    def execute(uri, http_request, parse_json: true, attempt: 0)
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.open_timeout = 10
        http.read_timeout = 30
        http.request(http_request)
      end

      if response.code.to_i == 429 && attempt < MAX_RETRIES
        retry_after = response["Retry-After"]
        if retry_after
          sleep(retry_after.to_f)
          return execute(uri, http_request, parse_json: parse_json, attempt: attempt + 1)
        end
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise ApiError.new(
          "Documenso API Error (#{response.code}): #{response.body}",
          status_code: response.code.to_i,
          body: response.body
        )
      end

      return response.body unless parse_json

      parse_body(response)
    end

    def parse_body(response)
      body = response.body
      return {} if body.nil? || body.empty?

      content_type = response["Content-Type"].to_s
      if content_type.include?("application/json") || body.lstrip.start_with?("{", "[")
        JSON.parse(body)
      else
        body
      end
    end
  end
end
