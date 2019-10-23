module NewAdministrateur
  class GroupeInstructeursController < AdministrateurController
    ITEMS_PER_PAGE = 25

    def index
      @procedure = procedure

      @groupes_instructeurs = paginated_groupe_instructeurs
    end

    def show
      @procedure = procedure
      @groupe_instructeur = groupe_instructeur
      @instructeurs = groupe_instructeur
        .instructeurs
        .page(params[:page])
        .per(ITEMS_PER_PAGE)
        .order(:email)
    end

    def create
      @groupe_instructeur = procedure
        .groupe_instructeurs
        .new(label: label, instructeurs: [current_administrateur.instructeur])

      if @groupe_instructeur.save
        redirect_to procedure_groupe_instructeur_path(procedure, @groupe_instructeur),
          notice: "Le groupe d’instructeurs « #{label} » a été créé."
      else
        @procedure = procedure
        @groupes_instructeurs = paginated_groupe_instructeurs

        flash[:alert] = "le nom « #{label} » est déjà pris par un autre groupe."
        render :index
      end
    end

    private

    def procedure
      current_administrateur
        .procedures
        .includes(:groupe_instructeurs)
        .find(params[:procedure_id])
    end

    def groupe_instructeur
      procedure.groupe_instructeurs.find(params[:id])
    end

    def label
      params[:groupe_instructeur][:label]
    end

    def paginated_groupe_instructeurs
      procedure
        .groupe_instructeurs
        .page(params[:page])
        .per(ITEMS_PER_PAGE)
        .order(:label)
    end
  end
end