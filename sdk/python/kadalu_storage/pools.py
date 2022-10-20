# noqa # pylint: disable=missing-module-docstring

from kadalu_storage.helpers import response_object_or_error
from kadalu_storage.nodes import Node
from kadalu_storage.volumes import Volume


class Pool:
    # noqa # pylint: disable=missing-class-docstring
    def __init__(self, mgr, name):
        self.mgr = mgr
        self.name = name

    @classmethod
    def create(cls, mgr, name):
        # noqa # pylint: disable=missing-function-docstring
        resp = mgr.http_post(mgr.url + "/api/v1/pools", {"name": name})
        return response_object_or_error("Pool", resp, 201)

    @classmethod
    def list(cls, mgr):
        # noqa # pylint: disable=missing-function-docstring
        resp = mgr.http_get(mgr.url + "/api/v1/pools")
        return response_object_or_error("Pool", resp, 200)

    def add_node(self, node_name, endpoint=""):
        """
        == Add a node to a Pool

        Add a node to a Pool

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("DEV").add_node(
            "server1",
            "http://localhost:3000"
        )
        ----
        """
        return Node.add(self.mgr, self.name, node_name, endpoint)

    def node(self, node_name):
        """
        == Node instance

        Node instance

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("DEV").node("server1.example.com")
        ----
        """
        return Node(self.mgr, self.name, node_name)

    def list_nodes(self):
        """
        == List nodes of a Pool

        List nodes of a Pool

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("DEV").list_nodes()
        ----
        """
        return Node.list(self.mgr, self.name)

    def list_volumes(self):
        """
        == List volumes of a Pool

        List volumes of a Pool

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("DEV").list_volumes()
        ----
        """
        return Volume.list(self.mgr, self.name)

    def create_volume(self, volume_name, distribute_groups, options=None):
        """
        == Create a Kadalu Storage Volume

        Create a Kadalu Storage Volume

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("DEV").create_volume(
            "vol1",
            "distribute_groups": [
              {
               "replica_count": 3,
               "storage_units": [
                  {"node": "server1.example.com", "path": "/exports/vol1/s1/storage"},
                  {"node": "server2.example.com", "path": "/exports/vol1/s2/storage"},
                  {"node": "server3.example.com", "path": "/exports/vol1/s3/storage"}
                ]
              }
            ]
        )
        ----
        """
        return Volume.create(
            self.mgr,
            self.name,
            volume_name,
            distribute_groups,
            options
        )

    def volume(self, volume_name):
        """
        == Volume instance

        Volume instance

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("DEV").volume("vol1")
        ----
        """
        return Volume(self.mgr, self.name, volume_name)

    def delete(self):
        """
        == Delete a Pool

        Delete a Pool

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("DEV").delete()
        ----
        """
        url = f"{self.mgr.url}/api/v1/pools/{self.name}"
        resp = self.mgr.http_delete(url)
        return response_object_or_error("Pool", resp, 204)
