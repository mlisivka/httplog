# frozen_string_literal: true

module Net
  class HTTP
    alias orig_request request unless method_defined?(:orig_request)
    alias orig_connect connect unless method_defined?(:orig_connect)

    def request(req, body = nil, &block)
      url = "http://#{@address}:#{@port}#{req.path}"

      bm = Benchmark.realtime do
        @response = orig_request(req, body, &block)
      end
      request_body = if req.body_stream
                       req.body_stream.to_s # read and rewind for RestClient::Payload::Base
                       req.body_stream.rewind rescue NoMethodError # RestClient::Payload::Base has no method rewind
                       req.body_stream.read
                     elsif req.body.nil? || req.body.empty?
                       body
                     else
                       req.body
                     end

      if HttpLog.url_approved?(url) && started?
        HttpLog.call(
          method: req.method,
          url: url,
          request_body: request_body,
          request_headers: req.each_header.collect,
          response_code: @response.code,
          response_body: @response.body,
          response_headers: @response.each_header.collect,
          benchmark: bm,
          encoding: @response['Content-Encoding'],
          content_type: @response['Content-Type']
        )
      end

      @response
    end

    def connect
      HttpLog.log_connection(@address, @port) if !started? && HttpLog.url_approved?("#{@address}:#{@port}")

      orig_connect
    end
  end
end
