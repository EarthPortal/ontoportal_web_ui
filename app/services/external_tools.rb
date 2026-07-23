# External editors connectors.
# Each connector implements the connection recipe of one registered tool and exposes:
#   connect(api_key:, acronym:, concept_id:) -> { redirect_url: } or { error:, status: }
# To support a new tool: add a connector class and register it in CONNECTORS,
# keyed by the tool's `name` in the registry (GET /external_tools).
module ExternalTools
  CONNECTORS = { 'opentheso' => OpenthesoConnector }.freeze

  def self.connector_for(tool)
    klass = CONNECTORS[tool[:name].to_s]
    klass&.new(tool)
  end
end
