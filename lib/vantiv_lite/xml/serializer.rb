# frozen-string-literal: true

module VantivLite
  module XML
    module Serializer
      ATTRIBUTES = %w[customerId id merchantId reportGroup version xmlns].freeze

      @@type_coercions = {}
      def self.coerce(type, obj = nil, &blk)
        raise TypeError, '`type` must be a `Class`' unless type.is_a?(Class)

        obj ||= blk
        raise TypeError, '`obj` must respond to `call`' unless obj.respond_to?(:call)

        @@type_coercions[type] = obj
      end

      attr_reader :attributes

      def initialize(attributes: ATTRIBUTES)
        @attributes = attributes
      end

      private

      def add_xml_elements!(parent, obj)
        case obj
        when Hash
          obj.each { |k, v| attributes_or_elements!(parent, k, v) }
        when Array
          obj.each { |v| add_xml_elements!(parent, v) }
        else
          insert_text!(parent, obj)
        end
        parent
      end

      def text_with(obj)
        (callable = @@type_coercions[obj.class]) ? callable.call(obj) : obj.to_s
      end
    end
  end
end
