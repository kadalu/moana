require "./helpers"
require "../server/*"

struct MgrArgs
  property metrics_interval_seconds = 15,
    workdir = "/var/lib/kadalu",
    logdir = ""
end

class Args
  property mgr_args = MgrArgs.new
end

command "mgr", "Start Kadalu Storage Manager" do |parser, args|
  parser.banner = "Usage: kadalu mgr"
  parser.on("--workdir=WORKDIR", "Kadalu Workdir") do |workdir|
    args.mgr_args.workdir = workdir
  end
  parser.on("--logdir=LOGDIR", "Kadalu Log directory") do |logdir|
    args.mgr_args.logdir = logdir
  end
end

handler "mgr" do |args|
  StorageMgr.start(args)
end
