# frozen_string_literal: true

describe Pupcycler::Upcycler do
  subject { Pupcycler.upcycler }

  let :nowish do
    Time.parse(Time.now.utc.iso8601(0))
  end

  before do
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
            'updated_at' => (nowish - 3600).to_s,
            'hostname' => 'fafafaf-testing-1-buh',
            'id' => 'fafafaf-afafafa-fafafafafafaf-afafaf-afafafafaf',
            'state' => 'running',
            'tags' => %w[worker testing],
            'created_at' => (nowish - 7200).to_s
          },
          {
            'updated_at' => (nowish - 3600).to_s,
            'hostname' => 'fafafaf-testing-1-qhu',
            'id' => 'fafafaf-afafafa-fafafafafafaf-afafaf-afafafafaf',
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
        'updated_at' => (nowish - 3600).to_s,
        'hostname' => 'fafafaf-testing-1-buh',
        'id' => 'fafafaf-afafafa-fafafafafafaf-afafaf-afafafafaf',
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

  it 'can upcycle' do
    subject.upcycle!
  end

  context 'when device is unresponsive' do
    before do
      allow(subject).to receive(:unresponsive?).and_return(true)
    end

    it 'reboots the device' do
      expect(subject).to receive(:reboot)
        .with(device_id: 'fafafaf-afafafa-fafafafafafaf-afafaf-afafafafaf')
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
        .with(device_id: 'fafafaf-afafafa-fafafafafafaf-afafaf-afafafafaf')
      subject.upcycle!
    end
  end
end
