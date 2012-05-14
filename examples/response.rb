#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '../lib/'))

require 'ostruct'
require 'state-handler'

class ResponseHandler
  include StateHandler::Mixing

  code 200 => :success
  code 404 => :not_found
  code 401 => :unauthorized

  match /5\d\d/ => :error
end

response = OpenStruct.new(:code => 500)
ResponseHandler.new(response) do |r|
  r.at :not_found, :unauthorized do
    puts 'Another response handled'
  end

  r.success { puts 'Request executed' }
  r.error { puts 'Request failed' }
end
