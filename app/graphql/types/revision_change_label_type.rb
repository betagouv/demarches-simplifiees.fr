module Types
  class RevisionChangeLabelType < Types::BaseObject
    field :id, ID, "ID du champ.", null: false

    field :from, String, "Valeur d’origine.", null: false
    field :to, String, "Nouvelle valeur.", null: false
  end
end
