if ENV['COVERAGE']
  SimpleCov.start do
    add_filter '/spec/'
  end

  if ENV['INTEGRATION_SPECS'] == '1' && ENV['TRAVIS']
    require 'codecov'
    SimpleCov.formatter = SimpleCov::Formatter::Codecov
  end
end
