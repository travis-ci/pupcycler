# frozen_string_literal: true

describe Pupcycler::Store do
  subject { Pupcycler.store }

  it 'knows how to now' do
    expect(subject.send(:now)).to_not be_nil
  end

  describe 'cleaning up' do
    let :device_hashes do
      [
        {
          boop: '2018-07-15 03:32:01 UTC',
          heartbeat: nil,
          hostname: 'fancy-1-worker-org-07-packet',
          reboot: nil,
          shutdown: nil,
          startup: nil,
          state: nil,
          id: 'ffffffff-aaaa-ffff-aaaa-fffffffffff0'
        },
        {
          boop: '2018-07-15 03:32:01 UTC',
          heartbeat: nil,
          hostname: 'fancy-1-worker-org-17-packet',
          reboot: nil,
          shutdown: nil,
          startup: nil,
          state: nil,
          id: 'ffffffff-aaaa-ffff-aaaa-fffffffffff1'
        },
        {
          boop: '2018-07-15 03:32:01 UTC',
          heartbeat: nil,
          hostname: 'fancy-1-worker-org-06-packet',
          reboot: nil,
          shutdown: nil,
          startup: nil,
          state: nil,
          id: 'ffffffff-aaaa-ffff-aaaa-fffffffffff2'
        }
      ]
    end

    before do
      allow(subject).to receive(:fetch_devices)
        .and_return(device_hashes)
    end

    it 'wipes device records' do
      expect(subject).to receive(:wipe_device)
        .exactly(device_hashes.length).times
      subject.cleanup!
    end
  end
end
