# noqa # pylint: disable=missing-module-docstring

from kadalu_storage.helpers import response_object_or_error


class Pool:
    # noqa # pylint: disable=missing-class-docstring
    def __init__(self, mgr, name):
        self.mgr = mgr
        self.name = name

    @classmethod
    def list(cls, mgr, state = False):
        # noqa # pylint: disable=missing-function-docstring
        resp = mgr.http_get(f'{mgr.url}/api/v1/pools?state={1 if state else 0}')
        return response_object_or_error("Pool", resp, 200)

    @classmethod
    def create(cls, mgr, name, distribute_groups, options=None):
        # noqa # pylint: disable=missing-function-docstring
        # noqa # pylint: disable=too-many-arguments
        options = {} if options is None else options
        resp = mgr.http_post(
            f"{mgr.url}/api/v1/pools",
            {
                "name": name,
                "distribute_groups": distribute_groups,
                "no_start": options.get("no_start", False),
                "distribute": options.get("distribute", False),
                "pool_id": options.get("pool_id", ""),
                "auto_add_nodes": options.get("auto_add_nodes", False),
                "options": options.get("options", {})
            }
        )
        return response_object_or_error("Pool", resp, 201)

    def start(self):
        """
        == Start a Kadalu Storage Pool

        Start a Kadalu Storage Pool

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("pool1").start()
        ----
        """
        resp = self.mgr.http_post(
            f"{self.mgr.url}/api/v1/pools/{self.name}/start"
        )
        return response_object_or_error("Pool", resp, 200)

    def stop(self):
        """
        == Stop a Kadalu Storage Pool

        Stop a Kadalu Storage Pool

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("pool1").stop()
        ----
        """
        resp = self.mgr.http_post(
            f"{self.mgr.url}/api/v1/pools/{self.name}/stop"
        )
        return response_object_or_error("Pool", resp, 200)

    def delete(self):
        """
        == Delete a Kadalu Storage Pool

        Delete a Kadalu Storage Pool

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("pool1").delete()
        ----
        """
        url = f"{self.mgr.url}/api/v1/pools/{self.name}"
        resp = self.mgr.http_delete(url)
        return response_object_or_error("Pool", resp, 204)
