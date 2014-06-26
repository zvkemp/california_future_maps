require 'sinatra/activerecord'

set :database, { adapter: "sqlite3", database: "cdf_data.sqlite3" }
