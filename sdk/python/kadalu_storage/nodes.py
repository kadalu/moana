# noqa # pylint: disable=missing-module-docstring

from kadalu_storage.helpers import response_object_or_error


class Node:
    # noqa # pylint: disable=missing-class-docstring
    def __init__(self, mgr, name):
        self.mgr = mgr
        self.name = name

    @classmethod
    def list(cls, mgr, state = False):
        # noqa # pylint: disable=missing-function-docstring
        resp = mgr.http_get(f'{mgr.url}/api/v1/nodes?state={1 if state else 0}')
        return response_object_or_error("Node", resp, 200)

    @classmethod
    def add(cls, mgr, name, endpoint=""):
        # noqa # pylint: disable=missing-function-docstring
        resp = mgr.http_post(f"{mgr.url}/api/v1/nodes",
                         {"name": name, "endpoint": endpoint})
        return response_object_or_error("Node", resp, 201)

    def remove(self):
        """
        == Remove a node from the Cluster

        Remove a node from the Cluster

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.node("server2.example.com").remove()
        ----
        """
        url = f"{self.mgr.url}/api/v1/nodes/{self.name}"
        resp = self.mgr.http_delete(url)
        return response_object_or_error("Node", resp, 204)
