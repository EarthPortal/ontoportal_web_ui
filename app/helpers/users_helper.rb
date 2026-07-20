module UsersHelper
  def external_tools_list
    tools = Rails.cache.fetch('external_tools_list', expires_in: 1.hour) do
      Array(LinkedData::Client::HTTP.get('/external_tools')).map do |tool|
        { name: tool.name, label: tool.title, url: tool.homepage.to_s, type: tool.toolType }
      end
    end
    tools || []
  end

  def external_tool(tool_name)
    external_tools_list.find { |tool| tool[:name].eql?(tool_name.to_s) }
  end

  def user_external_tool_apikey(user, tool_name)
    Array(user.externalTools).find { |tool| tool.toolName.eql?(tool_name) }&.apikey
  end
end
