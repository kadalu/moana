require "../../plugins/helpers"
require "./helpers"

SYSTEMCTL     = "systemctl"
UNIT_FILE_DIR = "/lib/systemd/system/"

def unit_file_content(svc_id, cmd)
  %Q[[Unit]
Description=#{svc_id}
After=network.target

[Service]
PIDFile=/run/kadalu/#{svc_id}.pid
ExecStart=#{cmd}

[Install]
WantedBy=multi-user.target
]
end

class SystemdServiceManager < ServiceManager
  def initialize
  end

  def create(svc_id, cmd)
    svc_file = "#{UNIT_FILE_DIR}/kadalu-#{svc_id}.service"
    return if File.exists?(svc_file)

    File.write(
      svc_file,
      unit_file_content(svc_id, cmd.join(" "))
    )
    rc, _out, err = execute(SYSTEMCTL, ["daemon-reload"])
    if rc != 0
      Log.warn &.emit("Systemd daemon-reload failed", svc_id: svc_id, err: err)
    end
  end

  def delete(svc_id)
    svc_file = "#{UNIT_FILE_DIR}/kadalu-#{svc_id}.service"
    File.delete(svc_file) if File.exists?(svc_file)
  end

  def start(svc_id, cmd)
    svc_id = svc_id.gsub("%2F", "-")
    create(svc_id, cmd)
    rc, _out, err = execute(SYSTEMCTL, ["start", "kadalu-#{svc_id}.service"])
    raise ServiceManagerException.new(err) unless rc == 0
  end

  def stop(svc_id)
    svc_id = svc_id.gsub("%2F", "-")
    rc, _out, err = execute(SYSTEMCTL, ["stop", "kadalu-#{svc_id}.service"])
    raise ServiceManagerException.new(err) unless rc == 0
    delete(svc_id)
  end

  def is_running?(svc_id)
    svc_id = svc_id.gsub("%2F", "-")
    rc, _out, _err = execute(SYSTEMCTL, ["is-active", "--quiet", "kadalu-#{svc_id}.service"])
    rc == 0
  end
end
