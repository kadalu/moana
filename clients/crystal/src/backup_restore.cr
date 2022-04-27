module MoanaClient
  class Backup
    def initialize(@client : Client, @backupdir : String)
    end

    def self.backup(client : Client, backupdir : String)
      url = "#{client.url}/api/v1/backup"

      response = MoanaClient.http_post(
        url,
        backupdir.to_json,
        headers: client.auth_header
      )

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end
  end

  class Restore
    def initialize(@client : Client, @backupdir : String)
    end

    def self.restore(client : Client, backupdir : String)
      url = "#{client.url}/api/v1/restore"

      response = MoanaClient.http_post(
        url,
        backupdir.to_json,
        headers: client.auth_header
      )

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end
  end
end
