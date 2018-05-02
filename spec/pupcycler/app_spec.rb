# frozen_string_literal: true

require 'pupcycler'

describe Pupcycler::App do
  subject { described_class }

  let :fake_store do
    FakeStore.new
  end

  before do
    allow_any_instance_of(described_class).to receive(:store)
      .and_return(fake_store)
  end

  def app
    Pupcycler::App
  end

  it 'has a non-zero boot time' do
    expect(subject::BOOT_TIME).to_not be_nil
  end

  describe 'GET /__meta__' do
    before do
      get '/__meta__'
    end

    let(:body) { JSON.parse(last_response.body) }

    it 'is friendly' do
      expect(last_response).to be_ok
      expect(body).to include('message')
      expect(body.fetch('message')).to match(/hello/i)
    end

    it 'provides uptime' do
      expect(last_response).to be_ok
      expect(body).to include('uptime')
      expect(body.fetch('uptime')).to be > -1
    end

    it 'provides version' do
      expect(last_response).to be_ok
      expect(body).to include('version')
      expect(body.fetch('version')).to_not be_empty
    end
  end

  describe 'GET /heartbeats/{device_id}' do
    before do
      get '/heartbeats/fafafaf', nil,
          'HTTP_AUTHORIZATION' => 'token fafafaf'
    end

    it 'is ok' do
      expect(last_response.status).to eql(200)
      expect(fake_store.heartbeats).to include('fafafaf')
      expect(fake_store.heartbeats.fetch('fafafaf')).to eql(1)
    end
  end
end

class FakeStore
  def initialize
    @heartbeats = {}
  end

  attr_reader :heartbeats

  def save_heartbeat(device_id: '')
    heartbeats[device_id] = 1
  end
end
