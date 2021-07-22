# == Schema Information
#
# Table name: procedures
#
#  id                                        :integer          not null, primary key
#  aasm_state                                :string           default("brouillon")
#  allow_expert_review                       :boolean          default(TRUE), not null
#  api_entreprise_token                      :string
#  ask_birthday                              :boolean          default(FALSE), not null
#  auto_archive_on                           :date
#  cadre_juridique                           :string
#  cerfa_flag                                :boolean          default(FALSE)
#  cloned_from_library                       :boolean          default(FALSE)
#  closed_at                                 :datetime
#  declarative_with_state                    :string
#  description                               :string
#  direction                                 :string
#  duree_conservation_dossiers_dans_ds       :integer
#  duree_conservation_dossiers_hors_ds       :integer
#  durees_conservation_required              :boolean          default(TRUE)
#  encrypted_api_particulier_token           :string
#  euro_flag                                 :boolean          default(FALSE)
#  experts_require_administrateur_invitation :boolean          default(FALSE)
#  for_individual                            :boolean          default(FALSE)
#  hidden_at                                 :datetime
#  juridique_required                        :boolean          default(TRUE)
#  libelle                                   :string
#  lien_demarche                             :string
#  lien_notice                               :string
#  lien_site_web                             :string
#  monavis_embed                             :text
#  organisation                              :string
#  path                                      :string           not null
#  published_at                              :datetime
#  routing_criteria_name                     :text             default("Votre ville")
#  test_started_at                           :datetime
#  unpublished_at                            :datetime
#  web_hook_url                              :string
#  whitelisted_at                            :datetime
#  created_at                                :datetime         not null
#  updated_at                                :datetime         not null
#  canonical_procedure_id                    :bigint
#  draft_revision_id                         :bigint
#  parent_procedure_id                       :bigint
#  published_revision_id                     :bigint
#  service_id                                :bigint
#

