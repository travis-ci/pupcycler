# frozen_string_literal: true

describe Pupcycler::Upcycler do
  subject { Pupcycler.upcycler }
  let(:nowish) { Time.parse(Time.now.utc.iso8601(0)) }
  let(:device_id) { 'fafafaf-afafafa-fafafafafafaf-afafaf-afafafafaf' }
  let(:store) { subject.send(:store) }
  let(:packet_client) { subject.send(:packet_client) }
  let(:last_heartbeat) { nowish - 300 }
  let(:last_startup) { nowish - 14_400 }
  let(:worker_updated_at) { nowish - 14_400 }

  before do
    allow(store).to receive(:now).and_return(nowish)
    allow(store).to receive(:fetch_heartbeat)
      .with(device_id: device_id).and_return(last_heartbeat)
    allow(store).to receive(:fetch_startup)
      .with(device_id: device_id).and_return(last_startup)

    stub_request(
      :get,
      %r{api\.packet\.net/projects/[^/]+/devices$}
    ).to_return(
      status: 200,
      headers: {
        'Content-Type' => 'application/json'
      },
      body: JSON.generate(
        'devices' => [
          {
            'updated_at' => worker_updated_at.to_s,
            'hostname' => 'fafafaf-testing-1-buh',
            'id' => device_id,
            'state' => 'running',
            'tags' => %w[worker testing],
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
      )
    )
    stub_request(
      :get,
      %r{api\.packet\.net/devices/fafafaf-[-af]+-afafafafaf$}
    ).to_return(
      status: 200,
      headers: {
        'Content-Type' => 'application/json'
      },
      body: JSON.generate(
        'updated_at' => worker_updated_at.to_s,
        'hostname' => 'fafafaf-testing-1-buh',
        'id' => device_id,
        'state' => 'running',
        'tags' => %w[worker testing],
        'created_at' => (nowish - 7200).to_s
      )
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
end
