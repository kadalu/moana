import json

import urllib3


class APIError(Exception):
    def __init__(self, message, status_code):
        self.message = message
        self.status_code = status_code
        super().__init__(message)


def http_post(url, data):
    http = urllib3.PoolManager()
    encoded_data = json.dumps(data).encode('utf-8')
    req = http.request(
        'POST',
        url,
        body=encoded_data,
        headers={'Content-Type': 'application/json'}
    )

    return req


def http_get(url):
    http = urllib3.PoolManager()
    req = http.request(
        'GET',
        url,
        headers={'Content-Type': 'application/json'}
    )

    return req
