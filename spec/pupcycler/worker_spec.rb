# frozen_string_literal: true

describe Pupcycler::Worker do
  let :fake_upcycler do
    double('fake upcycler', upcycle!: nil)
  end

  let :fake_lock_manager do
    flm = double('fake lock manager')
    allow(flm).to receive(:lock!) do |*_, &b|
      b.call
    end
    flm
  end

  before do
    Pupcycler.logger.level = Logger::FATAL
    Pupcycler.config.worker_run_once = true
    allow_any_instance_of(described_class).to receive(:upcycler)
      .and_return(fake_upcycler)
    allow_any_instance_of(described_class).to receive(:lock_manager)
      .and_return(fake_lock_manager)
  end

  it 'runs' do
    described_class.run
  end

  it 'upcycles stale workers' do
    expect(fake_upcycler).to receive(:upcycle!)
    described_class.run
  end

  it 'rescues StandardError and descendants within each run tick' do
    allow(fake_upcycler).to receive(:upcycle!).and_raise(KaboomsError)
    expect { described_class.run }.not_to raise_error
  end

  it 'rescues redis locking errors within each run tick' do
    allow(fake_lock_manager).to receive(:lock!).and_raise(Redlock::LockError)
    expect { described_class.run }.not_to raise_error
  end
end

KaboomsError = Class.new(StandardError)
