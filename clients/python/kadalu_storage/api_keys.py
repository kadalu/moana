# noqa # pylint: disable=missing-module-docstring
from kadalu_storage.helpers import response_object_or_error


class ApiKey:
    # noqa # pylint: disable=missing-class-docstring
    def __init__(self, mgr, api_key_id):
        self.mgr = mgr
        self.api_key_id = api_key_id

    @classmethod
    def create(cls, mgr, name):
        # noqa # pylint: disable=missing-function-docstring
        resp = mgr.http_post(mgr.url + "/api/v1/api-keys", {"name": name})
        return response_object_or_error("ApiKey", resp, 201)

    @classmethod
    def list(cls, mgr):
        # noqa # pylint: disable=missing-function-docstring
        resp = mgr.http_get(mgr.url + "/api/v1/api-keys")
        return response_object_or_error("ApiKey", resp, 200)

    def delete(self):
        """
        == Create a new API Key

        Create a new API Key

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.user("admin").api_key(
            "801bbbb7-375b-4f04-89f6-ad9e9728689e").delete()
        ----
        """
        resp = self.mgr.http_delete(f"{self.mgr.url}/api/v1/api-keys/{self.api_key_id}")
        return response_object_or_error("ApiKey", resp, 204)
