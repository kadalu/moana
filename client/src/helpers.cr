require "http/client"

require "moana_types"

module MoanaClient
  extend self

  def auth_header(ctx)
    return nil if (ctx.token == "")

    headers = HTTP::Headers{
      "Authorization" => "Bearer #{ctx.token}"
    }

    if ctx.user_id != ""
      headers["X-User-ID"] = ctx.user_id
    end

    if ctx.node_id != ""
      headers["X-Node-ID"] = ctx.node_id
    end

    headers
  end

  class MoanaClientException < Exception
    property message, status_code

    def initialize(@message : String, @status_code : Int32)
      super(@message)
    end
  end

  def error_response(response : HTTP::Client::Response)
    err = MoanaTypes::Error.from_json(response.body)
    raise MoanaClientException.new(err.error, response.status_code)
  end

  def http_put(url, body_json, headers : HTTP::Headers? = nil)
    headers = HTTP::Headers.new if headers.nil?
    headers["Content-Type"] = "application/json"

    HTTP::Client.put(url, body: body_json, headers: headers)
  end

  def http_post(url, body_json, headers : HTTP::Headers? = nil)
    headers = HTTP::Headers.new if headers.nil?
    headers["Content-Type"] = "application/json"

    HTTP::Client.post(url, body: body_json, headers: headers)
  end

  def http_get(url, headers : HTTP::Headers? = nil)
    HTTP::Client.get(url, headers: headers)
  end

  def http_delete(url, headers : HTTP::Headers? = nil)
    HTTP::Client.delete(url, headers: headers)
  end
end
