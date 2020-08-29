require "granite/adapter/sqlite"

Granite::Connections << Granite::Adapter::Sqlite.new(name: "sqlite", url: ENV["DATABASE_URL"]? || Amber.settings.database_url)
