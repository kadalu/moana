require "http/client"

require "moana_types"

require "./helpers"

module MoanaClient
  class App
    def initialize(@ctx : ClientContext, @user_id : String, @app_id : String)
    end

    def self.create(ctx : ClientContext, email : String, password : String)
      response = MoanaClient.http_post(
        "#{ctx.url}/api/v1/apps",
        {email: email, password: password}.to_json,
        headers: MoanaClient.auth_header(ctx)
      )
      if response.status_code == 201
        MoanaTypes::App.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.all(ctx : ClientContext)
      url = "#{ctx.url}/api/v1/apps"
      response = MoanaClient.http_get(url, headers: MoanaClient.auth_header(ctx))
      if response.status_code == 200
        Array(MoanaTypes::App).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def delete
      url = "#{@ctx.url}/api/v1/apps/#{@user_id}/#{@app_id}"
      response = MoanaClient.http_delete(url, headers: MoanaClient.auth_header(@ctx))

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end
  end
end
