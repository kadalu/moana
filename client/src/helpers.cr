require "http/client"

require "moana_types"

module MoanaClient
  extend self

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

  private def self.http_put(url, body_json)
    HTTP::Client.put(
      url,
      body: body_json,
      headers: HTTP::Headers{"Content-Type" => "application/json"}
    )
  end

  private def self.http_post(url, body_json)
    HTTP::Client.post(
      url,
      body: body_json,
      headers: HTTP::Headers{"Content-Type" => "application/json"}
    )
  end

  private def self.http_get(url)
    HTTP::Client.get url
  end

  private def self.http_delete(url)
    HTTP::Client.delete url
  end
end
