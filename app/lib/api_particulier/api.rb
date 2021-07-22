class APIParticulier::API
  include APIParticulier::Entities::Caf
  include APIParticulier::Error

  INTROSPECT_RESOURCE_NAME = "introspect"
  COMPOSITION_FAMILIALE_RESOURCE_NAME = "v2/composition-familiale"

  TIMEOUT = 20

  def self.introspect
    response = get(INTROSPECT_RESOURCE_NAME)
    APIParticulier::Entities::Introspection.new(response)
  end

  def self.composition_familiale(numero_d_allocataire, code_postal)
    response = get(COMPOSITION_FAMILIALE_RESOURCE_NAME,
                   numeroAllocataire: numero_d_allocataire,
                   codePostal: code_postal)

    Famille.new(response)
  end

  private

  def self.get(resource_name, params = {})
    url = [API_PARTICULIER_URL, resource_name].join("/")

    response = Typhoeus.get(url,
      headers: { accept: "application/json", "X-API-Key": token },
      params: params,
      timeout: TIMEOUT)

    if response.success?
      JSON.parse(response.body, symbolize_names: true)
    elsif response.timed_out?
      raise TimedOut.new(response)
    elsif response.code == 400
      raise BadFormatRequest.new(response)
    elsif response.code == 401
      raise Unauthorized.new(response)
    elsif response.code == 404
      raise NotFound.new(response)
    elsif response.code == 502
      raise	BadGateway.new(response)
    elsif response.code == 503
      raise ServiceUnavailable.new(response)
    else
      raise RequestFailed.new(response)
    end
  end

  def self.token
    Rails.application.secrets.api_entreprise[:token]
  end
end
