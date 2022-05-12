from kadalu_storage import StorageManager


def test_user_apis():
    mgr = StorageManager("http://server1:3000")
    mgr.create_user("admin", "admin", "kadalu")
    mgr.user("admin").login("kadalu")
    mgr.user("admin").set_password("kadalu", "uladak")
    mgr.user("admin").login("uladak")
    print(mgr.user("admin").list_api_keys())
    api_key = mgr.user("admin").create_api_key("Dev")
    print(mgr.user("admin").list_api_keys())
    mgr.user("admin").api_key(api_key.id).delete()
    mgr.user("admin").logout()
    mgr.user("admin").login("uladak")
    mgr.user("admin").delete()
