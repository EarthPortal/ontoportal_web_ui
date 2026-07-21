module ExternalTools
  # Connection recipe for OpenTheso instances:
  # 1. resolve the portal acronym to the thesaurus id (persistent name)
  # 2. request a temporary SSO token with the user API key
  class OpenthesoConnector

    def initialize(tool)
      @tool = tool
      @base_url = tool[:url].to_s.chomp('/')
    end

    def connect(api_key:, acronym:, concept_id: nil)
      idt = resolve_thesaurus(acronym)
      if idt.blank?
        return { error: I18n.t('ontologies.external_tool_resolve_failed', tool: @tool[:label]), status: :not_found }
      end

      data = request_sso_token(api_key, idt, concept_id)
      if data && data['redirectUrl']
        { redirect_url: "#{@base_url}#{data['redirectUrl']}" }
      else
        { error: error_message(data), status: :unprocessable_entity }
      end
    end

    private

    def error_message(data)
      case data && data['errorCode']
      when 'API_KEY_INVALID', 'API_KEY_MISSING'
        I18n.t('ontologies.external_tool_invalid_apikey', tool: @tool[:label])
      else
        I18n.t('ontologies.external_tool_connection_failed', tool: @tool[:label])
      end
    end

    def resolve_thesaurus(acronym)
      uri = URI("#{@base_url}/openapi/v1/thesaurus-resolve/#{acronym.to_s.downcase}")
      response = Net::HTTP.get_response(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)['idTheso']
    end

    def request_sso_token(api_key, idt, idc)
      uri = URI("#{@base_url}/api/v2/auth/token")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'

      request = Net::HTTP::Post.new(uri)
      request['X-API-Key'] = api_key
      request['Content-Type'] = 'application/json'
      request.body = { idc: idc.to_s, idt: idt }.to_json

      response = http.request(request)
      JSON.parse(response.body)
    end
  end
end
