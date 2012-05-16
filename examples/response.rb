#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '../lib/'))

require 'ostruct'
require 'state-handler'

class ResponseHandler
  include StateHandler::Mixing

  group :success do
    code 200 => :success
    code 302 => :already_added
  end

  group :pass do
    code 404 => :not_found
    code 401 => :unauthorized
  end

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
