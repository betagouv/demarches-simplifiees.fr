module Types
  class RevisionChangePositionType < Types::BaseObject
    field :id, ID, "ID du champ.", null: false

    field :from, Int, "Valeur d’origine.", null: false
    field :to, Int, "Nouvelle valeur.", null: false
  end
end
