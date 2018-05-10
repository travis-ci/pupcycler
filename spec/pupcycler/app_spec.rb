# frozen_string_literal: true

describe Pupcycler::App do
  subject { described_class }

  def app
    Pupcycler::App
  end

  let :store do
    Pupcycler::Store.new
  end

  let :nowish do
    Time.parse(Time.now.utc.iso8601(0))
  end

  let :body do
    JSON.parse(last_response.body)
  end

  before do
    Pupcycler.config.auth_tokens = %w[fafafaf]
    allow_any_instance_of(Pupcycler::Store).to receive(:now)
      .and_return(nowish)
  end

  it 'has a non-zero boot time' do
    expect(subject::BOOT_TIME).to_not be_nil
  end

  describe 'GET /__meta__' do
    before do
      get '/__meta__'
    end

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
    end

    it 'records heartbeat' do
      expect(store.fetch_heartbeat(device_id: 'fafafaf')).to eql(nowish)
    end

    it 'responds with the state' do
      expect(body.fetch('state')).to eql('up')
    end
  end

  describe 'POST /startups/{device_id}' do
    before do
      post '/startups/fafafaf', nil,
           'HTTP_AUTHORIZATION' => 'token fafafaf'
    end

    it 'creates' do
      expect(last_response.status).to eql(201)
    end

    it 'records startup' do
      expect(store.fetch_startup(device_id: 'fafafaf')).to eql(nowish)
    end

    it 'saves state as up' do
      expect(store.fetch_state(device_id: 'fafafaf')).to eql('up')
    end

    it 'responds with the state' do
      expect(body.fetch('state')).to eql('up')
    end
  end

  describe 'POST /shutdowns/{device_id}' do
    before do
      stub_request(
        :post,
        %r{api\.packet\.net/devices/fafafaf/actions\?type=reboot}
      ).to_return(status: 200)

      post '/shutdowns/fafafaf', nil,
           'HTTP_AUTHORIZATION' => 'token fafafaf'
    end

    it 'creates' do
      expect(last_response.status).to eql(201)
    end

    it 'saves shutdown' do
      expect(store.fetch_shutdown(device_id: 'fafafaf')).to eql(nowish)
    end

    it 'reboots' do
      expect(WebMock).to have_requested(
        :post,
        %r{api\.packet\.net/devices/fafafaf/actions\?type=reboot}
      )
    end

    it 'saves state as down' do
      expect(store.fetch_state(device_id: 'fafafaf')).to eql('down')
    end

    it 'responds with state' do
      expect(body.fetch('state')).to eql('down')
    end
  end

  describe 'GET /devices' do
    before do
      get '/devices', nil,
          'HTTP_AUTHORIZATION' => 'token fafafaf'
    end

    it 'is ok' do
      expect(last_response.status).to eql(200)
    end

    it 'responds with data' do
      expect(body.key?('data')).to be true
    end
  end
end
