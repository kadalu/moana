import json

from kadalu.helpers import APIError, http_post


class Node:
    def __init__(self, mgr, cluster_name, name):
        self.mgr = mgr
        self.cluster_name = cluster_name
        self.name = name

    @classmethod
    def join(cls, mgr, cluster_name, name, endpoint):
        req = http_post(f"{mgr.url}/api/v1/clusters/{cluster_name}/nodes",
                        {"name": name, "endpoint": endpoint})
        resp = json.loads(req.data.decode('utf-8'))
        if req.status == 201:
            return resp

        raise APIError(resp["error"], req.status)
