import json

from kadalu.helpers import APIError, http_post, http_get
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

    @classmethod
    def list(cls, mgr):
        req = http_get(mgr.url + "/api/v1/pools")
        resp = json.loads(req.data.decode('utf-8'))
        if req.status == 200:
            return resp

        raise APIError(resp["error"], req.status)

    def add_node(self, node_name, endpoint):
        """
        == Add a node to a Pool

        Add a node to a Pool

        Example:

        [source,python]
        ----
        from kadalu import StorageManager

        sm = StorageManager("http://localhost:3000")

        sm.pool("DEV").add_node(
            "server1",
            "http://localhost:3000"
        )
        ----
        """
        return Node.add(self.mgr, self.name, node_name, endpoint)
