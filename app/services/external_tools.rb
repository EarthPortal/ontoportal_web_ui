# external editors connectors

# each connector implements the connection logic for a specific external tool:
#   connect(api_key:, acronym:, concept_id:) -> { redirect_url: } 
# to support a new tool: add a connector class and register it in CONNECTORS
module ExternalTools
  CONNECTORS = { 'opentheso' => OpenthesoConnector }.freeze

  def self.connector_for(tool)
    klass = CONNECTORS[tool[:name].to_s]
    klass&.new(tool)
  end
end
