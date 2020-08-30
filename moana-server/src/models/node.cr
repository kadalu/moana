class Node < Granite::Base
  connection pg
  table nodes

  belongs_to :cluster, foreign_key: cluster_id : String
  has_many :tasks, class_name: Task
  has_many :bricks, class_name: Brick

  column id : String, primary: true, auto: false
  column hostname : String?
  column endpoint : String?
  timestamps
  before_create :assign_id

  def assign_id
    @id = UUID.random.to_s
  end
end
