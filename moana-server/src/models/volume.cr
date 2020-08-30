class Volume < Granite::Base
  connection pg
  table volumes

  belongs_to :cluster, foreign_key: cluster_id : String
  has_many :bricks, class_name: Brick

  column id : String, primary: true, auto: false
  column name : String?
  column state : String?
  column type : String?
  timestamps
  before_create :assign_id

  def assign_id
    @id = UUID.random.to_s
  end
end
