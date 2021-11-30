module MoanaClient
  class Volume
    def initialize(@client : Client, @cluster_name : String, @name : String)
    end

    def self.create(client : Client, cluster_name : String, volume : MoanaTypes::Volume)
      url = "#{client.url}/api/v1/clusters/#{cluster_name}/volumes"

      response = MoanaClient.http_post(
        url,
        volume.to_json,
        headers: client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::Volume.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.create(client : Client, cluster_name : String, name : String, dist_grps : Array(MoanaTypes::VolumeDistributeGroup), no_start = false)
      req = MoanaTypes::Volume.new
      req.name = name
      req.distribute_groups = dist_grps
      req.no_start = no_start
      create(client, cluster_name, req)
    end

    def get_volfile(name : String, storage_unit = "")
      url = "#{@client.url}/api/v1/clusters/#{@cluster_name}/volumes/#{@name}/volfiles/#{name}"
      url += "?storage_unit=#{storage_unit}" if storage_unit != ""

      response = MoanaClient.http_get(
        url,
        headers: @client.auth_header
      )
      if response.status_code == 200
        MoanaTypes::Volfile.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end
  end
end
