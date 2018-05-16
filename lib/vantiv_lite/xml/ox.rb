# frozen-string-literal: true

require 'ox'
require 'vantiv_lite/xml'

module VantivLite
  module XML
    module Ox
      class Parser
        include XML::Parser

        private

        def root(xml)
          ::Ox.load(xml, symbolize_keys: false)
        end

        def value_with!(node)
          node.text ? node.text : node.attributes.merge(hash_with(*node.nodes))
        end
      end

      class Serializer
        include XML::Serializer

        def call(hash)
          ::Ox.dump(add_xml_elements!(::Ox::Document.new(version: '1.0'), hash))
        end

        private

        def attributes_or_elements!(parent, key, value)
          return parent[key] = text_with(value) if attributes.include?(key)
          e = ::Ox::Element.new(key)
          parent << e
          add_xml_elements!(e, value)
        end

        def insert_text!(node, text)
          node << text_with(text)
        end
      end
    end
  end
end
