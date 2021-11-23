require "http/client"

module MoanaClient
  class ClientException < Exception
    property message, status_code

    def initialize(@message : String, @status_code : Int32)
      super(@message)
    end
  end

  def self.error_response(response : HTTP::Client::Response)
    err = MoanaTypes::Error.from_json(response.body)
    raise ClientException.new(err.error, response.status_code)
  end

  def self.http_put(url, body_json, headers : HTTP::Headers? = nil)
    headers = HTTP::Headers.new if headers.nil?
    headers["Content-Type"] = "application/json"

    HTTP::Client.put(url, body: body_json, headers: headers)
  end

  def self.http_post(url, body_json, headers : HTTP::Headers? = nil)
    headers = HTTP::Headers.new if headers.nil?
    headers["Content-Type"] = "application/json"

    HTTP::Client.post(url, body: body_json, headers: headers)
  end

  def self.http_get(url, headers : HTTP::Headers? = nil)
    HTTP::Client.get(url, headers: headers)
  end

  def self.http_delete(url, headers : HTTP::Headers? = nil)
    HTTP::Client.delete(url, headers: headers)
  end

  class Client
    def auth_header
      return nil if (@token == "")

      headers = HTTP::Headers{
        "Authorization" => "Bearer #{@token}",
      }

      if @user_id != ""
        headers["X-User-ID"] = @user_id
      end

      headers
    end
  end
end
