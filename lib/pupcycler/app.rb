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
    end

    get '/__meta__' do
      status :ok
      json message: 'hello, human',
           uptime: uptime,
           version: Pupcycler.version
    end

    get '/heartbeats/:device_id' do
      protect!
      param :device_id, String, required: true
      store.save_heartbeat(device_id: params.fetch('device_id'))
      status :ok
      json state: :up
    end

    private def uptime
      Time.now - BOOT_TIME
    end

    private def store
      @store ||= Pupcycler::Store.new
    end
  end
end
