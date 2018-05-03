# frozen_string_literal: true

require 'pupcycler'

module Pupcycler
  class Upcycler
    def initialize
      @thresholds = Pupcycler.config.upcycler_thresholds
      @unresponsiveness_threshold = @thresholds[:unresponsive]
      @staleness_threshold = @thresholds[:stale]
    end

    attr_reader :unresponsiveness_threshold, :staleness_threshold
    private :unresponsiveness_threshold
    private :staleness_threshold

    def upcycle!
      worker_devices.each do |dev|
        if unresponsive?(store.fetch_heartbeat(device_id: dev.id))
          reboot(device_id: dev.id)
        end

        if stale?(store.fetch_startup(device_id: dev.id))
          graceful_shutdown(device_id: dev.id)
        end
      end
    end

    def reboot(device_id: '')
      Pupcycler.logger.warn 'rebooting', device_id: device_id
      packet_client.reboot(device_id: device_id)
      store.save_reboot(device_id: device_id)
    end

    def graceful_shutdown(device_id: '')
      Pupcycler.logger.info 'gracefully shutting down', device_id: device_id
      store.save_state(device_id: device_id, state: 'down')
    end

    private def unresponsive?(last_heartbeat)
      return false if last_heartbeat.nil?
      (now - last_heartbeat) > unresponsiveness_threshold
    end

    private def stale?(startup)
      return false if startup.nil?
      (now - startup) > staleness_threshold
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
