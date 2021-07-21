module Types
  class RevisionChangeRequiredType < Types::BaseObject
    field :id, ID, "ID du champ.", null: false

    field :from, Boolean, "Valeur d’origine.", null: false
    field :to, Boolean, "Nouvelle valeur.", null: false
  end
end
