# noqa # pylint: disable=missing-module-docstring
from kadalu_storage.pools import Pool
from kadalu_storage.nodes import Node
from kadalu_storage.volumes import Volume
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

    def create_pool(self, name):
        """
        == Create a new Pool

        Create a new Pool

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.create_pool("DEV")
        ----
        """
        return Pool.create(self, name)

    def pool(self, name):
        """
        == Pool instance

        Pool instance

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("DEV")
        ----
        """
        return Pool(self, name)

    def list_pools(self):
        """
        == List Kadalu Storage Pools

        List Pools

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.list_pools()
        ----
        """
        return Pool.list(self)

    def list_nodes(self, state=False):
        """
        == List Kadalu Storage Nodes

        List Nodes

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.list_nodes()
        ----
        """
        return Node.list(self, state=state)

    def list_volumes(self, state=False):
        """
        == List Kadalu Storage Volumes

        List Volumes

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.list_volumes()
        ----
        """
        return Volume.list(self, state=state)

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
