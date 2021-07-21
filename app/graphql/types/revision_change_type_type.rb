module Types
  class RevisionChangeTypeType < Types::BaseObject
    field :id, ID, "ID du champ.", null: false

    field :from, Types::ChampDescriptorType::TypeDeChampType, "Valeur d’origine.", null: false
    field :to, Types::ChampDescriptorType::TypeDeChampType, "Nouvelle valeur.", null: false
  end
end
