# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'

require 'pupcycler'

module Pupcycler
  class PacketClient
    def initialize(auth_token: '', project_id: '')
      @auth_token = auth_token
      @project_id = project_id
    end

    attr_reader :auth_token, :project_id
    private :auth_token
    private :project_id

    def devices
      accum = []
      next_page = "/projects/#{project_id}/devices?page=1"

      loop do
        resp = conn.get(next_page)
        raise resp.body.fetch('errors', ['bork!']).first unless resp.success?
        accum += resp.body.fetch('devices').map do |h|
          Pupcycler::PacketDevice.from_api_hash(h)
        end
        meta_next = resp.body.fetch('meta', {}).fetch('next', nil)
        break if meta_next.nil?
        next_page = meta_next.fetch('href')
      end

      accum.uniq(&:id)
    end

    def device(device_id: '')
      resp = conn.get("/devices/#{device_id}")
      raise resp.body.fetch('errors', ['ugh!']).first unless resp.success?
      Pupcycler::PacketDevice.from_api_hash(resp.body)
    end

    def reboot(device_id: '')
      device_action(device_id, 'reboot')
    end

    private def device_action(device_id, action)
      device_id = device_id.to_s.strip
      action = action.to_s.strip
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
