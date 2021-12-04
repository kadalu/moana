from kadalu.pools import Pool


class StorageManager:
    def __init__(self, url):
        """
        == Kadalu Storage Manager instance.

        Example:

        [source,python]
        ----
        from kadalu import StorageManager

        sm = StorageManager("http://localhost:3000")
        ----
        """
        self.url = url.strip("/")

    def create_pool(self, name):
        """
        == Create a new Pool

        Create a new Pool

        Example:

        [source,python]
        ----
        from kadalu import StorageManager

        sm = StorageManager("http://localhost:3000")

        sm.create_pool("DEV")
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
        from kadalu import StorageManager

        sm = StorageManager("http://localhost:3000")

        sm.pool("DEV")
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
        from kadalu import StorageManager

        sm = StorageManager("http://localhost:3000")

        sm.list_pools()
        ----
        """
        return Pool.list(self)
