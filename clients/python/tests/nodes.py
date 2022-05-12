from kadalu_storage import StorageManager

NODES = ["server1", "server2", "server3"]


def test_node_apis():
    mgr = StorageManager("http://server1:3000")
    mgr.create_user("admin", "admin", "kadalu")
    mgr.user("admin").login("kadalu")
    mgr.create_pool("DEV")
    for node in NODES:
        mgr.pool("DEV").add_node(node)

    print(mgr.pool("DEV").list_nodes())
    for node in NODES:
        mgr.pool("DEV").node(node).remove()
    
    # Add and remove again to see node cleanup happens after remove
    for node in NODES:
        mgr.pool("DEV").add_node(node)
        mgr.pool("DEV").node(node).remove()

    mgr.pool("DEV").delete()
    pools = mgr.list_pools()
    assert len(pools) == 0
    mgr.user("admin").logout()