class Procedure < ApplicationRecord
  include ProcedureStatsConcern
  include EncryptableConcern

  include Discard::Model
  self.discard_column = :hidden_at
  default_scope -> { kept }

  MAX_DUREE_CONSERVATION = 36
  MAX_DUREE_CONSERVATION_EXPORT = 3.hours

  MIN_WEIGHT = 350000

  attr_encrypted :api_particulier_token

  has_many :revisions, -> { order(:id) }, class_name: 'ProcedureRevision', inverse_of: :procedure
  belongs_to :draft_revision, class_name: 'ProcedureRevision', optional: false
  belongs_to :published_revision, class_name: 'ProcedureRevision', optional: true
  has_many :deleted_dossiers, dependent: :destroy

  has_many :published_types_de_champ, through: :published_revision, source: :types_de_champ
  has_many :published_types_de_champ_private, through: :published_revision, source: :types_de_champ_private
  has_many :draft_types_de_champ, through: :draft_revision, source: :types_de_champ
  has_many :draft_types_de_champ_private, through: :draft_revision, source: :types_de_champ_private

  has_many :experts_procedures, dependent: :destroy
  has_many :experts, through: :experts_procedures

  has_one :module_api_carto, dependent: :destroy
  has_one :attestation_template, dependent: :destroy

  belongs_to :parent_procedure, class_name: 'Procedure', optional: true
  belongs_to :canonical_procedure, class_name: 'Procedure', optional: true
  belongs_to :service, optional: true

  def active_revision
    brouillon? ? draft_revision : published_revision
  end

  def types_de_champ
    brouillon? ? draft_types_de_champ : published_types_de_champ
  end

  def types_de_champ_private
    brouillon? ? draft_types_de_champ_private : published_types_de_champ_private
  end

  def types_de_champ_for_procedure_presentation
    explanatory_types_de_champ = [:header_section, :explication, :repetition].map { |k| TypeDeChamp.type_champs.fetch(k) }

    if brouillon?
      TypeDeChamp
        .joins(:revisions)
        .where.not(type_champ: explanatory_types_de_champ)
        .where(procedure_revisions: { id: draft_revision_id })
        .order(:private, :position)
    else
      # fetch all type_de_champ.stable_id for all the revisions expect draft
      # and for each stable_id take the bigger (more recent) type_de_champ.id
      recent_ids = TypeDeChamp
        .joins(:revisions)
        .where.not(type_champ: explanatory_types_de_champ)
        .where(procedure_revisions: { procedure_id: id })
        .where.not(procedure_revisions: { id: draft_revision_id })
        .group(:stable_id)
        .select('MAX(types_de_champ.id)')

      # fetch the more recent procedure_revision_types_de_champ
      # which includes recents_ids
      recents_prtdc = ProcedureRevisionTypeDeChamp
        .where(type_de_champ_id: recent_ids)
        .where.not(revision_id: draft_revision_id)
        .group(:type_de_champ_id)
        .select('MAX(id)')

      TypeDeChamp
        .joins(:revision_types_de_champ)
        .where(revision_types_de_champ: { id: recents_prtdc })
        .order(:private, :position, 'revision_types_de_champ.revision_id': :desc)
    end
  end

  def types_de_champ_for_tags
    if brouillon?
      draft_types_de_champ
    else
      TypeDeChamp.root
        .public_only
        .where(revision: revisions - [draft_revision])
        .order(:created_at)
        .uniq
    end
  end

  def types_de_champ_private_for_tags
    if brouillon?
      draft_types_de_champ_private
    else
      TypeDeChamp.root
        .private_only
        .where(revision: revisions - [draft_revision])
        .order(:created_at)
        .uniq
    end
  end

  has_many :administrateurs_procedures
  has_many :administrateurs, through: :administrateurs_procedures, after_remove: -> (procedure, _admin) { procedure.validate! }
  has_many :groupe_instructeurs, dependent: :destroy
  has_many :instructeurs, through: :groupe_instructeurs

  # This relationship is used in following dossiers through. We can not use revisions relationship
  # as order scope introduces invalid sql in some combinations.
  has_many :unordered_revisions, class_name: 'ProcedureRevision', inverse_of: :procedure, dependent: :destroy
  has_many :dossiers, through: :unordered_revisions, dependent: :restrict_with_exception

  has_one :initiated_mail, class_name: "Mails::InitiatedMail", dependent: :destroy
  has_one :received_mail, class_name: "Mails::ReceivedMail", dependent: :destroy
  has_one :closed_mail, class_name: "Mails::ClosedMail", dependent: :destroy
  has_one :refused_mail, class_name: "Mails::RefusedMail", dependent: :destroy
  has_one :without_continuation_mail, class_name: "Mails::WithoutContinuationMail", dependent: :destroy

  has_one :defaut_groupe_instructeur, -> { order(:label) }, class_name: 'GroupeInstructeur', inverse_of: :procedure

  has_one_attached :logo
  has_one_attached :notice
  has_one_attached :deliberation

  scope :brouillons,            -> { where(aasm_state: :brouillon) }
  scope :publiees,              -> { where(aasm_state: :publiee) }
  scope :closes,                -> { where(aasm_state: [:close, :depubliee]) }
  scope :publiees_ou_closes,    -> { where(aasm_state: [:publiee, :close, :depubliee]) }
  scope :by_libelle,            -> { order(libelle: :asc) }
  scope :created_during,        -> (range) { where(created_at: range) }
  scope :cloned_from_library,   -> { where(cloned_from_library: true) }
  scope :declarative,           -> { where.not(declarative_with_state: nil) }

  scope :discarded_expired, -> do
    with_discarded
      .discarded
      .where('hidden_at < ?', 1.month.ago)
  end

  scope :for_api, -> {
    includes(
      :administrateurs,
      :module_api_carto,
      published_revision: [
        :types_de_champ_private,
        :types_de_champ
      ],
      draft_revision: [
        :types_de_champ_private,
        :types_de_champ
      ]
    )
  }

  enum declarative_with_state: {
    en_instruction:  'en_instruction',
    accepte:         'accepte'
  }

  scope :for_api_v2, -> {
    includes(:draft_revision, :published_revision, administrateurs: :user)
  }

  scope :for_download, -> {
    includes(
      :groupe_instructeurs,
      dossiers: {
        champs: [
          piece_justificative_file_attachment: :blob,
          champs: [
            piece_justificative_file_attachment: :blob
          ]
        ]
      }
    )
  }

  validates :libelle, presence: true, allow_blank: false, allow_nil: false
  validates :description, presence: true, allow_blank: false, allow_nil: false
  validates :administrateurs, presence: true
  validates :lien_site_web, presence: true, if: :publiee?
  validate :validate_for_publication, on: :publication
  validate :check_juridique
  validates :path, presence: true, format: { with: /\A[a-z0-9_\-]{3,200}\z/ }, uniqueness: { scope: [:path, :closed_at, :hidden_at, :unpublished_at], case_sensitive: false }
  validates :duree_conservation_dossiers_dans_ds, allow_nil: false, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_DUREE_CONSERVATION }
  validates :duree_conservation_dossiers_hors_ds, allow_nil: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates_with MonAvisEmbedValidator
  validates :notice, content_type: [
    "application/msword",
    "application/pdf",
    "application/vnd.ms-powerpoint",
    "application/vnd.oasis.opendocument.presentation",
    "application/vnd.oasis.opendocument.text",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "image/jpeg",
    "image/jpg",
    "image/png",
    "text/plain"
  ], size: { less_than: 20.megabytes }, if: -> { new_record? || created_at > Date.new(2020, 2, 28) }

  validates :deliberation, content_type: [
    "application/msword",
    "application/pdf",
    "application/vnd.oasis.opendocument.text",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "image/jpeg",
    "image/jpg",
    "image/png",
    "text/plain"
  ], size: { less_than: 20.megabytes }, if: -> { new_record? || created_at > Date.new(2020, 4, 29) }

  validates :logo, content_type: ['image/png', 'image/jpg', 'image/jpeg'],
    size: { less_than: 5.megabytes },
    if: -> { new_record? || created_at > Date.new(2020, 11, 13) }

  validates :api_entreprise_token, jwt_token: true, allow_blank: true
  validates :api_particulier_token, format: { with: /\A[A-Za-z0-9\-_=.]{15,}\z/, message: "n'est pas un jeton valide" }, allow_blank: true

  before_save :update_juridique_required
  after_initialize :ensure_path_exists
  before_save :ensure_path_exists
  after_create :ensure_defaut_groupe_instructeur

  include AASM

  aasm whiny_persistence: true do
    state :brouillon, initial: true
    state :publiee
    state :close
    state :depubliee

    event :publish, before: :before_publish do
      transitions from: :brouillon, to: :publiee, after: :after_publish
      transitions from: :close, to: :publiee, after: :after_republish
      transitions from: :depubliee, to: :publiee, after: :after_republish
    end

    event :close, after: :after_close do
      transitions from: :publiee, to: :close
    end

    event :unpublish, after: :after_unpublish do
      transitions from: :publiee, to: :depubliee
    end
  end

  def publish_or_reopen!(administrateur)
    Procedure.transaction do
      if brouillon?
        reset!
      end

      other_procedure = other_procedure_with_path(path)
      if other_procedure.present? && administrateur.owns?(other_procedure)
        other_procedure.unpublish!
        publish!(other_procedure.canonical_procedure || other_procedure)
      else
        publish!
      end
    end
  end

  def reset!
    if !locked? || draft_changed?
      draft_revision.dossiers.destroy_all
    end
  end

  def validate_for_publication
    old_attributes = self.slice(:aasm_state, :closed_at)
    self.aasm_state = :publiee
    self.closed_at = nil

    is_valid = validate

    self.attributes = old_attributes

    is_valid
  end

  def suggested_path(administrateur)
    if path_customized?
      return path
    end
    slug = libelle&.parameterize&.first(50)
    suggestion = slug
    counter = 1
    while !path_available?(administrateur, suggestion)
      counter = counter + 1
      suggestion = "#{slug}-#{counter}"
    end
    suggestion
  end

  def other_procedure_with_path(path)
    Procedure.publiees
      .where.not(id: self.id)
      .find_by(path: path)
  end

  def path_available?(administrateur, path)
    procedure = other_procedure_with_path(path)

    procedure.blank? || (administrateur.owns?(procedure) && canonical_procedure_child?(procedure))
  end

  def canonical_procedure_child?(procedure)
    !canonical_procedure || canonical_procedure == procedure || canonical_procedure == procedure.canonical_procedure
  end

  def locked?
    publiee? || close? || depubliee?
  end

  def draft_changed?
    publiee? && published_revision.changed?(draft_revision) && revision_changes.present?
  end

  def revision_changes
    published_revision.compare(draft_revision)
  end

  def accepts_new_dossiers?
    publiee? || brouillon?
  end

  def dossier_can_transition_to_en_construction?
    accepts_new_dossiers? || depubliee?
  end

  def expose_legacy_carto_api?
    module_api_carto&.use_api_carto? && module_api_carto&.migrated?
  end

  def declarative?
    declarative_with_state.present?
  end

  def declarative_accepte?
    declarative_with_state == Procedure.declarative_with_states.fetch(:accepte)
  end

  def self.declarative_attributes_for_select
    declarative_with_states.map do |state, _|
      [I18n.t("activerecord.attributes.#{model_name.i18n_key}.declarative_with_state/#{state}"), state]
    end
  end

  def feature_enabled?(feature)
    Flipper.enabled?(feature, self)
  end

  def path_customized?
    !path.match?(/[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}/)
  end

  def organisation_name
    service&.nom || organisation
  end

  def self.active(id)
    publiees.find(id)
  end

  def clone(admin, from_library)
    is_different_admin = !admin.owns?(self)

    populate_champ_stable_ids
    include_list = {
      attestation_template: [],
      draft_revision: {
        revision_types_de_champ: {
          type_de_champ: :types_de_champ
        },
        revision_types_de_champ_private: {
          type_de_champ: :types_de_champ
        }
      }
    }
    include_list[:groupe_instructeurs] = :instructeurs if !is_different_admin
    procedure = self.deep_clone(include: include_list) do |original, kopy|
      PiecesJustificativesService.clone_attachments(original, kopy)
    end
    procedure.path = SecureRandom.uuid
    procedure.aasm_state = :brouillon
    procedure.closed_at = nil
    procedure.unpublished_at = nil
    procedure.published_at = nil
    procedure.lien_notice = nil
    procedure.published_revision = nil
    procedure.draft_revision.procedure = procedure

    if is_different_admin
      procedure.administrateurs = [admin]
      procedure.api_entreprise_token = nil
      procedure.encrypted_api_particulier_token = nil
    else
      procedure.administrateurs = administrateurs
    end

    procedure.initiated_mail = initiated_mail&.dup
    procedure.received_mail = received_mail&.dup
    procedure.closed_mail = closed_mail&.dup
    procedure.refused_mail = refused_mail&.dup
    procedure.without_continuation_mail = without_continuation_mail&.dup
    procedure.ask_birthday = false # see issue #4242

    procedure.cloned_from_library = from_library
    procedure.parent_procedure = self
    procedure.canonical_procedure = nil

    if from_library
      procedure.service = nil
    elsif self.service.present? && is_different_admin
      procedure.service = self.service.clone_and_assign_to_administrateur(admin)
    end

    procedure.save
    procedure.draft_types_de_champ.update_all(revision_id: procedure.draft_revision.id)
    procedure.draft_types_de_champ_private.update_all(revision_id: procedure.draft_revision.id)
    TypeDeChamp.where(parent: procedure.draft_types_de_champ.repetition + procedure.draft_types_de_champ_private.repetition).update_all(revision_id: procedure.draft_revision.id)

    if is_different_admin || from_library
      procedure.draft_types_de_champ.each { |tdc| tdc.options&.delete(:old_pj) }
    end

    procedure
  end

  def whitelisted?
    whitelisted_at.present?
  end

  def total_dossier
    self.dossiers.state_not_brouillon.size
  end

  def export_filename(format)
    procedure_identifier = path || "procedure-#{id}"
    "dossiers_#{procedure_identifier}_#{Time.zone.now.strftime('%Y-%m-%d_%H-%M')}.#{format}"
  end

  def export(dossiers)
    ProcedureExportService.new(self, dossiers)
  end

  def to_csv(dossiers)
    export(dossiers).to_csv
  end

  def to_xlsx(dossiers)
    export(dossiers).to_xlsx
  end

  def to_ods(dossiers)
    export(dossiers).to_ods
  end

  def procedure_overview(start_date, groups)
    ProcedureOverview.new(self, start_date, groups)
  end

  def initiated_mail_template
    initiated_mail || Mails::InitiatedMail.default_for_procedure(self)
  end

  def received_mail_template
    received_mail || Mails::ReceivedMail.default_for_procedure(self)
  end

  def closed_mail_template
    closed_mail || Mails::ClosedMail.default_for_procedure(self)
  end

  def refused_mail_template
    refused_mail || Mails::RefusedMail.default_for_procedure(self)
  end

  def without_continuation_mail_template
    without_continuation_mail || Mails::WithoutContinuationMail.default_for_procedure(self)
  end

  def mail_template_for(state)
    case state
    when Dossier.states.fetch(:en_construction)
      initiated_mail_template
    when Dossier.states.fetch(:en_instruction)
      received_mail_template
    when Dossier.states.fetch(:accepte)
      closed_mail_template
    when Dossier.states.fetch(:refuse)
      refused_mail_template
    when Dossier.states.fetch(:sans_suite)
      without_continuation_mail_template
    else
      raise "Unknown dossier state: #{state}"
    end
  end

  def self.default_sort
    {
      'table' => 'self',
      'column' => 'id',
      'order' => 'desc'
    }
  end

  def whitelist!
    touch(:whitelisted_at)
  end

  def closed_mail_template_attestation_inconsistency_state
    # As an optimization, don’t check the predefined templates (they are presumed correct)
    if closed_mail.present?
      tag_present = closed_mail.body.to_s.include?("--lien attestation--")
      if attestation_template&.activated? && !tag_present
        :missing_tag
      elsif !attestation_template&.activated? && tag_present
        :extraneous_tag
      end
    end
  end

  def populate_champ_stable_ids
    TypeDeChamp
      .joins(:revisions)
      .where(procedure_revisions: { procedure_id: id }, stable_id: nil)
      .find_each do |type_de_champ|
        type_de_champ.update_column(:stable_id, type_de_champ.id)
      end
  end

  def missing_steps
    result = []

    if service.nil?
      result << :service
    end

    if missing_instructeurs?
      result << :instructeurs
    end

    result
  end

  def process_dossiers!
    case declarative_with_state
    when Procedure.declarative_with_states.fetch(:en_instruction)
      dossiers
        .state_en_construction
        .where(declarative_triggered_at: nil)
        .find_each(&:passer_automatiquement_en_instruction!)
    when Procedure.declarative_with_states.fetch(:accepte)
      dossiers
        .state_en_construction
        .where(declarative_triggered_at: nil)
        .find_each(&:accepter_automatiquement!)
    end
  end

  def logo_url
    if logo.attached?
      Rails.application.routes.url_helpers.url_for(logo)
    else
      ActionController::Base.helpers.image_url(PROCEDURE_DEFAULT_LOGO_SRC)
    end
  end

  def missing_instructeurs?
    !AssignTo.exists?(groupe_instructeur: groupe_instructeurs)
  end

  def routee?
    groupe_instructeurs.size > 1
  end

  def defaut_groupe_instructeur_for_new_dossier
    if !routee? || feature_enabled?(:procedure_routage_api)
      defaut_groupe_instructeur
    end
  end

  def can_be_deleted_by_administrateur?
    brouillon? || dossiers.state_instruction_commencee.empty?
  end

  def can_be_deleted_by_manager?
    kept? && can_be_deleted_by_administrateur?
  end

  def discard_and_keep_track!(author)
    if brouillon?
      reset!
    elsif publiee?
      close!
    end

    dossiers.each do |dossier|
      dossier.discard_and_keep_track!(author, :procedure_removed)
    end

    discard!
  end

  def restore(author)
    if discarded? && undiscard
      dossiers.with_discarded.discarded.find_each do |dossier|
        dossier.restore(author, true)
      end
    end
  end

  def flipper_id
    "Procedure;#{id}"
  end

  def api_entreprise_role?(role)
    APIEntrepriseToken.new(api_entreprise_token).role?(role)
  end

  def api_entreprise_token
    self[:api_entreprise_token].presence || Rails.application.secrets.api_entreprise[:key]
  end

  def api_entreprise_token_expired?
    APIEntrepriseToken.new(api_entreprise_token).expired?
  end

  def create_new_revision
    draft_revision.deep_clone(include: [:revision_types_de_champ, :revision_types_de_champ_private])
  end

  def average_dossier_weight
    if dossiers.termine.any?
      dossiers_sample = dossiers.termine.limit(100)
      total_size = Champ
        .includes(piece_justificative_file_attachment: :blob)
        .where(type: Champs::PieceJustificativeChamp.to_s, dossier: dossiers_sample)
        .sum('active_storage_blobs.byte_size')

      MIN_WEIGHT + total_size / dossiers_sample.length
    else
      nil
    end
  end

  def publish_revision!
    update!(draft_revision: create_new_revision, published_revision: draft_revision)
    published_revision.touch(:published_at)
  end

  private

  def before_publish
    update!(closed_at: nil, unpublished_at: nil)
  end

  def after_publish(canonical_procedure = nil)
    update!(canonical_procedure: canonical_procedure, draft_revision: create_new_revision, published_revision: draft_revision)
    touch(:published_at)
    published_revision.touch(:published_at)
  end

  def after_republish(canonical_procedure = nil)
    touch(:published_at)
  end

  def after_close
    touch(:closed_at)
  end

  def after_unpublish
    touch(:unpublished_at)
  end

  def update_juridique_required
    self.juridique_required ||= (cadre_juridique.present? || deliberation.attached?)
    true
  end

  def check_juridique
    if juridique_required? && (cadre_juridique.blank? && !deliberation.attached?)
      errors.add(:cadre_juridique, " : veuillez remplir le texte de loi ou la délibération")
    end
  end

  def ensure_path_exists
    if self.path.blank?
      self.path = SecureRandom.uuid
    end
  end

  def ensure_defaut_groupe_instructeur
    if self.groupe_instructeurs.empty?
      groupe_instructeurs.create(label: GroupeInstructeur::DEFAUT_LABEL)
    end
  end
end
