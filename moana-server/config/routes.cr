Amber::Server.configure do
  pipeline :web do
    # Plug is the method to use connect a pipe (middleware)
    # A plug accepts an instance of HTTP::Handler
    # plug Amber::Pipe::PoweredByAmber.new
    # plug Amber::Pipe::ClientIp.new(["X-Forwarded-For"])
    plug Citrine::I18n::Handler.new
    plug Amber::Pipe::Error.new
    plug Amber::Pipe::Logger.new
    plug Amber::Pipe::Session.new
    plug Amber::Pipe::Flash.new
    plug Amber::Pipe::CSRF.new
  end

  pipeline :api do
    # plug Amber::Pipe::PoweredByAmber.new
    plug Amber::Pipe::Error.new
    plug Amber::Pipe::Logger.new
    plug Amber::Pipe::Session.new
    # plug Amber::Pipe::CORS.new
  end

  # All static content will run these transformations
  pipeline :static do
    # plug Amber::Pipe::PoweredByAmber.new
    plug Amber::Pipe::Error.new
    plug Amber::Pipe::Static.new("./public")
  end

  routes :web do
  end

  routes :api, "/api" do
    resources "/clusters", ClusterController, except: [:new, :edit]

    resources "/clusters/:cluster_id/nodes", NodeController, except: [:new, :edit]

    resources "/clusters/:cluster_id/volumes", VolumeController, except: [:new, :edit, :update]

    # Volume Options
    get "/clusters/:cluster_id/volumes/:id/options", OptionController, :index
    post "/clusters/:cluster_id/volumes/:id/options/set", OptionController, :setopt
    post "/clusters/:cluster_id/volumes/:id/options/reset", OptionController, :resetopt

    post "/clusters/:cluster_id/volumes/:id/:action", VolumeController, :action
    resources "/clusters/:cluster_id/tasks", TaskController, except: [:new, :edit, :create]

    resources "/tasks/:cluster_id/:node_id", TaskController, except: [:new, :edit, :create]

    get "/volfiles/:cluster_id/:name", VolfileController, :show_cluster_level
    get "/volfiles/:cluster_id/:name/:volume_id", VolfileController, :show_volume_and_brick_level
    get "/volfiles/:cluster_id/:name/:volume_id/:brick_id", VolfileController, :show_volume_and_brick_level
  end

  routes :static do
    # Each route is defined as follow
    # verb resource : String, controller : Symbol, action : Symbol
    get "/*", Amber::Controller::Static, :index
  end
end
