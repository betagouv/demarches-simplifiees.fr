require 'spec_helper'

describe NewGestionnaire::DossiersController, type: :controller do
  let(:gestionnaire) { create(:gestionnaire) }
  let(:procedure) { create(:procedure, :published, gestionnaires: [gestionnaire]) }
  let(:dossier) { create(:dossier, :replied, procedure: procedure) }

  before { sign_in(gestionnaire) }

  describe '#attestation' do
    context 'when a dossier has an attestation' do
      let(:fake_pdf) { double(read: 'pdf content') }
      let!(:dossier) { create(:dossier, :replied, attestation: Attestation.new, procedure: procedure) }
      let!(:procedure) { create(:procedure, :published, gestionnaires: [gestionnaire]) }
      let!(:dossier) { create(:dossier, :replied, attestation: Attestation.new, procedure: procedure) }

      it 'returns the attestation pdf' do
        allow_any_instance_of(Attestation).to receive(:pdf).and_return(fake_pdf)

        expect(controller).to receive(:send_data)
          .with('pdf content', filename: 'attestation.pdf', type: 'application/pdf') do
            controller.render nothing: true
          end

        get :attestation, params: { procedure_id: procedure.id, dossier_id: dossier.id }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe '#follow' do
    before do
      expect_any_instance_of(Dossier).to receive(:next_step!).with('gestionnaire', 'follow')
      patch :follow, params: { procedure_id: procedure.id, dossier_id: dossier.id }
    end

    it { expect(gestionnaire.followed_dossiers).to match([dossier]) }
    it { expect(flash.notice).to eq('Dossier suivi') }
    it { expect(response).to redirect_to(procedures_url) }
  end

  describe '#unfollow' do
    before do
      gestionnaire.followed_dossiers << dossier
      patch :unfollow, params: { procedure_id: procedure.id, dossier_id: dossier.id }
      gestionnaire.reload
    end

    it { expect(gestionnaire.followed_dossiers).to match([]) }
    it { expect(flash.notice).to eq("Vous ne suivez plus le dossier nº #{dossier.id}") }
    it { expect(response).to redirect_to(procedures_url) }
  end

  describe '#archive' do
    before do
      patch :archive, params: { procedure_id: procedure.id, dossier_id: dossier.id }
      dossier.reload
    end

    it { expect(dossier.archived).to be true }
    it { expect(response).to redirect_to(procedures_url) }
  end

  describe '#unarchive' do
    before do
      dossier.update_attributes(archived: true)
      patch :unarchive, params: { procedure_id: procedure.id, dossier_id: dossier.id }
      dossier.reload
    end

    it { expect(dossier.archived).to be false }
    it { expect(response).to redirect_to(procedures_url) }
  end

  describe "#show" do
    before { get :show, params: { procedure_id: procedure.id, dossier_id: dossier.id } }

    it { expect(response).to have_http_status(:success) }
  end

  describe "#create_commentaire" do
    let(:saved_commentaire) { dossier.commentaires.first }

    before do
      post :create_commentaire, params: {
        procedure_id: procedure.id,
        dossier_id: dossier.id,
        commentaire: { body: 'body' }
      }
    end

    it { expect(saved_commentaire.body).to eq('body') }
    it { expect(saved_commentaire.email).to eq(gestionnaire.email) }
    it { expect(saved_commentaire.dossier).to eq(dossier) }
    it { expect(response).to redirect_to(messagerie_dossier_path(dossier.procedure, dossier)) }
  end

  describe "#create_avis" do
    let(:saved_avis) { dossier.avis.first }

    before do
      post :create_avis, params: {
        procedure_id: procedure.id,
        dossier_id: dossier.id,
        avis: { email: 'email@a.com', introduction: 'intro' }
      }
    end

    it { expect(saved_avis.email).to eq('email@a.com') }
    it { expect(saved_avis.introduction).to eq('intro') }
    it { expect(saved_avis.dossier).to eq(dossier) }
    it { expect(saved_avis.claimant).to eq(gestionnaire) }
    it { expect(response).to redirect_to(instruction_dossier_path(dossier.procedure, dossier)) }
  end

  describe "#update_annotations" do
    let(:champ_multiple_drop_down_list) do
      type_de_champ = TypeDeChamp.create(type_champ: 'multiple_drop_down_list', libelle: 'libelle')
      ChampPrivate.create(type_de_champ: type_de_champ)
    end

    let(:champ_datetime) do
      type_de_champ = TypeDeChamp.create(type_champ: 'datetime', libelle: 'libelle')
      ChampPrivate.create(type_de_champ: type_de_champ)
    end

    let(:dossier) do
      create(:dossier, :replied, procedure: procedure, champs_private: [champ_multiple_drop_down_list, champ_datetime])
    end

    before do
      patch :update_annotations, params: {
        procedure_id: procedure.id,
        dossier_id: dossier.id,
        dossier: {
          champs_private_attributes: {
            '0': {
              id: champ_multiple_drop_down_list.id,
              value: ['', 'un', 'deux']
            },
            '1': {
              id: champ_datetime.id,
              'value(1i)': 2019,
              'value(2i)': 12,
              'value(3i)': 21,
              'value(4i)': 13,
              'value(5i)': 17
            }
          }
        }
      }

      champ_multiple_drop_down_list.reload
      champ_datetime.reload
    end

    it { expect(champ_multiple_drop_down_list.value).to eq('["un", "deux"]') }
    it { expect(champ_datetime.value).to eq('21/12/2019 13:17') }
    it { expect(response).to redirect_to(instruction_dossier_path(dossier.procedure, dossier)) }
  end
end
