module APIParticulier
  module Entities
    module Caf
      class Personne < Struct.new(:noms_et_prenoms, :date_de_naissance, :sexe)
        def initialize(attrs)
          super(
            attrs[:nomPrenom],
            Date.strptime(attrs[:dateDeNaissance], "%d%m%Y"),
            Personne.parse_sexe(attrs[:sexe])
          )
        end

        def self.parse_sexe(s)
          case s
          when 'F'
            'féminin'
          when 'M'
            'masculin'
          else
            raise 'unsupported sex yet'
          end
        end
      end
    end
  end
end
