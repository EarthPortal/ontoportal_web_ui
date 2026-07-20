# External editors connectors.
# Each connector implements the connection recipe of one tool type and exposes:
#   connect(api_key:, acronym:, concept_id:) -> { redirect_url: } or { error:, status: }
# To support a new tool type: add a connector class and register it in CONNECTORS.
module ExternalTools
  def self.connector_for(tool)
    connectors = { 'opentheso' => OpenthesoConnector }
    klass = connectors[tool[:type].to_s]
    klass&.new(tool)
  end
end
