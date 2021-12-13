# frozen-string-literal: true

require 'vantiv_lite/xml'
require 'vantiv_lite'

module VantivLite
  ServerError = Class.new(StandardError)
  class Response
    module Refinements
      [Array, Hash].each do |klass|
        next if klass.public_instance_methods.include?(:dig)

        refine klass do
          def dig(key, *next_keys)
            Dig.(self, key, *next_keys)
          end
        end
      end
    end

    using Refinements

    Dig = lambda do |obj, key, *next_keys|
      begin
        next_obj = obj[key]
        next_obj.nil? || next_keys.empty? ? next_obj : next_obj.dig(*next_keys)
      rescue NoMethodError
        raise TypeError, "#{next_obj.class.name} does not have #dig method"
      end
    end

    include Enumerable

    attr_reader :to_h, :error, :root_key
    alias to_hash to_h

    def initialize(http_response, *dig_keys, request, parser:)
      @error = nil
      @root_key = request.is_a?(Request) ? 'litleOnlineResponse' : 'cnpOnlineResponse'
      http_ok?(http_response)
      @to_h = response_hash_with(parser.(http_response.body), dig_keys)
    end

    def [](key)
      @to_h[key]
    end

    def dig(key, *next_keys)
      Dig.(@to_h, key, *next_keys)
    end

    def each(*args, &blk)
      @to_h.each(*args, &blk)
    end

    def success?
      @error.nil?
    end

    def error_message
      @error
    end

    private

    def http_ok?(http_response)
      return true unless http_response.code != '200'

      @error = "server responded with #{http_response.code} instead of 200"
      raise ServerError, @error
    end

    def response_hash_with(response_hash, dig_keys)
      raise ServerError, "missing root :#{root_key}" unless (root_hash = response_hash[root_key])

      if root_hash['response'] != '0'
        @error = root_hash['message']
        raise ServerError, @error
      end

      dig_keys.any? ? root_hash.dig(*dig_keys) : root_hash
    end
  end
end
