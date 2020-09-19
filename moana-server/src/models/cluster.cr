class Cluster < Granite::Base
  connection pg
  table clusters

  has_many :nodes, class_name: Node
  has_many :tasks, class_name: Task
  has_many :volumes, class_name: Volume
  has_many :bricks, class_name: Brick

  column id : String, primary: true, auto: false
  column name : String
  timestamps
  before_create :assign_id

  def assign_id
    @id = UUID.random.to_s
  end
end
