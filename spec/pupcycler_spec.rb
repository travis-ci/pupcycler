# frozen_string_literal: true

describe Pupcycler do
  %w[
    App
    Config
    PacketClient
    PacketDevice
    Store
    Upcycler
    Worker
  ].each do |sym|
    describe Pupcycler.const_get(sym) do
      it 'exists' do
        expect(described_class).to_not be_nil
      end
    end
  end
end
