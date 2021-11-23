require "http/client"

require "moana_types"

require "./helpers"

module MoanaClient
  class Role
    def initialize(@ctx : ClientContext, @user_id : String, @cluster_id : String, @volume_id : String, @role : String)
    end

    def self.create(ctx : ClientContext, user_id : String, cluster_id : String, volume_id : String, role : String)
      response = MoanaClient.http_post(
        "#{ctx.url}/api/v1/roles",
        {user_id: user_id, cluster_id: cluster_id, volume_id: volume_id, name: role}.to_json,
        headers: MoanaClient.auth_header(ctx)
      )
      if response.status_code == 201
        MoanaTypes::Role.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def delete
      url = "#{@ctx.url}/api/v1/roles/#{@user_id}/#{@cluster_id}/#{@volume_id}/#{@role}"
      response = MoanaClient.http_delete(url, headers: MoanaClient.auth_header(@ctx))

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end
  end
end
