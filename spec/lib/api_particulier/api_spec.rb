describe APIParticulier::API do
  let(:token) { "d7e9c9f4c3ca00caadde31f50fd4521a" }
  let(:api) { APIParticulier::API }

  before do
    Rails.application.secrets.api_entreprise[:token] = token
  end

  describe "introspect" do
    subject { api.introspect }

    it "doit retourner une introspection valide" do
      VCR.use_cassette("api_particulier/success/introspect") do
        expect(subject.id).to be_nil
        expect(subject.name).to eql("Application de sandbox")
        expect(subject.email).to be_nil
        expect(subject.scopes).to be_instance_of(Array)
        expect(subject.scopes).to match_array(['dgfip_avis_imposition', 'dgfip_adresse', 'cnaf_allocataires', 'cnaf_enfants', 'cnaf_adresse', 'cnaf_quotient_familial', 'mesri_statut_etudiant'])
      end
    end
  end

  describe "composition familiale" do
    subject { api.composition_familiale(numero_d_allocataire, code_postal) }

    context "avec un numéro d'allocataire et un code postal valides" do
      let(:numero_d_allocataire) { "0000354" }
      let(:code_postal) { "99148" }

      it "doit retourner une famille valide" do
        VCR.use_cassette("api_particulier/success/composition_familiale") do
          expect(subject.allocataires.count).to equal(2)

          allocataire = subject.allocataires.first
          expect(allocataire.noms_et_prenoms).to eql("MARIE DUPONT")
          expect(allocataire.date_de_naissance).to eql(Date.new(1971, 11, 12))
          expect(allocataire.sexe).to eql("féminin")

          expect(subject.enfants.count).to equal(1)

          enfant = subject.enfants.first
          expect(enfant.noms_et_prenoms).to eql("LUCIE DUPONT")
          expect(enfant.date_de_naissance).to eql(Date.new(2016, 12, 11))
          expect(enfant.sexe).to eql("féminin")

          expect(subject.adresse.identite).to eql("Madame MARIE DUPONT")
          expect(subject.adresse.complement_d_identite).to be_nil
          expect(subject.adresse.numero_et_rue).to eql("123 RUE BIDON")
          expect(subject.adresse.lieu_dit).to be_nil
          expect(subject.adresse.code_postal_et_ville).to eql("12345 CONDAT")
          expect(subject.adresse.pays).to eql("FRANCE")

          expect(subject.quotient_familial).to equal(1754)
          expect(subject.annee).to equal(2020)
          expect(subject.mois).to equal(12)
        end
      end
    end

    context "avec un numéro d'allocataire inconnu" do
       let(:numero_d_allocataire) { "0000000" }
       let(:code_postal) { "99148" }

       it "doit retourner une erreur" do
         VCR.use_cassette("api_particulier/not_found/composition_familiale") do
           expect { subject }.to raise_error(APIParticulier::Error::NotFound)
         end
       end
     end
  end
end
