module Datastore
  def insert_query(table_name, fields, replace = false)
    replace_str = replace ? " OR REPLACE " : ""
    String.build do |stmt|
      stmt << "INSERT #{replace_str} INTO #{table_name} ("
      stmt << fields.map { |name| "#{name}" }.join(", ")
      stmt << ", created_on, updated_on) VALUES ("
      stmt << fields.map { |_| "?" }.join(", ")
      stmt << ", datetime(), datetime())"
    end
  end

  def update_query(table_name, fields, where = "")
    String.build do |stmt|
      stmt << "UPDATE #{table_name} SET "
      stmt << fields.map { |name| "#{name}=?" }.join(", ")
      stmt << ", updated_on = datetime() "
      stmt << " WHERE #{where}" if where != ""
    end
  end
end
