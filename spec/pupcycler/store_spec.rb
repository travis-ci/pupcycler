# frozen_string_literal: true

describe Pupcycler::Store do
  it 'knows how to now' do
    expect(subject.send(:now)).to_not be_nil
  end
end
