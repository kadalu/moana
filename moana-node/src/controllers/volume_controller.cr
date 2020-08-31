class VolumeController < ApplicationController
  def create
    # task = request.get_json()
    # volume_data = copy.copy(task)
    # del volume_data["bricks"]

    # for brick in task["bricks"]:
    #     if os.environ["NODE_ID"] != brick["node"]["id"]:
    #         continue

    #     try:
    #         brick.update(volume_data)
    #         brick["volume_id"] = task["id"]
    #         brick["volname"] = task["name"]
    #         if brick["device"] != "":
    #             brick["mount_path"] = os.path.dirname(brick["path"])

    #         brickutils.create(brick)
    #     except brickutils.CreateBrickError as err:
    #         return jsonify({"error": f"{err}"}), 500

    # return jsonify({"data": "created"}), 201
    respond_with 201 do
      json "{\"ok\": true}"
    end
  end
end
