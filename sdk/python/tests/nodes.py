from kadalu_storage import StorageManager

NODES = ["server1", "server2", "server3"]


def test_node_apis():
    mgr = StorageManager("http://server1:3000")
    mgr.create_user("admin", "admin", "kadalu")
    mgr.user("admin").login("kadalu")
    for node in NODES:
        mgr.add_node(node)

    print(mgr.list_nodes())
    for node in NODES:
        mgr.node(node).remove()

    # Add and remove again to see node cleanup happens after remove
    for node in NODES:
        mgr.add_node(node)
        mgr.node(node).remove()

    mgr.user("admin").logout()
