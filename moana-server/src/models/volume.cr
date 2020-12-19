class Volume < Granite::Base
  connection pg
  table volumes

  belongs_to :cluster, foreign_key: cluster_id : String
  has_many :bricks, class_name: Brick

  column id : String, primary: true, auto: false
  column name : String
  column state : String
  column type : String
  column replica_count : Int32
  column disperse_count : Int32
  column options : String
  timestamps
end
