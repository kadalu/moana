require "spec"

require "moana_types"

require "../src/*"

describe Volfile do
  it "generates a shd volfile for replicate/disperse volumes" do
    volumes = File.open("./spec/replica_volumes.json") do |file|
      Array(MoanaTypes::Volume).from_json(file)
    end

    shd_tmpl = File.read("./spec/shd_template.yaml")
    content = Volfile.pool_level("shd", shd_tmpl, volumes)
    content.should eq(File.read("./spec/shd.vol"))
  end
end
