# noqa # pylint: disable=missing-module-docstring
from kadalu_storage.pools import Pool
from kadalu_storage.nodes import Node
from kadalu_storage.users import User
from kadalu_storage.helpers import StorageManagerBase


class StorageManager(StorageManagerBase):
    """Kadalu Storage Manager"""
    def __init__(self, url):
        """
        == Kadalu Storage Manager instance.

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")
        ----
        """
        self.url = url.strip("/")
        super().__init__()

    def add_node(self, node_name, endpoint=""):
        """
        == Add a node to a Pool

        Add a node to a Pool

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.add_node(
            "server1",
            "http://localhost:3000"
        )
        ----
        """
        return Node.add(self, node_name, endpoint)

    def node(self, node_name):
        """
        == Node instance

        Node instance

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.node("server1.example.com")
        ----
        """
        return Node(self, node_name)

    def list_nodes(self):
        """
        == List nodes of a Pool

        List nodes of a Pool

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.list_nodes()
        ----
        """
        return Node.list(self)

    def list_pools(self):
        """
        == List Kadalu Storage Pools

        List Kadalu Storage Pools

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.list_pools()
        ----
        """
        return Pool.list(self)

    def create_pool(self, pool_name, distribute_groups, options=None):
        """
        == Create a Kadalu Storage Pool

        Create a Kadalu Storage Pool

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.create_pool(
            "pool1",
            "distribute_groups": [
              {
               "replica_count": 3,
               "storage_units": [
                  {"node": "server1.example.com", "path": "/exports/pool1/s1/storage"},
                  {"node": "server2.example.com", "path": "/exports/pool1/s2/storage"},
                  {"node": "server3.example.com", "path": "/exports/pool1/s3/storage"}
                ]
              }
            ]
        )
        ----
        """
        return Pool.create(
            self,
            pool_name,
            distribute_groups,
            options
        )

    def pool(self, pool_name):
        """
        == Pool instance

        Pool instance

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("pool1")
        ----
        """
        return Pool(self, pool_name)

    def create_user(self, username, name, password):
        """
        == Create a new User

        Create a new User

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.create_user("admin", "Admin", "secret")
        ----
        """
        return User.create(self, username, name, password)

    def has_users(self):
        """
        == Zero users in the instance

        Check if no users created

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        print(mgr.has_users())
        ----
        """
        return User.has_users(self)

    def user(self, username):
        """
        == User instance

        User instance

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.user("admin")
        ----
        """
        return User(self, username)
