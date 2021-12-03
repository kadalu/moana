import json

from kadalu.helpers import APIError, http_post
from kadalu.nodes import Node


class Pool:
    def __init__(self, mgr, name):
        self.mgr = mgr
        self.name = name

    @classmethod
    def create(cls, mgr, name):
        req = http_post(mgr.url + "/api/v1/pools", {"name": name})
        resp = json.loads(req.data.decode('utf-8'))
        if req.status == 201:
            return resp

        raise APIError(resp["error"], req.status)

    def join_node(self, node_name, endpoint):
        """
        == Join a node to a Pool

        Join a node to a Pool

        Example:

        [source,python]
        ----
        from kadalu import StorageManager

        sm = StorageManager("http://localhost:3000")

        sm.pool("DEV").join_node(
            "server1",
            "http://localhost:3000"
        )
        ----
        """
        return Node.join(self.mgr, self.name, node_name, endpoint)
