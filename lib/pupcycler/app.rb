# frozen_string_literal: true

require 'pupcycler'

require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/param'

module Pupcycler
  class App < Sinatra::Base
    helpers Sinatra::Param

    BOOT_TIME = Time.now

    helpers do
      def protect!
        return if authorized?
        headers['WWW-Authenticate'] = 'Basic realm="Pupcycler"'
        content_type :json
        halt 401, '{"no":"not you"}'
      end

      def authorized?
        @auth ||= request.env.fetch('HTTP_AUTHORIZATION', 'notset')
        @auth.start_with?('token ') &&
          Pupcycler.config.auth_tokens.include?(@auth.sub(/^token /, ''))
      end

      private def device_id
        params.fetch('device_id')
      end
    end

    get '/__meta__' do
      status :ok
      json message: 'hello, human',
           uptime: uptime,
           version: Pupcycler.version
    end

    get '/heartbeats/:device_id' do
      protect!

      store.save_heartbeat(device_id: device_id)
      state = store.fetch_state(device_id: device_id)
      status :ok
      json state: state
    end

    post '/startups/:device_id' do
      protect!

      store.save_startup(device_id: device_id)
      store.save_state(device_id: device_id, state: 'up')
      state = store.fetch_state(device_id: device_id)
      status :created
      json state: state
    end

    post '/shutdowns/:device_id' do
      protect!

      store.save_shutdown(device_id: device_id)

      upcycler.reboot(device_id: device_id) unless rebooting_disabled?

      store.save_state(device_id: device_id, state: 'down')
      state = store.fetch_state(device_id: device_id)
      status :created
      json state: state
    end

    get '/devices' do
      protect!
      status :ok
      json data: store.fetch_devices
    end

    private def uptime
      Time.now - BOOT_TIME
    end

    private def store
      @store ||= Pupcycler::Store.new
    end

    private def upcycler
      @upcycler ||= Pupcycler::Upcycler.new
    end

    private def rebooting_disabled?
      Pupcycler.config.upcycler_rebooting_disabled?
    end
  end
end
