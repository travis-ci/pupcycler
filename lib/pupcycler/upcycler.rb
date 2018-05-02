# frozen_string_literal: true

require 'pupcycler'

module Pupcycler
  class Upcycler
    def initialize
      @staleness_threshold = Pupcycler.config.upcycler.staleness_threshold
    end

    attr_reader :staleness_threshold
    private :staleness_threshold

    def upcycle_stale_workers
      worker_devices.each do |dev|
        upcycle!(dev.id) if stale?(store.heartbeats.fetch(dev.id, nil))
      end
    end

    private def upcycle!(device_id)
      Pupcycler.logger.warn 'upcycling', device_id: device_id
      packet_client.reboot(device_id)
    end

    private def stale?(last_heartbeat)
      return false if last_heartbeat.nil?
      (now - last_heartbeat) > staleness_threshold
    end

    private def worker_devices
      packet_client.devices.select do |dev|
        dev.tags.include?('worker')
      end
    end

    private def now
      Time.now.utc
    end

    private def store
      @store ||= Pupcycler::Store.new
    end

    private def packet_client
      @packet_client ||= Pupcycler::PacketClient.new
    end
  end
end
