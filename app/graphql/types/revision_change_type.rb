module Types
  class RevisionChangeType < Types::BaseUnion
    possible_types Types::RevisionChangeAddChampType,
      Types::RevisionChangeRemoveChampType,
      Types::RevisionChangePositionType,
      Types::RevisionChangeTypeType,
      Types::RevisionChangeLabelType,
      Types::RevisionChangeDescriptionType,
      Types::RevisionChangeRequiredType,
      Types::RevisionChangeOptionsType

    def self.resolve_type(object, context)
      case object[:op]
      when :add
        Types::RevisionChangeAddChampType
      when :remove
        Types::RevisionChangeRemoveChampType
      when :move
        Types::RevisionChangePositionType
      else
        case object[:attribute]
        when :type_champ
          Types::RevisionChangeTypeType
        when :libelle
          Types::RevisionChangeLabelType
        when :description
          Types::RevisionChangeDescriptionType
        when :mandatory
          Types::RevisionChangeRequiredType
        when :drop_down_options
          Types::RevisionChangeOptionsType
        end
      end
    end
  end
end
