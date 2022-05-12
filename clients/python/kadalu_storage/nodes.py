# noqa # pylint: disable=missing-module-docstring

from kadalu_storage.helpers import response_object_or_error


class Node:
    # noqa # pylint: disable=missing-class-docstring
    def __init__(self, mgr, pool_name, name):
        self.mgr = mgr
        self.pool_name = pool_name
        self.name = name

    @classmethod
    def list(cls, mgr, pool_name=None, state = False):
        # noqa # pylint: disable=missing-function-docstring
        url_part = "/nodes" if pool_name is None else "/pools/{pool_name}/nodes"
        resp = mgr.http_get(f'{mgr.url}/api/v1{url_part}?state={1 if state else 0}')
        return response_object_or_error("Node", resp, 200)

    @classmethod
    def add(cls, mgr, pool_name, name, endpoint=""):
        # noqa # pylint: disable=missing-function-docstring
        resp = mgr.http_post(f"{mgr.url}/api/v1/pools/{pool_name}/nodes",
                         {"name": name, "endpoint": endpoint})
        return response_object_or_error("Node", resp, 201)

    def remove(self):
        """
        == Remove a node from a Pool

        Remove a node from a Pool

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("DEV").node("server2.example.com").remove()
        ----
        """
        url = f"{self.mgr.url}/api/v1/pools/{self.pool_name}/nodes/{self.name}"
        resp = self.mgr.http_delete(url)
        return response_object_or_error("Node", resp, 204)
