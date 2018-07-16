# frozen_string_literal: true

describe Pupcycler::PacketClient do
  subject { Pupcycler.packet_client }

  let(:nowish) { Time.parse(Time.now.utc.iso8601(0)) }
  let :device_id do
    "fafafaf-afafafa-fafafafafafaf-#{rand(100_000..1_000_000)}-afafafafaf"
  end

  let :response_page_1 do
    {
      'devices' => [
        {
          'updated_at' => (nowish - 84_000).to_s,
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
      ],
      'meta' => {
        'next' => {
          'href' => '/projects/notset/devices?page=2'
        }
      }
    }
  end

  let :response_page_2 do
    {
      'devices' => [
        {
          'updated_at' => (nowish - 84_000).to_s,
          'hostname' => 'fafafaf-testing-3-buh',
          'id' => 'also-not' + device_id,
          'state' => 'running',
          'tags' => %w[worker notset pool-0],
          'created_at' => (nowish - 7200).to_s
        },
        {
          'updated_at' => (nowish - 3600).to_s,
          'hostname' => 'fafafaf-testing-8-zil',
          'id' => 'def-not-' + device_id,
          'state' => 'running',
          'tags' => %w[bloop testing],
          'created_at' => (nowish - 7200).to_s
        }
      ],
      'meta' => {
        'next' => nil
      }
    }
  end

  before do
    stub_request(
      :get,
      %r{api\.packet\.net/projects/[^/]+/devices\?page=1$}
    ).to_return(
      status: 200,
      headers: {
        'Content-Type' => 'application/json'
      },
      body: JSON.generate(response_page_1)
    )

    stub_request(
      :get,
      %r{api\.packet\.net/projects/[^/]+/devices\?page=2$}
    ).to_return(
      status: 200,
      headers: {
        'Content-Type' => 'application/json'
      },
      body: JSON.generate(response_page_2)
    )
  end

  context 'when fetching devices' do
    it 'fetches all of them' do
      expect(subject.devices.map(&:id).length).to eql(4)
    end
  end
end
