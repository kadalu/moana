class Cluster < Granite::Base
  connection pg
  table clusters

  column id : String, primary: true, auto: false
  column name : String?
  timestamps
  before_create :assign_id

  def assign_id
    @id = UUID.random.to_s
  end
end
