describe Procedure do
  describe 'mail templates' do
    subject { create(:procedure) }

    it { expect(subject.initiated_mail_template).to be_a(Mails::InitiatedMail) }
    it { expect(subject.received_mail_template).to be_a(Mails::ReceivedMail) }
    it { expect(subject.closed_mail_template).to be_a(Mails::ClosedMail) }
    it { expect(subject.refused_mail_template).to be_a(Mails::RefusedMail) }
    it { expect(subject.without_continuation_mail_template).to be_a(Mails::WithoutContinuationMail) }
  end

  describe 'initiated_mail' do
    let(:procedure) { create(:procedure) }

    subject { procedure }

    context 'when initiated_mail is not customize' do
      it { expect(subject.initiated_mail_template.body).to eq(Mails::InitiatedMail.default_for_procedure(procedure).body) }
    end

    context 'when initiated_mail is customize' do
      before :each do
        subject.initiated_mail = Mails::InitiatedMail.new(body: 'sisi')
        subject.save
        subject.reload
      end
      it { expect(subject.initiated_mail_template.body).to eq('sisi') }
    end

    context 'when initiated_mail is customize ... again' do
      before :each do
        subject.initiated_mail = Mails::InitiatedMail.new(body: 'toto')
        subject.save
        subject.reload
      end
      it { expect(subject.initiated_mail_template.body).to eq('toto') }

      it { expect(Mails::InitiatedMail.count).to eq(1) }
    end
  end

  describe 'closed mail template body' do
    let(:procedure) { create(:procedure) }

    subject { procedure.closed_mail_template.rich_body.body.to_html }

    context 'for procedures without an attestation' do
      it { is_expected.not_to include('lien attestation') }
    end

    context 'for procedures with an attestation' do
      before { create(:attestation_template, procedure: procedure, activated: activated) }

      context 'when the attestation is inactive' do
        let(:activated) { false }

        it { is_expected.not_to include('lien attestation') }
      end

      context 'when the attestation is inactive' do
        let(:activated) { true }

        it { is_expected.to include('lien attestation') }
      end
    end
  end

  describe '#closed_mail_template_attestation_inconsistency_state' do
    let(:procedure_without_attestation) { create(:procedure, closed_mail: closed_mail) }
    let(:procedure_with_active_attestation) do
      procedure = create(:procedure, closed_mail: closed_mail)
      create(:attestation_template, procedure: procedure, activated: true)
      procedure
    end
    let(:procedure_with_inactive_attestation) do
      procedure = create(:procedure, closed_mail: closed_mail)
      create(:attestation_template, procedure: procedure, activated: false)
      procedure
    end

    subject { procedure.closed_mail_template_attestation_inconsistency_state }

    context 'with a custom mail template' do
      context 'that contains a lien attestation tag' do
        let(:closed_mail) { build(:closed_mail, body: '--lien attestation--') }

        context 'when the procedure doesn’t have an attestation' do
          let(:procedure) { procedure_without_attestation }

          it { is_expected.to eq(:extraneous_tag) }
        end

        context 'when the procedure has an active attestation' do
          let(:procedure) { procedure_with_active_attestation }

          it { is_expected.to be(nil) }
        end

        context 'when the procedure has an inactive attestation' do
          let(:procedure) { procedure_with_inactive_attestation }

          it { is_expected.to eq(:extraneous_tag) }
        end
      end

      context 'that doesn’t contain a lien attestation tag' do
        let(:closed_mail) { build(:closed_mail) }

        context 'when the procedure doesn’t have an attestation' do
          let(:procedure) { procedure_without_attestation }

          it { is_expected.to be(nil) }
        end

        context 'when the procedure has an active attestation' do
          let(:procedure) { procedure_with_active_attestation }

          it { is_expected.to eq(:missing_tag) }
        end

        context 'when the procedure has an inactive attestation' do
          let(:procedure) { procedure_with_inactive_attestation }

          it { is_expected.to be(nil) }
        end
      end
    end

    context 'with the default mail template' do
      let(:closed_mail) { nil }

      context 'when the procedure doesn’t have an attestation' do
        let(:procedure) { procedure_without_attestation }

        it { is_expected.to be(nil) }
      end

      context 'when the procedure has an active attestation' do
        let(:procedure) { procedure_with_active_attestation }

        it { is_expected.to be(nil) }
      end

      context 'when the procedure has an inactive attestation' do
        let(:procedure) { procedure_with_inactive_attestation }

        it { is_expected.to be(nil) }
      end
    end
  end

  describe 'scopes' do
    let!(:procedure) { create(:procedure) }
    let!(:discarded_procedure) { create(:procedure, :discarded) }

    describe 'default_scope' do
      subject { Procedure.all }
      it { is_expected.to match_array([procedure]) }
    end
  end

  describe 'validation' do
    context 'libelle' do
      it { is_expected.not_to allow_value(nil).for(:libelle) }
      it { is_expected.not_to allow_value('').for(:libelle) }
      it { is_expected.to allow_value('Demande de subvention').for(:libelle) }
    end

    context 'description' do
      it { is_expected.not_to allow_value(nil).for(:description) }
      it { is_expected.not_to allow_value('').for(:description) }
      it { is_expected.to allow_value('Description Demande de subvention').for(:description) }
    end

    context 'organisation' do
      it { is_expected.to allow_value('URRSAF').for(:organisation) }
    end

    context 'administrateurs' do
      it { is_expected.not_to allow_value([]).for(:administrateurs) }
    end

    context 'juridique' do
      it { is_expected.not_to allow_value(nil).for(:cadre_juridique) }
      it { is_expected.to allow_value('text').for(:cadre_juridique) }

      context 'with deliberation' do
        let(:procedure) { build(:procedure, cadre_juridique: nil) }

        it { expect(procedure.valid?).to eq(false) }

        context 'when the deliberation is uploaded ' do
          before do
            procedure.deliberation = fixture_file_upload('spec/fixtures/files/file.pdf', 'application/pdf')
          end

          it { expect(procedure.valid?).to eq(true) }
        end

        context 'when the deliberation is uploaded with an unauthorized format' do
          before do
            procedure.deliberation = fixture_file_upload('spec/fixtures/files/french-flag.gif', 'image/gif')
          end

          it { expect(procedure.valid?).to eq(false) }
        end
      end

      context 'when juridique_required is false' do
        let(:procedure) { build(:procedure, juridique_required: false, cadre_juridique: nil) }

        it { expect(procedure.valid?).to eq(true) }
      end
    end

    context 'api_entreprise_token' do
      let(:valid_token) { "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c" }
      let(:invalid_token) { 'plouf' }
      it { is_expected.to allow_value(valid_token).for(:api_entreprise_token) }
      it { is_expected.not_to allow_value(invalid_token).for(:api_entreprise_token) }
    end

    context 'api_particulier_token' do
      let(:valid_token) { "3841b13fa8032ed3c31d160d3437a76a" }
      let(:invalid_token) { 'jet0n 1nvalide' }
      it { is_expected.to allow_value(valid_token).for(:api_particulier_token) }
      it { is_expected.not_to allow_value(invalid_token).for(:api_particulier_token) }
    end

    context 'monavis' do
      context 'nil is allowed' do
        it { is_expected.to allow_value(nil).for(:monavis_embed) }
        it { is_expected.to allow_value('').for(:monavis_embed) }
      end

      context 'random string is not allowed' do
        let(:procedure) { build(:procedure, monavis_embed: "plop") }
        it { expect(procedure.valid?).to eq(false) }
      end

      context 'random html is not allowed' do
        let(:procedure) { build(:procedure, monavis_embed: '<img src="http://some.analytics/hello.gif">') }
        it { expect(procedure.valid?).to eq(false) }
      end

      context 'Monavis embed code with white button is allowed' do
        monavis_blanc = <<-MSG
        <a href="https://monavis.numerique.gouv.fr/Demarches/123?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=cd4a872d475e4045666057f">
          <img src="https://monavis.numerique.gouv.fr/monavis-static/bouton-blanc.png" alt="Je donne mon avis" title="Je donne mon avis sur cette démarche" />
        </a>
        MSG
        let(:procedure) { build(:procedure, monavis_embed: monavis_blanc) }
        it { expect(procedure.valid?).to eq(true) }
      end

      context 'Monavis embed code with blue button is allowed' do
        monavis_bleu = <<-MSG
        <a href="https://monavis.numerique.gouv.fr/Demarches/123?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=cd4a872d475e4045666057f">
          <img src="https://monavis.numerique.gouv.fr/monavis-static/bouton-bleu.png" alt="Je donne mon avis" title="Je donne mon avis sur cette démarche" />
        </a>
        MSG
        let(:procedure) { build(:procedure, monavis_embed: monavis_bleu) }
        it { expect(procedure.valid?).to eq(true) }
      end
    end

    shared_examples 'duree de conservation' do
      context 'duree_conservation_required it true, the field gets validated' do
        it { is_expected.not_to allow_value(nil).for(field_name) }
        it { is_expected.not_to allow_value('').for(field_name) }
        it { is_expected.not_to allow_value('trois').for(field_name) }
        it { is_expected.to allow_value(3).for(field_name) }
      end
    end

    describe 'duree de conservation dans ds' do
      let(:field_name) { :duree_conservation_dossiers_dans_ds }

      it_behaves_like 'duree de conservation'
    end
  end

  describe 'active' do
    let(:procedure) { create(:procedure) }
    subject { Procedure.active(procedure.id) }

    context 'when procedure is in draft status and not closed' do
      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'when procedure is published and not closed' do
      let(:procedure) { create(:procedure, :published) }
      it { is_expected.to be_truthy }
    end

    context 'when procedure is published and closed' do
      let(:procedure) { create(:procedure, :closed) }
      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end

  describe 'api_entreprise_token_expired?' do
    let(:token) { "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c" }
    let(:procedure) { create(:procedure, api_entreprise_token: token) }
    let(:payload) {
      [
        { "exp" => expiration_time }
      ]
    }
    let(:subject) { procedure.api_entreprise_token_expired? }

    before do
      allow(JWT).to receive(:decode).with(token, nil, false).and_return(payload)
    end

    context "with token expired" do
      let(:expiration_time) { (Time.zone.now - 1.day).to_i }
      it { is_expected.to be_truthy }
    end

    context "with token not expired" do
      let(:expiration_time) { (Time.zone.now + 1.day).to_i }
      it { is_expected.to be_falsey }
    end
  end

  describe 'clone' do
    let(:service) { create(:service) }
    let(:procedure) { create(:procedure, received_mail: received_mail, service: service, types_de_champ: [type_de_champ_0, type_de_champ_1, type_de_champ_2, type_de_champ_pj, type_de_champ_repetition], types_de_champ_private: [type_de_champ_private_0, type_de_champ_private_1, type_de_champ_private_2, type_de_champ_private_repetition]) }
    let(:type_de_champ_0) { build(:type_de_champ, position: 0) }
    let(:type_de_champ_1) { build(:type_de_champ, position: 1) }
    let(:type_de_champ_2) { build(:type_de_champ_drop_down_list, position: 2) }
    let(:type_de_champ_pj) { build(:type_de_champ_piece_justificative, position: 3, old_pj: { stable_id: 2713 }) }
    let(:type_de_champ_repetition) { build(:type_de_champ_repetition, position: 4, types_de_champ: [build(:type_de_champ)]) }
    let(:type_de_champ_private_0) { build(:type_de_champ, :private, position: 0) }
    let(:type_de_champ_private_1) { build(:type_de_champ, :private, position: 1) }
    let(:type_de_champ_private_2) { build(:type_de_champ_drop_down_list, :private, position: 2) }
    let(:type_de_champ_private_repetition) { build(:type_de_champ_repetition, :private, position: 3, types_de_champ: [build(:type_de_champ, :private)]) }
    let(:received_mail) { build(:received_mail) }
    let(:from_library) { false }
    let(:administrateur) { procedure.administrateurs.first }

    let(:groupe_instructeur_1) { create(:groupe_instructeur, procedure: procedure, label: "groupe_1") }
    let(:instructeur_1) { create(:instructeur) }
    let(:instructeur_2) { create(:instructeur) }
    let!(:assign_to_1) { create(:assign_to, procedure: procedure, groupe_instructeur: groupe_instructeur_1, instructeur: instructeur_1) }
    let!(:assign_to_2) { create(:assign_to, procedure: procedure, groupe_instructeur: groupe_instructeur_1, instructeur: instructeur_2) }

    before do
      @logo = Rack::Test::UploadedFile.new('spec/fixtures/files/white.png', 'image/png')
      @signature = Rack::Test::UploadedFile.new('spec/fixtures/files/black.png', 'image/png')
      @attestation_template = create(:attestation_template, procedure: procedure, logo: @logo, signature: @signature)
      @procedure = procedure.clone(administrateur, from_library)
      @procedure.save
    end

    subject { @procedure }

    it { expect(subject.parent_procedure).to eq(procedure) }

    describe "should keep groupe instructeurs " do
      it "should clone groupe instructeurs" do
        expect(subject.groupe_instructeurs.size).to eq(2)
        expect(subject.groupe_instructeurs.size).to eq(procedure.groupe_instructeurs.size)
        expect(subject.groupe_instructeurs.where(label: "groupe_1").first).not_to be nil
      end

      it "should clone instructeurs in the groupe" do
        expect(subject.groupe_instructeurs.where(label: "groupe_1").first.instructeurs.map(&:email)).to eq(procedure.groupe_instructeurs.where(label: "groupe_1").first.instructeurs.map(&:email))
      end
    end

    it 'should duplicate specific objects with different id' do
      expect(subject.id).not_to eq(procedure.id)

      expect(subject.draft_types_de_champ.size).to eq(procedure.draft_types_de_champ.size)
      expect(subject.draft_types_de_champ_private.size).to eq(procedure.draft_types_de_champ_private.size)

      procedure.draft_types_de_champ.zip(subject.draft_types_de_champ).each do |ptc, stc|
        expect(stc).to have_same_attributes_as(ptc, except: ["revision_id"])
        expect(stc.revision).to eq(subject.draft_revision)
      end

      TypeDeChamp.where(parent: procedure.draft_types_de_champ.repetition).zip(TypeDeChamp.where(parent: subject.draft_types_de_champ.repetition)).each do |ptc, stc|
        expect(stc).to have_same_attributes_as(ptc, except: ["revision_id", "parent_id"])
        expect(stc.revision).to eq(subject.draft_revision)
      end

      procedure.draft_types_de_champ_private.zip(subject.draft_types_de_champ_private).each do |ptc, stc|
        expect(stc).to have_same_attributes_as(ptc, except: ["revision_id"])
        expect(stc.revision).to eq(subject.draft_revision)
      end

      TypeDeChamp.where(parent: procedure.draft_types_de_champ_private.repetition).zip(TypeDeChamp.where(parent: subject.draft_types_de_champ_private.repetition)).each do |ptc, stc|
        expect(stc).to have_same_attributes_as(ptc, except: ["revision_id", "parent_id"])
        expect(stc.revision).to eq(subject.draft_revision)
      end

      expect(subject.attestation_template.title).to eq(procedure.attestation_template.title)

      expect(subject.cloned_from_library).to be(false)

      cloned_procedure = subject
      cloned_procedure.parent_procedure_id = nil
      expect(cloned_procedure).to have_same_attributes_as(procedure, except: ["path", "draft_revision_id"])
    end

    context 'when the procedure is cloned from the library' do
      let(:from_library) { true }

      it 'should set cloned_from_library to true' do
        expect(subject.cloned_from_library).to be(true)
      end

      it 'should set service_id to nil' do
        expect(subject.service).to eq(nil)
      end

      it 'should discard old pj information' do
        subject.draft_types_de_champ.each do |stc|
          expect(stc.old_pj).to be_nil
        end
      end

      it 'should have one administrateur' do
        expect(subject.administrateurs).to eq([administrateur])
      end

      it 'should set ask_birthday to false' do
        expect(subject.ask_birthday?).to eq(false)
      end
    end

    context 'when the procedure is cloned from the library' do
      let(:procedure) { create(:procedure, received_mail: received_mail, service: service, ask_birthday: true) }

      it 'should set ask_birthday to false' do
        expect(subject.ask_birthday?).to eq(false)
      end
    end

    it 'should keep service_id' do
      expect(subject.service).to eq(service)
    end

    context 'when the procedure is cloned to another administrateur' do
      let(:administrateur) { create(:administrateur) }

      it 'should clone service' do
        expect(subject.service.id).not_to eq(service.id)
        expect(subject.service.administrateur_id).not_to eq(service.administrateur_id)
        expect(subject.service.attributes.except("id", "administrateur_id", "created_at", "updated_at")).to eq(service.attributes.except("id", "administrateur_id", "created_at", "updated_at"))
      end

      it 'should discard old pj information' do
        subject.draft_types_de_champ.each do |stc|
          expect(stc.old_pj).to be_nil
        end
      end

      it 'should discard specific api_entreprise_token' do
        expect(subject.read_attribute(:api_entreprise_token)).to be_nil
      end

      it 'should have one administrateur' do
        expect(subject.administrateurs).to eq([administrateur])
      end

      it "should discard the existing groupe instructeurs" do
        expect(subject.groupe_instructeurs.size).not_to eq(procedure.groupe_instructeurs.size)
        expect(subject.groupe_instructeurs.where(label: "groupe_1").first).to be nil
      end

      it 'should have a default groupe instructeur' do
        expect(subject.groupe_instructeurs.size).to eq(1)
        expect(subject.groupe_instructeurs.first.label).to eq(GroupeInstructeur::DEFAUT_LABEL)
        expect(subject.groupe_instructeurs.first.instructeurs.size).to eq(0)
      end
    end

    it 'should duplicate existing mail_templates' do
      expect(subject.received_mail.attributes.except("id", "procedure_id", "created_at", "updated_at")).to eq procedure.received_mail.attributes.except("id", "procedure_id", "created_at", "updated_at")
      expect(subject.received_mail.id).not_to eq procedure.received_mail.id
      expect(subject.received_mail.id).not_to be nil
      expect(subject.received_mail.procedure_id).not_to eq procedure.received_mail.procedure_id
      expect(subject.received_mail.procedure_id).not_to be nil
    end

    it 'should not duplicate default mail_template' do
      expect(subject.initiated_mail_template.attributes).to eq Mails::InitiatedMail.default_for_procedure(subject).attributes
    end

    it 'should not duplicate specific related objects' do
      expect(subject.dossiers).to eq([])
    end

    describe 'should not duplicate lien_notice' do
      let(:procedure) { create(:procedure, lien_notice: "http://toto.com") }

      it { expect(subject.lien_notice).to be_nil }
    end

    describe 'procedure status is reset' do
      let(:procedure) { create(:procedure, :closed, received_mail: received_mail, service: service) }

      it 'Not published nor closed' do
        expect(subject.closed_at).to be_nil
        expect(subject.published_at).to be_nil
        expect(subject.unpublished_at).to be_nil
        expect(subject.aasm_state).to eq "brouillon"
        expect(subject.path).not_to be_nil
      end
    end

    it 'should keep types_de_champ ids stable' do
      expect(subject.draft_types_de_champ.first.id).not_to eq(procedure.draft_types_de_champ.first.id)
      expect(subject.draft_types_de_champ.first.stable_id).to eq(procedure.draft_types_de_champ.first.id)
    end

    it 'should duplicate piece_justificative_template on a type_de_champ' do
      expect(subject.draft_types_de_champ.where(type_champ: "piece_justificative").first.piece_justificative_template.attached?).to be true
    end

    context 'with a notice attached' do
      let(:procedure) { create(:procedure, :with_notice, received_mail: received_mail, service: service) }

      it 'should duplicate notice' do
        expect(subject.notice.attached?).to be true
      end
    end

    context 'with a deliberation attached' do
      let(:procedure) { create(:procedure, :with_deliberation, received_mail: received_mail, service: service) }

      it 'should duplicate deliberation' do
        expect(subject.deliberation.attached?).to be true
      end
    end

    context 'with canonical procedure' do
      let(:canonical_procedure) { create(:procedure) }
      let(:procedure) { create(:procedure, canonical_procedure: canonical_procedure, received_mail: received_mail, service: service) }

      it 'do not clone canonical procedure' do
        expect(subject.canonical_procedure).to be_nil
      end
    end
  end

  describe '#publish!' do
    let(:procedure) { create(:procedure, path: 'example-path') }
    let(:now) { Time.zone.now.beginning_of_minute }

    context 'when publishing a new procedure' do
      before do
        Timecop.freeze(now) do
          procedure.publish!
        end
      end

      it 'no reference to the canonical procedure on the published procedure' do
        expect(procedure.canonical_procedure).to be_nil
      end

      it 'changes the procedure state to published' do
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
        expect(Procedure.find_by(path: "example-path")).to eq(procedure)
        expect(Procedure.find_by(path: "example-path").administrateurs).to eq(procedure.administrateurs)
      end

      it 'creates a new draft revision' do
        expect(procedure.published_revision).not_to be_nil
        expect(procedure.draft_revision).not_to be_nil
        expect(procedure.revisions.count).to eq(2)
        expect(procedure.revisions).to eq([procedure.published_revision, procedure.draft_revision])
      end
    end

    context 'when publishing over a previous canonical procedure' do
      let(:canonical_procedure) { create(:procedure, :published) }

      before do
        Timecop.freeze(now) do
          procedure.publish!(canonical_procedure)
        end
      end

      it 'references the canonical procedure on the published procedure' do
        expect(procedure.canonical_procedure).to eq(canonical_procedure)
      end

      it 'changes the procedure state to published' do
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
      end
    end
  end

  describe "#publish_or_reopen!" do
    let(:canonical_procedure) { create(:procedure, :published) }
    let(:administrateur) { canonical_procedure.administrateurs.first }

    let(:procedure) { create(:procedure, administrateurs: [administrateur]) }
    let(:now) { Time.zone.now.beginning_of_minute }

    context 'when publishing over a previous canonical procedure' do
      before do
        procedure.path = canonical_procedure.path
        Timecop.freeze(now) do
          procedure.publish_or_reopen!(administrateur)
        end
        procedure.reload
        canonical_procedure.reload
      end

      it 'references the canonical procedure on the published procedure' do
        expect(procedure.canonical_procedure).to eq(canonical_procedure)
      end

      it 'changes the procedure state to published' do
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
      end

      it 'unpublishes the canonical procedure' do
        expect(canonical_procedure.unpublished_at).to eq(now)
      end

      it 'creates a new draft revision' do
        expect(procedure.published_revision).not_to be_nil
        expect(procedure.draft_revision).not_to be_nil
        expect(procedure.revisions.count).to eq(2)
        expect(procedure.revisions).to eq([procedure.published_revision, procedure.draft_revision])
        expect(procedure.published_revision.published_at).to eq(now)
      end
    end

    context 'when publishing over a previous procedure with canonical procedure' do
      let(:canonical_procedure) { create(:procedure, :closed) }
      let(:parent_procedure) { create(:procedure, :published, administrateurs: [administrateur]) }

      before do
        parent_procedure.update!(path: canonical_procedure.path, canonical_procedure: canonical_procedure)
        procedure.path = canonical_procedure.path
        Timecop.freeze(now) do
          procedure.publish_or_reopen!(administrateur)
        end
        parent_procedure.reload
      end

      it 'references the canonical procedure on the published procedure' do
        expect(procedure.canonical_procedure).to eq(canonical_procedure)
      end

      it 'changes the procedure state to published' do
        expect(procedure.canonical_procedure).to eq(canonical_procedure)
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
        expect(procedure.published_revision.published_at).to eq(now)
      end

      it 'unpublishes parent procedure' do
        expect(parent_procedure.unpublished_at).to eq(now)
      end
    end

    context 'when republishing a previously closed procedure' do
      let(:procedure) { create(:procedure, :published, administrateurs: [administrateur]) }

      before do
        procedure.close!
        Timecop.freeze(now) do
          procedure.publish_or_reopen!(administrateur)
        end
      end

      it 'changes the procedure state to published' do
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
        expect(procedure.published_revision.published_at).not_to eq(now)
      end

      it "doesn't create a new revision" do
        expect(procedure.published_revision).not_to be_nil
        expect(procedure.draft_revision).not_to be_nil
        expect(procedure.revisions.count).to eq(2)
        expect(procedure.revisions).to eq([procedure.published_revision, procedure.draft_revision])
      end
    end
  end

  describe "#unpublish!" do
    let(:procedure) { create(:procedure, :published) }
    let(:now) { Time.zone.now.beginning_of_minute }

    before do
      Timecop.freeze(now) do
        procedure.unpublish!
      end
    end

    it {
      expect(procedure.closed_at).to eq(nil)
      expect(procedure.published_at).not_to be_nil
      expect(procedure.unpublished_at).to eq(now)
    }

    it 'sets published revision' do
      expect(procedure.published_revision).not_to be_nil
      expect(procedure.draft_revision).not_to be_nil
      expect(procedure.revisions.count).to eq(2)
      expect(procedure.revisions).to eq([procedure.published_revision, procedure.draft_revision])
    end
  end

  describe "#brouillon?" do
    let(:procedure_brouillon) { build(:procedure) }
    let(:procedure_publiee) { build(:procedure, :published) }
    let(:procedure_close) { build(:procedure, :closed) }
    let(:procedure_depubliee) { build(:procedure, :unpublished) }

    it { expect(procedure_brouillon.brouillon?).to be_truthy }
    it { expect(procedure_publiee.brouillon?).to be_falsey }
    it { expect(procedure_close.brouillon?).to be_falsey }
    it { expect(procedure_depubliee.brouillon?).to be_falsey }
  end

  describe "#publiee?" do
    let(:procedure_brouillon) { build(:procedure) }
    let(:procedure_publiee) { build(:procedure, :published) }
    let(:procedure_close) { build(:procedure, :closed) }
    let(:procedure_depubliee) { build(:procedure, :unpublished) }

    it { expect(procedure_brouillon.publiee?).to be_falsey }
    it { expect(procedure_publiee.publiee?).to be_truthy }
    it { expect(procedure_close.publiee?).to be_falsey }
    it { expect(procedure_depubliee.publiee?).to be_falsey }
  end

  describe "#close?" do
    let(:procedure_brouillon) { build(:procedure) }
    let(:procedure_publiee) { build(:procedure, :published) }
    let(:procedure_close) { build(:procedure, :closed) }
    let(:procedure_depubliee) { build(:procedure, :unpublished) }

    it { expect(procedure_brouillon.close?).to be_falsey }
    it { expect(procedure_publiee.close?).to be_falsey }
    it { expect(procedure_close.close?).to be_truthy }
    it { expect(procedure_depubliee.close?).to be_falsey }
  end

  describe "#depubliee?" do
    let(:procedure_brouillon) { build(:procedure) }
    let(:procedure_publiee) { build(:procedure, :published) }
    let(:procedure_close) { build(:procedure, :closed) }
    let(:procedure_depubliee) { build(:procedure, :unpublished) }

    it { expect(procedure_brouillon.depubliee?).to be_falsey }
    it { expect(procedure_publiee.depubliee?).to be_falsey }
    it { expect(procedure_close.depubliee?).to be_falsey }
    it { expect(procedure_depubliee.depubliee?).to be_truthy }
  end

  describe "#locked?" do
    let(:procedure_brouillon) { build(:procedure) }
    let(:procedure_publiee) { build(:procedure, :published) }
    let(:procedure_close) { build(:procedure, :closed) }
    let(:procedure_depubliee) { build(:procedure, :unpublished) }

    it { expect(procedure_brouillon.locked?).to be_falsey }
    it { expect(procedure_publiee.locked?).to be_truthy }
    it { expect(procedure_close.locked?).to be_truthy }
    it { expect(procedure_depubliee.locked?).to be_truthy }
  end

  describe 'close' do
    let(:procedure) { create(:procedure, :published) }
    let(:now) { Time.zone.now.beginning_of_minute }
    before do
      Timecop.freeze(now) do
        procedure.close!
      end
      procedure.reload
    end

    it { expect(procedure.close?).to be_truthy }
    it { expect(procedure.closed_at).to eq(now) }

    it 'sets published revision' do
      expect(procedure.published_revision).not_to be_nil
      expect(procedure.draft_revision).not_to be_nil
      expect(procedure.revisions.count).to eq(2)
      expect(procedure.revisions).to eq([procedure.published_revision, procedure.draft_revision])
    end
  end

  describe 'path_customized?' do
    let(:procedure) { create :procedure }

    subject { procedure.path_customized? }

    context 'when the path is still the default' do
      it { is_expected.to be_falsey }
    end

    context 'when the path has been changed' do
      before { procedure.path = 'custom_path' }

      it { is_expected.to be_truthy }
    end
  end

  describe 'total_dossier' do
    let(:procedure) { create :procedure }

    before do
      create :dossier, procedure: procedure, state: Dossier.states.fetch(:en_construction)
      create :dossier, procedure: procedure, state: Dossier.states.fetch(:brouillon)
      create :dossier, procedure: procedure, state: Dossier.states.fetch(:en_construction)
    end

    subject { procedure.total_dossier }

    it { is_expected.to eq 2 }
  end

  describe 'suggested_path' do
    let(:procedure) { create(:procedure, aasm_state: :publiee, libelle: 'Inscription au Collège') }

    subject { procedure.suggested_path(procedure.administrateurs.first) }

    context 'when the path has been customized' do
      before { procedure.path = 'custom_path' }

      it { is_expected.to eq 'custom_path' }
    end

    context 'when the suggestion does not conflict' do
      it { is_expected.to eq 'inscription-au-college' }
    end

    context 'when the suggestion conflicts with one procedure' do
      before do
        create(:procedure, aasm_state: :publiee, path: 'inscription-au-college')
      end

      it { is_expected.to eq 'inscription-au-college-2' }
    end

    context 'when the suggestion conflicts with several procedures' do
      before do
        create(:procedure, aasm_state: :publiee, path: 'inscription-au-college')
        create(:procedure, aasm_state: :publiee, path: 'inscription-au-college-2')
      end

      it { is_expected.to eq 'inscription-au-college-3' }
    end

    context 'when the suggestion conflicts with another procedure of the same admin' do
      before do
        create(:procedure, aasm_state: :publiee, path: 'inscription-au-college', administrateurs: procedure.administrateurs)
      end

      it { is_expected.to eq 'inscription-au-college' }
    end
  end

  describe ".default_scope" do
    let!(:procedure) { create(:procedure, hidden_at: hidden_at) }

    context "when hidden_at is nil" do
      let(:hidden_at) { nil }

      it { expect(Procedure.count).to eq(1) }
      it { expect(Procedure.all).to include(procedure) }
    end

    context "when hidden_at is not nil" do
      let(:hidden_at) { 2.days.ago }

      it { expect(Procedure.count).to eq(0) }
      it { expect { Procedure.find(procedure.id) }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end

  describe "#discard_and_keep_track!" do
    let(:super_admin) { create(:super_admin) }
    let(:procedure) { create(:procedure) }
    let!(:dossier) { create(:dossier, procedure: procedure) }
    let!(:dossier2) { create(:dossier, procedure: procedure) }
    let(:instructeur) { create(:instructeur) }

    it { expect(Dossier.count).to eq(2) }
    it { expect(Dossier.all).to include(dossier, dossier2) }

    context "when discarding procedure" do
      before do
        instructeur.followed_dossiers << dossier
        procedure.discard_and_keep_track!(super_admin)
        instructeur.reload
      end

      it { expect(procedure.dossiers.count).to eq(0) }
      it { expect(Dossier.count).to eq(0) }
      it { expect(instructeur.followed_dossiers).not_to include(dossier) }
    end
  end

  describe ".default_sort" do
    it { expect(Procedure.default_sort).to eq({ "table" => "self", "column" => "id", "order" => "desc" }) }
  end

  describe "#export_filename" do
    before { Timecop.freeze(Time.zone.local(2018, 1, 2, 23, 11, 14)) }
    after { Timecop.return }

    subject { procedure.export_filename(:csv) }

    let(:procedure) { create(:procedure, :published) }

    it { is_expected.to eq("dossiers_#{procedure.path}_2018-01-02_23-11.csv") }
  end

  describe '#new_dossier' do
    let(:procedure) do
      create(:procedure,
        types_de_champ: [
          build(:type_de_champ_text, position: 0),
          build(:type_de_champ_number, position: 1)
        ],
        types_de_champ_private: [
          build(:type_de_champ_textarea, :private)
        ])
    end

    let(:dossier) { procedure.active_revision.new_dossier }

    it { expect(dossier.procedure).to eq(procedure) }

    it { expect(dossier.champs.size).to eq(2) }
    it { expect(dossier.champs[0].type).to eq("Champs::TextChamp") }

    it { expect(dossier.champs_private.size).to eq(1) }
    it { expect(dossier.champs_private[0].type).to eq("Champs::TextareaChamp") }

    it { expect(Champ.count).to eq(0) }
  end

  describe "#organisation_name" do
    subject { procedure.organisation_name }
    context 'when the procedure has a service (and no organization)' do
      let(:procedure) { create(:procedure, :with_service, organisation: nil) }
      it { is_expected.to eq procedure.service.nom }
    end

    context 'when the procedure has an organization (and no service)' do
      let(:procedure) { create(:procedure, organisation: 'DDT des Vosges', service: nil) }
      it { is_expected.to eq procedure.organisation }
    end
  end

  describe '#juridique_required' do
    it 'automatically jumps to true once cadre_juridique or deliberation have been set' do
      p = create(
        :procedure,
        juridique_required: false,
        cadre_juridique: nil
      )

      expect(p.juridique_required).to be_falsey

      p.update(cadre_juridique: 'cadre')
      expect(p.juridique_required).to be_truthy

      p.update(cadre_juridique: nil)
      expect(p.juridique_required).to be_truthy

      p.update_columns(cadre_juridique: nil, juridique_required: false)
      p.reload
      expect(p.juridique_required).to be_falsey

      @deliberation = fixture_file_upload('spec/fixtures/files/file.pdf', 'application/pdf')
      p.update(deliberation: @deliberation)
      p.reload
      expect(p.juridique_required).to be_truthy
    end
  end

  describe '.ensure_a_groupe_instructeur_exists' do
    let!(:procedure) { create(:procedure) }

    it { expect(procedure.groupe_instructeurs.count).to eq(1) }
    it { expect(procedure.groupe_instructeurs.first.label).to eq(GroupeInstructeur::DEFAUT_LABEL) }
  end

  describe '.missing_instructeurs?' do
    let!(:procedure) { create(:procedure) }

    subject { procedure.missing_instructeurs? }

    it { is_expected.to be true }

    context 'when an instructeur is assign to this procedure' do
      let!(:instructeur) { create(:instructeur) }

      before { instructeur.assign_to_procedure(procedure) }

      it { is_expected.to be false }
    end
  end

  describe "#destroy" do
    let(:procedure) { create(:procedure, :closed, :with_type_de_champ) }

    before do
      procedure.discard!
    end

    it "can destroy procedure" do
      expect(procedure.revisions.count).to eq(2)
      expect(procedure.destroy).to be_truthy
    end
  end

  describe '#average_dossier_weight' do
    let(:procedure) { create(:procedure, :published) }

    before do
      create_dossier_with_pj_of_size(4, procedure)
      create_dossier_with_pj_of_size(5, procedure)
      create_dossier_with_pj_of_size(6, procedure)
    end

    it 'estimates average dossier weight' do
      expect(procedure.reload.average_dossier_weight).to eq(5 + Procedure::MIN_WEIGHT)
    end
  end

  private

  def create_dossier_with_pj_of_size(size, procedure)
    dossier = create(:dossier, :accepte, procedure: procedure)
    create(:champ_piece_justificative, size: size, dossier: dossier)
  end
end
