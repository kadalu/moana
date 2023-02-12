require "./helpers"
require "../server/*"

struct MgrArgs
  property metrics_interval_seconds = 15,
    workdir = "/var/lib/kadalu",
    logdir = "",
    hostname = "",
    service_mgr = ""
end

class Args
  property mgr_args = MgrArgs.new
end

command "mgr", "Start the kadalu storage manager" do |parser, args|
  parser.banner = "Usage: kadalu mgr"
  parser.on("--workdir=WORKDIR", "Set kadalu workdir") do |workdir|
    args.mgr_args.workdir = workdir
  end
  parser.on("--logdir=LOGDIR", "Set kadalu log directory") do |logdir|
    args.mgr_args.logdir = logdir
  end
  parser.on("--hostname=HOSTNAME", "Set hostname") do |hostname|
    args.mgr_args.hostname = hostname
  end
  parser.on("--service-mgr=SVC_MANAGER", "Service manager (systemd,supervisord,..). Default is None") do |svc_mgr|
    args.mgr_args.service_mgr = svc_mgr
  end
end

handler "mgr" do |args|
  StorageMgr.start(args)
end
