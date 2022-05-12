from kadalu_storage import StorageManager


def test_pool_apis():
    mgr = StorageManager("http://server1:3000")
    mgr.create_user("admin", "admin", "kadalu")
    mgr.user("admin").login("kadalu")
    mgr.create_pool("DEV")
    pools = mgr.list_pools()
    assert len(pools) == 1
    mgr.pool("DEV").delete()
    pools = mgr.list_pools()
    assert len(pools) == 0
    mgr.user("admin").logout()
