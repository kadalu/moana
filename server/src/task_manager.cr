module TaskManager
  class ClusterStatusTasks
    getter id

    @terminated = false

    def initialize(@id : String, connection_manager : ConnectionManager::Manager)
      spawn do
        loop do
          break if @terminated

          sleep 5.seconds
        end
      end
    end

    def stop
      @terminated = true
    end
  end

  class ClusterTasks
    getter id

    @terminated = false

    def initialize(@id : String, connection_manager : ConnectionManager::Manager)
      spawn do
        loop do
          break if @terminated

          MoanaDB.list_open_tasks(@id).each do |task|
            begin
              responses = connection_manager.task(
                @id,
                ConnectionManager::Task.new(task.id, task.to_json),
                task.participating_nodes.map { |node| node.id },
                timeout: 120
              )
              # TODO: Handle responses and update Task table
            rescue ex : ConnectionManager::NotOnlineException
              MoanaDB.update_task(
                task.id,
                MoanaTypes::TASK_STATE_FAILED,
                {
                  "error"             => ex.message,
                  "offline_nodes"     => ex.ids,
                  "partial_responses" => ex.responses,
                }.to_json
              )
            rescue ex : ConnectionManager::TimeoutException
              MoanaDB.update_task(
                task.id,
                MoanaTypes::TASK_STATE_FAILED,
                {
                  "error"             => ex.message,
                  "partial_responses" => ex.responses,
                }.to_json
              )
            end
          end

          sleep 5.seconds
        end
      end
    end

    def stop
      @terminated = true
    end
  end

  def self.new(connections : ConnectionManager::Manager)
    cluster_tasks = Hash(String, ClusterTasks).new
    cluster_status_tasks = Hash(String, ClusterStatusTasks).new
    spawn do
      loop do
        new_clusters = MoanaDB.list_cluster_ids

        # Remove task managers of Deleted Clusters
        deleted_clusters = cluster_tasks.select { |cluster_id, _| new_clusters.includes?(cluster_id) }
        deleted_clusters.each do |cluster_id, _|
          cluster_tasks[cluster_id].stop
          cluster_status_tasks[cluster_id].stop
          cluster_tasks.delete(cluster_id)
          cluster_status_tasks.delete(cluster_id)
        end

        # Start Task manager of new Clusters if not already started
        new_clusters.each do |cluster_id|
          if !cluster_tasks[cluster_id]?
            cluster_tasks[cluster_id] = ClusterTasks.new(cluster_id, connections)
            cluster_status_tasks[cluster_id] = ClusterStatusTasks.new(cluster_id, connections)
          end
        end

        sleep 5.seconds
      end
    end
  end
end
