# frozen_string_literal: true

require 'time'

require 'pupcycler'

module Pupcycler
  class PacketDevice
    def self.from_api_hash(api_hash)
      new(
        created_at: Time.parse(api_hash.fetch('created_at')),
        hostname: api_hash.fetch('hostname'),
        id: api_hash.fetch('id'),
        state: api_hash.fetch('state'),
        tags: Array(api_hash.fetch('tags')),
        updated_at: Time.parse(api_hash.fetch('updated_at'))
      )
    end

    def initialize(id: '', hostname: '', state: '', tags: [],
                   created_at: nil, updated_at: nil)
      @created_at = created_at || Time.now.utc
      @hostname = hostname
      @id = id
      @state = state
      @tags = Array(tags)
      @updated_at = updated_at || Time.now.utc
    end

    attr_reader :created_at, :hostname, :id, :state, :tags, :updated_at
  end
end
