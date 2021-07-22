# == Schema Information
#
# Table name: procedure_presentations
#
#  id               :integer          not null, primary key
#  displayed_fields :jsonb            not null
#  filters          :jsonb            not null
#  sort             :jsonb            not null
#  created_at       :datetime
#  updated_at       :datetime
#  assign_to_id     :integer
#
class ProcedurePresentation < ApplicationRecord
  EXTRA_SORT_COLUMNS = {
    'notifications' => ['notifications'],
    'self' => ['id', 'state']
  }

  TABLE = 'table'
  COLUMN = 'column'
  SLASH = '/'
  TYPE_DE_CHAMP = 'type_de_champ'
  TYPE_DE_CHAMP_PRIVATE = 'type_de_champ_private'

  FILTERS_VALUE_MAX_LENGTH = 100

  belongs_to :assign_to, optional: false

  delegate :procedure, to: :assign_to

  validate :check_allowed_displayed_fields
  validate :check_allowed_sort_column
  validate :check_allowed_sort_order
  validate :check_allowed_filter_columns
  validate :check_filters_max_length

  def fields
    fields = [
      field_hash('Créé le', 'self', 'created_at'),
      field_hash('En construction le', 'self', 'en_construction_at'),
      field_hash('Mis à jour le', 'self', 'updated_at'),
      field_hash('Demandeur', 'user', 'email'),
      field_hash('Email instructeur', 'followers_instructeurs', 'email'),
      field_hash('Groupe instructeur', 'groupe_instructeur', 'label')
    ]

    if procedure.for_individual
      fields.push(
        field_hash("Prénom", "individual", "prenom"),
        field_hash("Nom", "individual", "nom"),
        field_hash("Civilité", "individual", "gender")
      )
    end

    if !procedure.for_individual
      fields.push(
        field_hash('SIREN', 'etablissement', 'entreprise_siren'),
        field_hash('Forme juridique', 'etablissement', 'entreprise_forme_juridique'),
        field_hash('Nom commercial', 'etablissement', 'entreprise_nom_commercial'),
        field_hash('Raison sociale', 'etablissement', 'entreprise_raison_sociale'),
        field_hash('SIRET siège social', 'etablissement', 'entreprise_siret_siege_social'),
        field_hash('Date de création', 'etablissement', 'entreprise_date_creation')
      )

      fields.push(
        field_hash('SIRET', 'etablissement', 'siret'),
        field_hash('Libellé NAF', 'etablissement', 'libelle_naf'),
        field_hash('Code postal', 'etablissement', 'code_postal')
      )
    end

    fields.concat procedure.types_de_champ_for_procedure_presentation
      .pluck(:libelle, :private, :stable_id)
      .map { |(libelle, is_private, stable_id)| field_hash(libelle, is_private ? TYPE_DE_CHAMP_PRIVATE : TYPE_DE_CHAMP, stable_id.to_s) }

    fields
  end

  def displayed_fields_for_select
    [
      fields.map { |field| [field['label'], field_id(field)] },
      displayed_fields.map { |field| field_id(field) }
    ]
  end

  def sorted_ids(dossiers, count, instructeur)
    table, column, order = sort.values_at(TABLE, COLUMN, 'order')

    case table
    when 'notifications'
      dossiers_id_with_notification = dossiers.merge(instructeur.followed_dossiers).with_notifications.ids
      if order == 'desc'
        dossiers_id_with_notification +
            (dossiers.order('dossiers.updated_at desc').ids - dossiers_id_with_notification)
      else
        (dossiers.order('dossiers.updated_at asc').ids - dossiers_id_with_notification) +
            dossiers_id_with_notification
      end
    when TYPE_DE_CHAMP
      ids = dossiers
        .with_type_de_champ(column)
        .order("champs.value #{order}")
        .pluck(:id)
      if ids.size != count
        rest = dossiers.where.not(id: ids).order(id: order).pluck(:id)
        order == 'asc' ? ids + rest : rest + ids
      else
        ids
      end
    when TYPE_DE_CHAMP_PRIVATE
      ids = dossiers
        .with_type_de_champ_private(column)
        .order("champs.value #{order}")
        .pluck(:id)
      if ids.size != count
        rest = dossiers.where.not(id: ids).order(id: order).pluck(:id)
        order == 'asc' ? ids + rest : rest + ids
      else
        ids
      end
    when 'followers_instructeurs'
      assert_supported_column(table, column)
      # LEFT OUTER JOIN allows to keep dossiers without assignated instructeurs yet
      dossiers
        .includes(:followers_instructeurs)
        .joins('LEFT OUTER JOIN users instructeurs_users ON instructeurs_users.instructeur_id = instructeurs.id')
        .order("instructeurs_users.email #{order}")
        .pluck(:id)
        .uniq
    when 'self', 'user', 'individual', 'etablissement', 'groupe_instructeur'
      (table == 'self' ? dossiers : dossiers.includes(table))
        .order("#{self.class.sanitized_column(table, column)} #{order}")
        .pluck(:id)
    end
  end

  def filtered_ids(dossiers, statut)
    filters[statut].group_by { |filter| filter.values_at(TABLE, COLUMN) } .map do |(table, column), filters|
      values = filters.pluck('value')
      case table
      when 'self'
        dates = values
          .filter_map { |v| Time.zone.parse(v).beginning_of_day rescue nil }

        dossiers.filter_by_datetimes(column, dates)
      when TYPE_DE_CHAMP
        dossiers.with_type_de_champ(column)
          .filter_ilike(:champs, :value, values)
      when TYPE_DE_CHAMP_PRIVATE
        dossiers.with_type_de_champ_private(column)
          .filter_ilike(:champs_private, :value, values)
      when 'etablissement'
        if column == 'entreprise_date_creation'
          dates = values
            .filter_map { |v| v.to_date rescue nil }

          dossiers
            .includes(table)
            .where(table.pluralize => { column => dates })
        else
          dossiers
            .includes(table)
            .filter_ilike(table, column, values)
        end
      when 'followers_instructeurs'
        assert_supported_column(table, column)
        dossiers
          .includes(:followers_instructeurs)
          .joins('INNER JOIN users instructeurs_users ON instructeurs_users.instructeur_id = instructeurs.id')
          .filter_ilike('instructeurs_users', :email, values)
      when 'user', 'individual'
        dossiers
          .includes(table)
          .filter_ilike(table, column, values)
      when 'groupe_instructeur'
        dossiers
          .joins(:groupe_instructeur)
          .filter_ilike(table, column, values)
      end.pluck(:id)
    end.reduce(:&)
  end

  def human_value_for_filter(filter)
    case filter[TABLE]
    when TYPE_DE_CHAMP, TYPE_DE_CHAMP_PRIVATE
      find_type_de_champ(filter[COLUMN]).dynamic_type.filter_to_human(filter['value'])
    else
      filter['value']
    end
  end

  def add_filter(statut, field, value)
    if value.present?
      table, column = field.split(SLASH)
      label = find_field(table, column)['label']

      case table
      when TYPE_DE_CHAMP, TYPE_DE_CHAMP_PRIVATE
        value = find_type_de_champ(column).dynamic_type.human_to_filter(value)
      end

      updated_filters = filters.dup
      updated_filters[statut] << {
        'label' => label,
        TABLE => table,
        COLUMN => column,
        'value' => value
      }

      update!(filters: updated_filters)
    end
  end

  def remove_filter(statut, field, value)
    table, column = field.split(SLASH)

    updated_filters = filters.dup
    updated_filters[statut] = filters[statut].reject do |filter|
      filter.values_at(TABLE, COLUMN, 'value') == [table, column, value]
    end

    update!(filters: updated_filters)
  end

  def update_displayed_fields(values)
    if values.nil?
      values = []
    end

    fields = values.map { |value| find_field(*value.split(SLASH)) }

    update!(displayed_fields: fields)

    if !values.include?(field_id(sort))
      update!(sort: Procedure.default_sort)
    end
  end

  def update_sort(table, column)
    order = if sort.values_at(TABLE, COLUMN) == [table, column]
      sort['order'] == 'asc' ? 'desc' : 'asc'
    else
      'asc'
    end

    update!(sort: {
      TABLE => table,
      COLUMN => column,
      'order' => order
    })
  end

  private

  def field_id(field)
    field.values_at(TABLE, COLUMN).join(SLASH)
  end

  def find_field(table, column)
    fields.find { |field| field.values_at(TABLE, COLUMN) == [table, column] }
  end

  def find_type_de_champ(column)
    TypeDeChamp.order(:revision_id).find_by(stable_id: column)
  end

  def check_allowed_displayed_fields
    displayed_fields.each do |field|
      check_allowed_field(:displayed_fields, field)
    end
  end

  def check_allowed_sort_column
    check_allowed_field(:sort, sort, EXTRA_SORT_COLUMNS)
  end

  def check_allowed_sort_order
    order = sort['order']
    if !["asc", "desc"].include?(order)
      errors.add(:sort, "#{order} n’est pas une ordre permis")
    end
  end

  def check_allowed_filter_columns
    filters.each do |key, columns|
      return true if key == 'migrated'
      columns.each do |column|
        check_allowed_field(:filters, column)
      end
    end
  end

  def check_allowed_field(kind, field, extra_columns = {})
    table, column = field.values_at(TABLE, COLUMN)
    if !valid_column?(table, column, extra_columns)
      errors.add(kind, "#{table}.#{column} n’est pas une colonne permise")
    end
  end

  def check_filters_max_length
    individual_filters = filters.values.flatten.filter { |f| f.is_a?(Hash) }
    individual_filters.each do |filter|
      if filter['value']&.length.to_i > FILTERS_VALUE_MAX_LENGTH
        errors.add(:filters, :too_long)
      end
    end
  end

  def field_hash(label, table, column)
    {
      'label' => label,
      TABLE => table,
      COLUMN => column
    }
  end

  def valid_column?(table, column, extra_columns = {})
    valid_columns_for_table(table).include?(column) ||
      extra_columns[table]&.include?(column)
  end

  def valid_columns_for_table(table)
    @column_whitelist ||= fields
      .group_by { |field| field[TABLE] }
      .transform_values { |fields| Set.new(fields.pluck(COLUMN)) }

    @column_whitelist[table] || []
  end

  def self.sanitized_column(association, column)
    table = if association == 'self'
      Dossier.table_name
    elsif (association_reflection = Dossier.reflect_on_association(association))
      association_reflection.klass.table_name
    else
      # Allow filtering on a joined table alias (which doesn’t exist
      # in the ActiveRecord domain).
      association
    end

    [table, column]
      .map { |name| ActiveRecord::Base.connection.quote_column_name(name) }
      .join('.')
  end

  def assert_supported_column(table, column)
    if table == 'followers_instructeurs' && column != 'email'
      raise ArgumentError, 'Table `followers_instructeurs` only supports the `email` column.'
    end
  end
end
