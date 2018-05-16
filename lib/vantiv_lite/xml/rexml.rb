# frozen-string-literal: true

require 'rexml/document'
require 'vantiv_lite/xml'

module VantivLite
  module XML
    module REXML
      class Parser
        include XML::Parser

        private

        def attribute_hash(element)
          element.attributes.each_with_object({}) { |(k, v), h| h[k] = v.to_s }
        end

        def root(xml)
          ::REXML::Document.new(xml).root
        end

        def value_with!(element)
          children = element.elements.to_a
          return element.text if element.attributes.empty? && children.empty?
          attribute_hash(element).merge(hash_with(*children))
        end
      end

      class Serializer
        include XML::Serializer

        def call(hash)
          # NOTE: This forces attributes to be delimited with double quotes. Despite the fact that
          # the Litle API returns single-quoted responses, requests with single-quoted attributes
          # will yield an internal server error.
          ::REXML::Document.new(nil, attribute_quote: :quote).tap do |d|
            d.add(::REXML::XMLDecl.new)
            add_xml_elements!(d, hash)
          end.to_s
        end

        private

        def attributes_or_elements!(parent, key, value)
          return parent.add_attribute(key, text_with(value)) if attributes.include?(key)
          add_xml_elements!(::REXML::Element.new(key, parent, parent.context), value)
        end

        def insert_text!(element, text)
          element.add_text(text_with(text))
        end
      end
    end
  end
end
