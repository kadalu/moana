require "spec"

require "../../src/db/*"

describe MoanaDB do
  it "opens the database" do
    MoanaDB.init(".")
    MoanaDB.get_connection.should_not be_nil
  end

  it "creates a Cluster" do
    MoanaDB.init(".")
    cluster = MoanaDB.create_cluster("my_cluster")
    cluster.name.should eq("my_cluster")

    c2 = MoanaDB.get_cluster(cluster.id)
    c2.not_nil!.name.should eq("my_cluster")
    c2.not_nil!.id.should eq(cluster.id)

    c3 = MoanaDB.update_cluster(cluster.id, "my_cluster_renamed")
    c3.not_nil!.id.should eq(cluster.id)
    c3.not_nil!.name.should eq("my_cluster_renamed")

    MoanaDB.delete_cluster(cluster.id)
  end

  it "creates a Node" do
    MoanaDB.init(".")
    cluster = MoanaDB.create_cluster("my_cluster")
    cluster.name.should eq("my_cluster")

    node = MoanaDB.create_node(cluster.id, "node1.example.com", "node1.example.com:5002")
    node.hostname.should eq("node1.example.com")
    node.endpoint.should eq("node1.example.com:5002")

    nodes = MoanaDB.list_nodes(cluster.id)
    nodes.size.should eq(1)

    n2 = MoanaDB.get_node(node.id)
    n2.not_nil!.id.should eq(node.id)
    n2.not_nil!.hostname.should eq("node1.example.com")
    n2.not_nil!.endpoint.should eq("node1.example.com:5002")

    n3 = MoanaDB.update_node(node.id, hostname: "node2.example.com")
    n3.not_nil!.hostname.should eq("node2.example.com")

    n4 = MoanaDB.update_node(node.id, endpoint: "node2.example.com:5003")
    n4.not_nil!.endpoint.should eq("node2.example.com:5003")

    MoanaDB.delete_node(node.id)
  end
end
