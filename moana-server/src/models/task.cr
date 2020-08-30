class Task < Granite::Base
  connection pg
  table tasks

  belongs_to :cluster, foreign_key: cluster_id : String
  belongs_to :node, foreign_key: node_id : String

  column id : String, primary: true, auto: false
  column data : String?
  column state : String?
  column type : String?
  column response : String?
  timestamps
  before_create :assign_id

  def assign_id
    @id = UUID.random.to_s
  end
end
