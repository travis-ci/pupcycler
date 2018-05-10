# frozen_string_literal: true

require 'simplecov'

require 'rack/test'
require 'rspec'
require 'webmock/rspec'

require 'fakeredis' unless ENV['INTEGRATION_SPECS'] == '1'

ENV['PUPCYCLER_LOG_LEVEL'] = 'fatal'
require 'pupcycler'

RSpec.configure do |c|
  c.include Rack::Test::Methods
end

WebMock.disable_net_connect!
