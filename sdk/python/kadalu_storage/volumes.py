# noqa # pylint: disable=missing-module-docstring

from kadalu_storage.helpers import response_object_or_error


class Volume:
    # noqa # pylint: disable=missing-class-docstring
    def __init__(self, mgr, pool_name, volume_name):
        self.mgr = mgr
        self.pool_name = pool_name
        self.volume_name = volume_name

    @classmethod
    def list(cls, mgr, pool_name=None, state = False):
        # noqa # pylint: disable=missing-function-docstring
        url_part = "/volumes" if pool_name is None else "/pools/{pool_name}/volumes"
        resp = mgr.http_get(f'{mgr.url}/api/v1{url_part}?state={1 if state else 0}')
        return response_object_or_error("Volume", resp, 200)

    @classmethod
    def create(cls, mgr, pool_name, volume_name, distribute_groups, options=None):
        # noqa # pylint: disable=missing-function-docstring
        # noqa # pylint: disable=too-many-arguments
        options = {} if options is None else options
        resp = mgr.http_post(
            f"{mgr.url}/api/v1/pools/{pool_name}/volumes",
            {
                "name": volume_name,
                "distribute_groups": distribute_groups,
                "no_start": options.get("no_start", False),
                "volume_id": options.get("volume_id", ""),
                "auto_create_pool": options.get("auto_create_pool", False),
                "auto_add_nodes": options.get("auto_add_nodes", False),
                "options": options.get("options", {})
            }
        )
        return response_object_or_error("Volume", resp, 201)

    def start(self):
        """
        == Start a Kadalu Storage Volume

        Start a Kadalu Storage Volume

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("DEV").volume("vol1").start()
        ----
        """
        resp = self.mgr.http_post(
            f"{self.mgr.url}/api/v1/pools/{self.pool_name}"
            f"/volumes/{self.volume_name}/start",
        )
        return response_object_or_error("Volume", resp, 200)

    def stop(self):
        """
        == Stop a Kadalu Storage Volume

        Stop a Kadalu Storage Volume

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("DEV").volume("vol1").stop()
        ----
        """
        resp = self.mgr.http_post(
            f"{self.mgr.url}/api/v1/pools/{self.pool_name}"
            f"/volumes/{self.volume_name}/stop",
        )
        return response_object_or_error("Volume", resp, 200)

    def delete(self):
        """
        == Delete a Kadalu Storage Volume

        Delete a Kadalu Storage Volume

        Example:

        [source,python]
        ----
        from kadalu_storage import StorageManager

        mgr = StorageManager("http://localhost:3000")

        mgr.pool("DEV").volume("vol1").delete()
        ----
        """
        url = f"{self.mgr.url}/api/v1/pools/{self.pool_name}/volumes/{self.volume_name}"
        resp = self.mgr.http_delete(url)
        return response_object_or_error("Volume", resp, 204)
