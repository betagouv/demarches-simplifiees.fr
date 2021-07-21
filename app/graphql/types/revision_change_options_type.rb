module Types
  class RevisionChangeOptionsType < Types::BaseObject
    field :id, ID, "ID du champ.", null: false

    field :added_values, [String], null: false
    field :removed_values, [String], null: false

    def added_values
      object[:to].sort - object[:from].sort
    end

    def removed_values
      object[:from].sort - object[:to].sort
    end
  end
end
