# noqa # pylint: disable=missing-module-docstring

from kadalu_storage.helpers import response_object_or_error, json_from_response
from kadalu_storage.api_keys import ApiKey


class User:
    # noqa # pylint: disable=missing-class-docstring
    def __init__(self, mgr, username):
        self.mgr = mgr
        self.username = username

    @classmethod
    def list(cls, mgr):
        # noqa # pylint: disable=missing-function-docstring
        resp = mgr.http_get(mgr.url + "/api/v1/users")
        return response_object_or_error("User", resp, 200)

    @classmethod
    def has_users(cls, mgr):
        # noqa # pylint: disable=missing-function-docstring
        resp = mgr.http_get(mgr.url + "/api/v1/user-exists")
        return resp.status == 200

    @classmethod
    def create(cls, mgr, username, name, password):
        # noqa # pylint: disable=missing-function-docstring
        resp = mgr.http_post(f"{mgr.url}/api/v1/users",
                         {"name": name, "username": username,
                          "password": password})
        return response_object_or_error("User", resp, 201)

    def login(self, password):
        """
        == Login to Kadalu Storage

        Login to Kadalu Storage

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.user("admin").login("secret")
        ----
        """
        resp = self.mgr.http_post(
            f"{self.mgr.url}/api/v1/users/{self.username}/api-keys",
            {"password": password}
        )
        if resp.status == 201:
            data = json_from_response(resp)
            self.mgr.api_key_id = data["id"]
            self.mgr.user_id = data["user_id"]
            self.mgr.username = self.username
            self.mgr.token = data["token"]

        return response_object_or_error("ApiKey", resp, 201)

    def logout(self):
        """
        == Logout from Kadalu Storage

        Logout from Kadalu Storage

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.user("admin").logout()
        ----
        """
        url = f"{self.mgr.url}/api/v1/api-keys/{self.mgr.api_key_id}"
        resp = self.mgr.http_delete(url)

        if resp.status == 204:
            self.mgr.api_key_id = ""
            self.mgr.user_id = ""
            self.mgr.username = ""
            self.mgr.token = ""

        return response_object_or_error("User", resp, 204)

    def set_password(self, password, new_password):
        """
        == Set user password

        Set Kadalu Storage user password

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.user("admin").set_password("secret", "new_secret")
        ----
        """
        resp = self.mgr.http_post(
            f"{self.mgr.url}/api/v1/users/{self.mgr.username}/password",
            {"password": password, "new_password": new_password}
        )
        return response_object_or_error("User", resp, 200)

    def create_api_key(self, name):
        """
        == Create a new API Key

        Create a new API Key

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.user("admin").create_api_key("mobile_app")
        ----
        """
        return ApiKey.create(self.mgr, name)

    def list_api_keys(self):
        """
        == List API Keys

        List API Keys

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.user("admin").list_api_keys()
        ----
        """
        return ApiKey.list(self.mgr)

    def api_key(self, api_key_id):
        """
        == API Key instance

        API Key instance

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.user("admin").api_key("801bbbb7-375b-4f04-89f6-ad9e9728689e")
        ----
        """
        return ApiKey(self.mgr, api_key_id)

    def delete(self, username=None):
        """
        == Delete a User

        Delete a User

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.user("admin").delete()

        # Delete other user if admin
        mgr.user("admin").delete("user1")
        ----
        """
        if username is None:
            username = self.mgr.username
        url = f"{self.mgr.url}/api/v1/users/{username}"
        resp = self.mgr.http_delete(url)

        if resp.status == 204:
            if username == self.mgr.username:
                self.mgr.api_key_id = ""
                self.mgr.user_id = ""
                self.mgr.username = ""
                self.mgr.token = ""

        return response_object_or_error("User", resp, 204)
