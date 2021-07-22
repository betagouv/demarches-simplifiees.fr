module APIParticulier
  module Entities
    class Introspection < Struct.new(:id, :name, :email, :scopes)
      def initialize(attrs)
        super(attrs[:id], attrs[:name], attrs[:email], attrs[:scopes])
      end
    end
  end
end
