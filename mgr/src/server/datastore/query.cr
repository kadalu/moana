module Datastore
  def self.insert_query(table_name, fields)
    String.build do |stmt|
      stmt << "INSERT INTO #{table_name} ("
      stmt << fields.map { |name| "#{name}" }.join(", ")
      stmt << ", created_on, updated_on) VALUES ("
      stmt << fields.map { |_| "?" }.join(", ")
      stmt << ", datetime(), datetime())"
    end
  end

  def self.update_query(table_name, fields, where = "")
    String.build do |stmt|
      stmt << "UPDATE #{table_name} SET "
      stmt << fields.map { |name| "#{name}=?" }.join(", ")
      stmt << ", updated_on = datetime() "
      stmt << " WHERE #{where}" if where != ""
    end
  end
end
