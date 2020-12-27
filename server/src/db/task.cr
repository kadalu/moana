require "json"
require "uuid"

require "moana_types"
require "sqlite3"

TASK_SELECT_QUERY = <<-SQL
  SELECT id,
         node_id,
         type,
         state,
         data,
         response
  FROM tasks
SQL

module MoanaDB
  def self.create_table_tasks(conn = @@conn)
    conn.not_nil!.exec "CREATE TABLE IF NOT EXISTS tasks (
       id         UUID PRIMARY KEY,
       cluster_id UUID,
       node_id    UUID,
       type       VARCHAR,
       state      VARCHAR,
       data       TEXT,
       response   TEXT,
       created_at TIMESTAMP,
       updated_at TIMESTAMP
    );"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS tasks_cluster_id_idx ON tasks (cluster_id);"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS tasks_node_id_idx ON tasks (node_id);"
  end

  def self.list_tasks(conn = @@conn)
    conn.not_nil!.query_all(TASK_SELECT_QUERY, as: MoanaTypes::Task)
  end

  def self.list_tasks(cluster_id : String, conn = @@conn)
    conn.not_nil!.query_all("#{TASK_SELECT_QUERY} WHERE cluster_id = ?", cluster_id, as: MoanaTypes::Task)
  end

  def self.list_tasks(cluster_id : String, node_id : String, conn = @@conn)
    conn.not_nil!.query_all("#{TASK_SELECT_QUERY} WHERE cluster_id = ? AND node_id = ?", cluster_id, node_id, as: MoanaTypes::Task)
  end

  def self.get_task(id : String, conn = @@conn)
    tasks = conn.not_nil!.query_all("#{TASK_SELECT_QUERY} WHERE id = ?", id, as: MoanaTypes::Task)

    return nil if tasks.size == 0
    tasks[0]
  end

  def self.create_task(cluster_id : String, node_id : String, task_type : String, data : String, conn = @@conn)
    query = "INSERT INTO tasks(id, cluster_id, node_id, type, state, data, response, created_at, updated_at)
             VALUES           (?,  ?,          ?,       ?,    ?,     ?,    ?,        datetime(), datetime());"

    task_id = UUID.random.to_s
    conn.not_nil!.exec(
      query,
      task_id,
      cluster_id,
      node_id,
      task_type,
      "Queued",
      data,
      "{}"
    )

    get_task(task_id)
  end

  def self.update_task(id : String, state : String? = nil, response : String? = nil, conn = @@conn)
    query = "UPDATE tasks SET "
    params = [] of DB::Any
    if !state.nil?
      query += "state = ?, "
      params << state
    end

    if !response.nil?
      query += "response = ?, "
      params << response
    end

    params << id

    query += "updated_at = datetime() WHERE id = ?"

    conn.not_nil!.exec(query, args: params)

    get_task(id)
  end

  def self.delete_task(id : String, conn = @@conn)
    query = "DELETE FROM tasks WHERE id = ?"
    @@conn.not_nil!.exec(query, id)
  end
end
