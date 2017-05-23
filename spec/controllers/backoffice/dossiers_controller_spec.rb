require 'spec_helper'

describe Backoffice::DossiersController, type: :controller do
  before do
    @request.env['HTTP_REFERER'] = TPS::Application::URL
  end
  let(:procedure) { create :procedure }
  let(:procedure2) { create :procedure }

  let(:dossier) { create(:dossier, :with_entreprise, procedure: procedure, state: :initiated) }
  let(:dossier2) { create(:dossier, :with_entreprise, procedure: procedure2, state: :initiated) }
  let(:dossier_archived) { create(:dossier, :with_entreprise, archived: true) }

  let(:dossier_id) { dossier.id }
  let(:dossier2_id) { dossier2.id }
  let(:bad_dossier_id) { Dossier.count + 10 }

  let(:gestionnaire) { create(:gestionnaire, administrateurs: [create(:administrateur)]) }
  let!(:gestionnaire2) { create(:gestionnaire, administrateurs: [create(:administrateur)]) }

  before do
    create :assign_to, procedure: procedure, gestionnaire: gestionnaire
    create :assign_to, procedure: procedure2, gestionnaire: gestionnaire2

    procedure.dossiers << dossier
    procedure2.dossiers << dossier2
  end

  describe 'GET #index' do
    subject { get :index }

    before do
      sign_in gestionnaire
    end

    context 'when gestionnaire is assign to a procedure' do
      it { is_expected.to redirect_to backoffice_dossiers_procedure_path(id: procedure.id) }

      context 'when gestionnaire is assign to many proceudure' do
        before do
          create :assign_to, procedure: create(:procedure), gestionnaire: gestionnaire
          create :assign_to, procedure: create(:procedure), gestionnaire: gestionnaire
        end

        it { expect(gestionnaire.procedures.count).to eq 3 }

        context 'when gestionnaire procedure_filter is nil' do
          it { expect(gestionnaire.procedure_filter).to be_nil }
          it { is_expected.to redirect_to backoffice_dossiers_procedure_path(id: gestionnaire.procedures.order('libelle ASC').first.id) }
        end

        context 'when gestionnaire procedure_filter is not nil' do
          let(:procedure_filter_id) { gestionnaire.procedures.order('libelle ASC').last.id }

          before do
            gestionnaire.update_column :procedure_filter, procedure_filter_id
          end

          context 'when gestionnaire is assign_to the procedure filter id' do
            it { is_expected.to redirect_to backoffice_dossiers_procedure_path(id: procedure_filter_id) }
          end

          context 'when gestionnaire not any more assign_to the procedure filter id' do
            before do
              AssignTo.where(procedure: procedure_filter_id, gestionnaire: gestionnaire).delete_all
            end

            it { expect(gestionnaire.procedure_filter).to be_nil }
            it { expect(AssignTo.where(procedure: procedure_filter_id, gestionnaire: gestionnaire).count).to eq 0 }

            it { is_expected.to redirect_to backoffice_dossiers_procedure_path(id: gestionnaire.procedures.order('libelle ASC').first.id) }
          end
        end
      end
    end

    context 'when gestionnaire is not assign to a procedure' do
      before do
        AssignTo.where(procedure: procedure, gestionnaire: gestionnaire).delete_all
      end

      it { is_expected.to redirect_to root_path }
    end
  end

  describe 'GET #show' do
    subject { get :show, params: {id: dossier_id} }

    context 'gestionnaire is connected' do
      before do
        sign_in gestionnaire
      end

      it 'returns http success' do
        expect(subject).to have_http_status(200)
      end

      describe 'all notifications unread are changed' do
        it do
          expect(Notification).to receive(:where).with(dossier_id: dossier_id).and_return(Notification::ActiveRecord_Relation)
          expect(Notification::ActiveRecord_Relation).to receive(:update_all).with(already_read: true).and_return(true)

          subject
        end
      end

      context 'when dossier id does not exist' do
        let(:dossier_id) { bad_dossier_id }

        it { expect(subject).to redirect_to('/backoffice') }
      end

      describe 'he can invite somebody for avis' do
        render_views

        it { expect(subject.body).to include("Invitez une personne externe à consulter le dossier et à vous donner un avis sur celui ci.") }
      end

      context 'and is invited on a dossier' do
        let(:dossier_invited){ create(:dossier, procedure: create(:procedure)) }
        let!(:avis){ create(:avis, dossier: dossier_invited, gestionnaire: gestionnaire) }

        subject { get :show, params: { id: dossier_invited.id } }

        render_views

        it { expect(subject.status).to eq(200) }
        it { expect(subject.body).to include("Votre avis est sollicité sur le dossier") }
        it { expect(subject.body).to_not include("Invitez une personne externe à consulter le dossier et à vous donner un avis sur celui ci.") }
      end
    end

    context 'gestionnaire does not connected but dossier id is correct' do
      it { is_expected.to redirect_to('/users/sign_in') }
    end
  end

  describe 'GET #a_traiter' do
    context 'when gestionnaire is connected' do
      before do
        sign_in gestionnaire
      end

      it 'returns http success' do
        get :index, params: {liste: :a_traiter}
        expect(response).to have_http_status(302)
      end
    end
  end

  describe 'GET #termine' do
    context 'when gestionnaire is connected' do
      before do
        sign_in gestionnaire
      end

      it 'returns http success' do
        get :index, params: {liste: :termine}
        expect(response).to have_http_status(302)
      end
    end
  end

  describe 'GET #list_fake' do
    context 'when gestionnaire is connected' do
      before do
        sign_in gestionnaire
      end

      it 'returns http success' do
        get :index, params: {liste: :list_fake}
        expect(response).to redirect_to(backoffice_dossiers_procedure_path(id: gestionnaire.procedures.first.id))
      end
    end
  end


  describe 'POST #search' do
    describe 'by id' do
      context 'when I am logged as a gestionnaire' do
        before do
          sign_in gestionnaire
        end

        context 'when I own the dossier' do
          before :each do
            post :search, params: { q: dossier_id }
          end

          it 'returns http success' do
            expect(response).to have_http_status(200)
          end

          it 'returns the expected dossier' do
            expect(assigns(:dossiers).count).to eq(1)
            expect(assigns(:dossiers).first.id).to eq(dossier_id)
          end
        end

        context 'when I do not own the dossier' do
          before :each do
            post :search, params: { q: dossier2_id }
          end

          it 'returns http success' do
            expect(response).to have_http_status(200)
          end

          it 'returns nothing' do
            expect(assigns(:dossiers).count).to eq(0)
          end
        end
      end
    end
  end

  describe 'POST #receive' do
    before do
      dossier.initiated!
      sign_in gestionnaire
    end

    subject { post :receive, params: {dossier_id: dossier_id} }

    context 'when it post a receive instruction' do
      before do
        subject
        dossier.reload
      end

      it 'change state to received' do
        expect(dossier.state).to eq('received')
      end
    end

    it 'Notification email is send' do
      expect(NotificationMailer).to receive(:send_notification)
        .with(dossier, kind_of(Mails::ReceivedMail)).and_return(NotificationMailer)
      expect(NotificationMailer).to receive(:deliver_now!)

      subject
    end

    it { is_expected.to redirect_to backoffice_dossier_path(id: dossier.id) }
  end

  describe 'POST #refuse' do
    before do
      dossier.refused!
      sign_in gestionnaire
    end

    subject { post :refuse, params: {dossier_id: dossier_id} }

    it 'change state to refused' do
      subject

      dossier.reload
      expect(dossier.state).to eq('refused')
    end

    it 'Notification email is sent' do
      expect(NotificationMailer).to receive(:send_notification)
        .with(dossier, kind_of(Mails::RefusedMail)).and_return(NotificationMailer)
      expect(NotificationMailer).to receive(:deliver_now!)

      subject
    end

    it { is_expected.to redirect_to backoffice_dossier_path(id: dossier.id) }
  end

  describe 'POST #without_continuation' do
    before do
      dossier.without_continuation!
      sign_in gestionnaire
    end
    subject { post :without_continuation, params: {dossier_id: dossier_id} }


    it 'change state to without_continuation' do
      subject

      dossier.reload
      expect(dossier.state).to eq('without_continuation')
    end

    it 'Notification email is sent' do
      expect(NotificationMailer).to receive(:send_notification)
        .with(dossier, kind_of(Mails::WithoutContinuationMail)).and_return(NotificationMailer)
      expect(NotificationMailer).to receive(:deliver_now!)

      subject
    end

    it { is_expected.to redirect_to backoffice_dossier_path(id: dossier.id) }
  end

  describe 'POST #close' do
    before do
      dossier.received!
      sign_in gestionnaire
    end
    subject { post :close, params: {dossier_id: dossier_id} }

    it 'change state to closed' do
      subject

      dossier.reload
      expect(dossier.state).to eq('closed')
    end

    it 'Notification email is sent' do
      expect(NotificationMailer).to receive(:send_notification)
        .with(dossier, kind_of(Mails::ClosedMail)).and_return(NotificationMailer)
      expect(NotificationMailer).to receive(:deliver_now!)

      subject
    end

    it { is_expected.to redirect_to backoffice_dossier_path(id: dossier.id) }
  end

  describe 'PUT #toggle_follow' do
    before do
      sign_in gestionnaire
    end

    subject { put :follow, params: {dossier_id: dossier_id} }

    it { expect(subject.status).to eq 302 }

    context 'when dossier is at state initiated' do
      let(:dossier) { create(:dossier, :with_entreprise, procedure: procedure, state: 'initiated') }

      before do
        subject
        dossier.reload
      end

      it 'change state for updated' do
        expect(dossier.state).to eq 'updated'
      end

    end

    describe 'flash alert' do
      context 'when dossier is not follow by gestionnaire' do
        before do
          subject
        end
        it { expect(flash[:notice]).to have_content 'Dossier suivi' }
      end

      context 'when dossier is follow by gestionnaire' do
        before do
          create :follow, gestionnaire_id: gestionnaire.id, dossier_id: dossier.id
          subject
        end
        it { expect(flash[:notice]).to have_content 'Dossier relaché' }
      end
    end
  end

  describe 'POST #reopen' do
    before do
      dossier.received!
      sign_in gestionnaire
    end

    subject { post :reopen, params: {dossier_id: dossier_id} }

    it 'change state to replied' do
      subject

      dossier.reload
      expect(dossier.state).to eq('replied')
    end

    it { is_expected.to redirect_to backoffice_dossiers_path }
  end

  describe 'POST #archive' do
    before do
      dossier.update(archived: false)
      sign_in gestionnaire
    end

    subject { post :archive, params: {id: dossier_id} }

    it 'change state to archived' do
      subject

      dossier.reload
      expect(dossier.archived).to eq(true)
    end

    it { is_expected.to redirect_to backoffice_dossiers_path }
  end
end
