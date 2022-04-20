module MoanaClient
  class Backup
    def initialize(@client : Client, @backupdir : String)
    end

    def self.backup(client : Client, backupdir : String)
      url = "#{client.url}/api/v1/backup"

      puts "url", url

      response = MoanaClient.http_post(
        url,
        backupdir.to_json,
        headers: client.auth_header
      )

      puts "response", response

      # if response.status_code == 201
      #   MoanaTypes::Volume.from_json(response.body)
      # else
      #   MoanaClient.error_response(response)
      # end
    end
  end

  class Restore
    def initialize(@client : Client, @targetpath : String)
    end

    def self.restore(client : Client, targetpath : String)
      url = "#{client.url}/api/v1/restore"

      puts "url", url

      response = MoanaClient.http_post(
        url,
        targetpath.to_json,
        headers: client.auth_header
      )

      puts "response", response

      # if response.status_code == 201
      #   MoanaTypes::Volume.from_json(response.body)
      # else
      #   MoanaClient.error_response(response)
      # end
    end
  end
end
