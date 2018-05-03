# frozen_string_literal: true

require 'simplecov'

require 'rack/test'
require 'rspec'

RSpec.configure do |c|
  c.include Rack::Test::Methods
end

require 'pupcycler'

module Support
  class FakeStore
    def initialize
      @heartbeats = {}
      @states = {}
    end

    attr_reader :heartbeats, :states

    def save_heartbeat(device_id: '')
      heartbeats[device_id] = 1
    end

    def fetch_state(device_id: '')
      states.fetch(device_id, 'up')
    end
  end
end
