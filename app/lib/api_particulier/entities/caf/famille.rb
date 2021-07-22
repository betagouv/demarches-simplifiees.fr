module APIParticulier
  module Entities
    module Caf
      class Famille < Struct.new(:allocataires, :enfants, :adresse, :quotient_familial, :annee, :mois)
        def initialize(attrs)
          super(
            attrs[:allocataires].map { |a| Personne.new(a) },
            attrs[:enfants].map { |a| Personne.new(a) },
            PosteAdresse.new(attrs[:adresse]),
            attrs[:quotientFamilial],
            attrs[:annee],
            attrs[:mois]
          )
        end
      end
    end
  end
end
