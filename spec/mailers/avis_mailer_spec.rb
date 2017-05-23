require "rails_helper"

RSpec.describe AvisMailer, type: :mailer do
  describe '.you_are_invited_on_dossier' do
    let(:avis) { create(:avis) }

    subject { described_class.you_are_invited_on_dossier(avis) }

    it { expect(subject.subject).to eq("Donnez votre avis sur le dossier nº #{avis.dossier.id} (#{avis.dossier.procedure.libelle})") }
    it { expect(subject.body).to include("Vous avez été invité à donner votre avis sur le dossier nº #{avis.dossier.id} de la procédure : #{avis.dossier.procedure.libelle}.") }
    it { expect(subject.body).to include(avis.introduction) }
  end
end
