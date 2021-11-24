from kadalu.cluster import Cluster


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

    def create_cluster(self, name):
        """
        == Create a new Cluster

        Create a new Cluster

        Example:

        [source,python]
        ----
        from kadalu import StorageManager

        sm = StorageManager("http://localhost:3000")

        sm.create_cluster("mycluster")
        ----
        """
        return Cluster.create(self, name)
