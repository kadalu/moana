require "spec"

require "moana_types"

require "../src/*"

describe Volfile do
  it "generates a client volfile for distribute volume" do
    volume = File.open("./spec/dist_vol.json") do |file|
      MoanaTypes::Volume.from_json(file)
    end

    client1_tmpl = File.read("./spec/client1_template.yaml")
    content = Volfile.volume_level("client", client1_tmpl, volume)
    content.should eq(File.read("./spec/dist_client.vol"))
  end

  it "generates a client volfile for replica 3 volume" do
    volume = File.open("./spec/rep3_vol.json") do |file|
      MoanaTypes::Volume.from_json(file)
    end

    client1_tmpl = File.read("./spec/client1_template.yaml")
    content = Volfile.volume_level("client", client1_tmpl, volume)
    content.should eq(File.read("./spec/rep3_client.vol"))
  end

  it "generates a client volfile for distributed replica 3 volume" do
    volume = File.open("./spec/distrep3_vol.json") do |file|
      MoanaTypes::Volume.from_json(file)
    end

    client1_tmpl = File.read("./spec/client1_template.yaml")
    content = Volfile.volume_level("client", client1_tmpl, volume)
    content.should eq(File.read("./spec/distrep3_client.vol"))
  end
end
