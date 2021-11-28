require "uuid"
require "json"

module Datastore
  class_property rootdir = ""

  class DatastoreError < Exception
  end
end
