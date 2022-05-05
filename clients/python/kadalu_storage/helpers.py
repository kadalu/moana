# noqa # pylint: disable=missing-module-docstring
import json

import urllib3


class APIError(Exception):
    # noqa # pylint: disable=missing-class-docstring
    def __init__(self, resp):
        data = json_from_response(resp)
        self.message = data["error"]
        self.status_code = resp.status
        super().__init__(self.message)


class StorageManagerBase:
    # noqa # pylint: disable=missing-class-docstring
    def __init__(self):
        self.token = ""
        self.user_id = ""

    def get_headers(self):
        # noqa # pylint: disable=missing-function-docstring
        headers = {'Content-Type': 'application/json'}
        if self.token != "":
            headers["Authorization"] = f"Bearer {self.token}"

        if self.user_id != "":
            headers["X-User-ID"] = self.user_id

        return headers

    def http_post(self, url, data):
        # noqa # pylint: disable=missing-function-docstring
        http = urllib3.PoolManager()
        encoded_data = json.dumps(data).encode('utf-8')
        resp = http.request(
            'POST',
            url,
            body=encoded_data,
            headers=self.get_headers()
        )

        return resp

    def http_delete(self, url):
        # noqa # pylint: disable=missing-function-docstring
        http = urllib3.PoolManager()
        resp = http.request(
            'DELETE',
            url,
            headers=self.get_headers()
        )

        return resp

    def http_get(self, url):
        # noqa # pylint: disable=missing-function-docstring
        http = urllib3.PoolManager()
        resp = http.request(
            'GET',
            url,
            headers=self.get_headers()
        )

        return resp


# noqa # pylint: disable=too-few-public-methods
class Generic:
    """
    Generic class to convert dict into class object
    """
    def __init__(self, name, data):
        self.class_name = name
        self.class_highlights = []

        for key, val in data.items():
            if isinstance(val, dict):
                setattr(self, key, Generic(key, val))
            elif isinstance(val, list):
                setattr(self, key, to_object(key, val))
            else:
                self.class_highlights.append(val)
                setattr(self, key, val)

    def __str__(self):
        return f'<{self.class_name}({", ".join(self.class_highlights[0:2])},...)>'


def to_object(name, data):
    # noqa # pylint: disable=missing-function-docstring
    if isinstance(data, list):
        return [
            (Generic(name, item) if isinstance(item, dict) else item)
            for item in data
        ]

    return Generic(name, data)


def json_from_response(resp):
    # noqa # pylint: disable=missing-function-docstring
    return json.loads(resp.data.decode('utf-8'))


def response_object_or_error(name, resp, status_code=200):
    # noqa # pylint: disable=missing-function-docstring
    if resp.status == status_code:
        if status_code == 204:
            return None

        return to_object(name, json_from_response(resp))

    raise APIError(resp)
