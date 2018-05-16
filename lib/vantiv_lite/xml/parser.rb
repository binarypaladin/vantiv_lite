# frozen-string-literal: true

module VantivLite
  module XML
    module Parser
      def call(xml)
        hash_with(root(xml))
      end

      private

      def hash_with(*nodes)
        nodes.each_with_object({}) do |n, h|
          inject_or_merge!(h, n.name, value_with!(n))
        end
      end

      def inject_or_merge!(hash, key, value)
        if hash.key?(key)
          cv = hash[key]
          value = cv.is_a?(Array) ? cv.push(value) : [cv, value]
        end
        hash[key] = value
      end
    end
  end
end
