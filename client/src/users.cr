require "http/client"

require "moana_types"

require "./helpers"
require "./apps"

module MoanaClient
  class User
    def initialize(@ctx : ClientContext, @user_id : String)
    end

    def self.create(ctx : ClientContext, name : String, email : String, password : String)
      response = MoanaClient.http_post(
        "#{ctx.url}/api/v1/users",
        {name: name, email: email, password: password}.to_json
      )
      if response.status_code == 201
        MoanaTypes::User.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def get
      url = "#{@ctx.url}/api/v1/users/#{@user_id}"
      response = MoanaClient.http_get(url, headers: MoanaClient.auth_header(@ctx))
      if response.status_code == 200
        MoanaTypes::User.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def delete
      url = "#{@ctx.url}/api/v1/users/#{@user_id}"
      response = MoanaClient.http_delete(url, headers: MoanaClient.auth_header(@ctx))

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end

    def apps
      App.all(@ctx)
    end

    def create_app(password)
      App.create(@ctx, @user_id, password)
    end

    def app(app_id)
      App.new(@ctx, @user_id, app_id)
    end
  end
end
