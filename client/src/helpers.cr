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
    err = MoanaTypes::ErrorResponse.from_json(response.body)
    raise MoanaClientException.new(err.error, response.status_code)
  end
end
