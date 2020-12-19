class OptionController < ApplicationController
  def index
    if volume = Volume.find params["id"]
      respond_with 200 do
        json volume.options
      end
    else
      results = {status: "volume not found"}
      respond_with 404 do
        json results.to_json
      end
    end
  end

  def setopt
    if volume = Volume.find params["id"]
      options = Hash(String, String).from_json(params.to_unsafe_h["_json"])
      # TODO: Validate Options
      volopts = Hash(String, String).from_json(volume.options)
      volume.options = volopts.merge(options).to_json
      if volume.save
        respond_with 200 do
          json volume.options
        end
      else
        results = {status: "failed to set options"}
        respond_with 500 do
          json results.to_json
        end
      end
    else
      results = {status: "volume not found"}
      respond_with 404 do
        json results.to_json
      end
    end
  end

  def resetopt
    if volume = Volume.find params["id"]
      optnames = Array(String).from_json(params.to_unsafe_h["_json"])
      # TODO: Validate Options
      volopts = Hash(String, String).from_json(volume.options)
      volume.options = volopts.reject!(optnames).to_json
      if volume.save
        respond_with 200 do
          json volume.options
        end
      else
        results = {status: "failed to reset options"}
        respond_with 500 do
          json results.to_json
        end
      end
    else
      results = {status: "volume not found"}
      respond_with 404 do
        json results.to_json
      end
    end
  end
end
