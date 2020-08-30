class Brick < Granite::Base
  connection pg
  table bricks

  belongs_to :cluster, foreign_key: cluster_id : String
  belongs_to :volume, foreign_key: volume_id : String
  belongs_to :node, foreign_key: node_id : String

  column id : String, primary: true, auto: false
  column path : String?
  column device : String?
  column port : Int32?
  column state : String?
  timestamps
  before_create :assign_id

  def assign_id
    @id = UUID.random.to_s
  end
end
