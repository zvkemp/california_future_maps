require 'sinatra'
require './data'

get '/' do
  "Hello, World"
end

get '/data' do
  params.inspect
end
