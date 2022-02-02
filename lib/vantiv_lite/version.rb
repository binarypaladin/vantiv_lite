# frozen-string-literal: true

module VantivLite
  MAJOR = 0
  MINOR = 2
  TINY  = 6
  VERSION = [MAJOR, MINOR, TINY].join('.').freeze

  def self.version
    VERSION
  end
end
