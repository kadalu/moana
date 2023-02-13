class ServiceManagerException < Exception
end

abstract class ServiceManager
  abstract def start(svc_id : String, cmd : Array(String))
  abstract def stop(svc_id : String)
end
