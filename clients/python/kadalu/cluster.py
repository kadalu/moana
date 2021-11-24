import json

from kadalu.helpers import APIError, http_post


class Cluster:
    def __init__(self, name):
        self.name = name

    @classmethod
    def create(cls, mgr, name):
        req = http_post(mgr.url + "/api/v1/clusters", {"name": name})
        resp = json.loads(req.data.decode('utf-8'))
        if req.status == 201:
            return resp

        raise APIError(resp["error"], req.status)
