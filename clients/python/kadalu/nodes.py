import json

from kadalu.helpers import APIError, http_post


class Node:
    def __init__(self, mgr, pool_name, name):
        self.mgr = mgr
        self.pool_name = pool_name
        self.name = name

    @classmethod
    def add(cls, mgr, pool_name, name, endpoint):
        req = http_post(f"{mgr.url}/api/v1/pools/{pool_name}/nodes",
                        {"name": name, "endpoint": endpoint})
        resp = json.loads(req.data.decode('utf-8'))
        if req.status == 201:
            return resp

        raise APIError(resp["error"], req.status)
