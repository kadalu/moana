class VolumeController < ApplicationController
  def create
    respond_with 201 do
      json "{\"ok\": true}"
    end
  end
end
