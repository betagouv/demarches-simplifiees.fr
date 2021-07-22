module APIParticulier
  module Entities
    module Caf
      class PosteAdresse < Struct.new(:identite, :complement_d_identite, :complement_d_identite_geo, :numero_et_rue, :lieu_dit, :code_postal_et_ville, :pays)
        def initialize(attrs)
          super(
            attrs[:identite],
            attrs[:complementIdentite],
            attrs[:complementIdentiteGeo],
            attrs[:numeroRue],
            attrs[:lieuDit],
            attrs[:codePostalVille],
            attrs[:pays]
          )
        end
      end
    end
  end
end
