# frozen_string_literal: true

describe Pupcycler::Upcycler do
  subject { Pupcycler.upcycler }
  let(:nowish) { Time.parse(Time.now.utc.iso8601(0)) }
  let(:store) { subject.send(:store) }
  let(:packet_client) { subject.send(:packet_client) }
  let(:last_heartbeat) { nowish - 300 }
  let(:last_startup) { nowish - 14_400 }
  let(:worker_updated_at) { nowish - 14_400 }

  let :device_id do
    "fafafaf-afafafa-fafafafafafaf-#{rand(100_000..1_000_000)}-afafafafaf"
  end

  let :api_response_hash do
    {
      'devices' => [
        {
          'updated_at' => worker_updated_at.to_s,
          'hostname' => 'fafafaf-testing-1-buh',
          'id' => device_id,
          'state' => 'running',
          'tags' => %w[worker notset pool-0],
          'created_at' => (nowish - 7200).to_s
        },
        {
          'updated_at' => (nowish - 3600).to_s,
          'hostname' => 'fafafaf-testing-1-qhu',
          'id' => 'not-' + device_id,
          'state' => 'running',
          'tags' => %w[bloop testing],
          'created_at' => (nowish - 7200).to_s
        }
      ]
    }
  end

  let :device do
    Pupcycler::PacketDevice.from_api_hash(
      api_response_hash.fetch('devices').first
    )
  end

  before do
    Pupcycler.redis_pool.with do |redis|
      keys = redis.scan_each(match: 'device:*').to_a.uniq
      redis.multi do |conn|
        keys.each { |k| conn.del(k) }
      end
    end

    allow(store).to receive(:now).and_return(nowish)
    allow(store).to receive(:fetch_heartbeat)
      .with(device_id: device_id).and_return(last_heartbeat)
    allow(store).to receive(:fetch_startup)
      .with(device_id: device_id).and_return(last_startup)

    stub_request(
      :get,
      %r{api\.packet\.net/projects/[^/]+/devices(\?page=.+|)$}
    ).to_return(
      status: 200,
      headers: {
        'Content-Type' => 'application/json'
      },
      body: JSON.generate(api_response_hash)
    )
    stub_request(
      :get,
      %r{api\.packet\.net/devices/fafafaf-.+-afafafafaf$}
    ).to_return(
      status: 200,
      headers: {
        'Content-Type' => 'application/json'
      },
      body: JSON.generate(api_response_hash.fetch('devices').first)
    )
    stub_request(
      :post,
      %r{api\.packet\.net/devices/[^/]+/actions\?type=reboot$}
    ).to_return(status: 200)
  end

  describe 'upcycling' do
    it 'can upcycle' do
      subject.upcycle!
    end

    context 'when device is deleted' do
      before do
        allow(subject).to receive(:deleted?).and_return(true)
      end

      it 'wipes record of the device' do
        expect(store).to receive(:wipe_device).with(device_id: device_id)
        subject.upcycle!
      end

      it 'does not check for staleness' do
        expect(subject).to_not receive(:stale?)
        subject.upcycle!
      end
    end

    context 'when device is unresponsive' do
      before do
        allow(subject).to receive(:unresponsive?).and_return(true)
      end

      it 'reboots the device' do
        expect(subject).to receive(:reboot).with(device_id: device_id)
        subject.upcycle!
      end

      it 'does not check for staleness' do
        expect(subject).to_not receive(:stale?)
        subject.upcycle!
      end
    end

    context 'when device is stale' do
      before do
        allow(subject).to receive(:stale?).and_return(true)
      end

      it 'gracefully shuts down the device' do
        expect(subject).to receive(:graceful_shutdown)
          .with(device_id: device_id)
        subject.upcycle!
      end
    end

    context 'when store contains devices unknown to packet' do
      before do
        allow(subject).to receive(:packet_known_worker_devices).and_return([])
        allow(store).to receive(:fetch_devices).and_return(
          [
            {
              boop: '2018-07-15 03:32:01 UTC',
              heartbeat: nil,
              hostname: 'fancy-1-worker-org-07-packet',
              reboot: nil,
              shutdown: nil,
              startup: nil,
              state: nil,
              id: device_id
            }
          ]
        )
      end

      it 'upcycles' do
        expect(subject).to receive(:upcycle_device!)
          .with(device_id: device_id, hostname: 'fancy-1-worker-org-07-packet')
        subject.upcycle!
      end
    end
  end

  describe 'rebooting' do
    it 'reboots via Packet API' do
      expect(packet_client).to receive(:reboot).with(device_id: device_id)
      subject.reboot(device_id: device_id)
    end

    it 'stores a reboot timestamp' do
      subject.reboot(device_id: device_id)
      expect(store.fetch_reboot(device_id: device_id)).to eql(nowish)
    end

    context 'when the device has not cooled down' do
      let(:worker_updated_at) { nowish - 300 }

      it 'refuses to reboot' do
        expect { subject.reboot(device_id: device_id) }
          .to raise_error(StandardError)
      end
    end
  end

  describe 'gracefully shutting down' do
    it 'changes the device state to "down"' do
      expect do
        subject.graceful_shutdown(device_id: device_id)
      end.to change {
        store.fetch_state(device_id: device_id)
      }.from('up').to('down')
    end
  end

  describe 'deletion detection' do
    context 'when device exists' do
      before do
        allow(packet_client).to receive(:device)
          .with(device_id: device_id).and_return(device)
      end

      it 'reports false' do
        expect(subject.send(:deleted?, device_id, nowish - 7200)).to be false
      end
    end

    context 'when device does not exist' do
      before do
        allow(packet_client).to receive(:device)
          .with(device_id: device_id).and_raise(StandardError.new('ugh!'))
      end

      context 'when device is unresponsive' do
        before do
          allow(subject).to receive(:unresponsive?).and_return(true)
        end

        it 'reports true' do
          expect(subject.send(:deleted?, device_id, nowish - 7200)).to be true
        end
      end

      context 'when device is still responsive' do
        before do
          allow(subject).to receive(:unresponsive?).and_return(false)
        end
      end
    end
  end
end
