# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'

require 'pupcycler'

module Pupcycler
  class PacketClient
    def initialize
      @auth_token = Pupcycler.config.packet_auth_token
      @project_id = Pupcycler.config.packet_project_id
    end

    attr_reader :auth_token, :project_id
    private :auth_token
    private :project_id

    def devices
      resp = conn.get("/projects/#{project_id}/devices")
      raise resp.body.fetch('errors', ['bork!']).first unless resp.success?
      resp.body.fetch('devices').map do |h|
        Pupcycler::PacketDevice.from_api_hash(h)
      end
    end

    def reboot(device_id)
      device_action(device_id, 'reboot')
    end

    private def device_action(device_id, action)
      device_id.strip!
      action.strip!
      raise 'missing device id' if device_id.empty?
      raise 'missing action type' if action.empty?

      resp = conn.post do |req|
        req.url "/devices/#{device_id}/actions", 'type' => action
      end

      raise resp.body.fetch('errors', ['bork!']).first unless resp.success?
      resp.body
    end

    private def conn
      @conn ||= Faraday.new(url: 'https://api.packet.net') do |c|
        c.headers = {
          'Accept' => 'application/json',
          'X-Auth-Token' => auth_token
        }
        c.response :json, content_type: /\bjson$/
        c.adapter :net_http
      end
    end
  end
end
