module UsersHelper
  def external_tools_list
    tools = Rails.cache.fetch('external_tools_list', expires_in: 1.hour) do
      LinkedData::Client::Models::ExternalTool.all
        .sort_by { |tool| tool.created.to_s }
        .map { |tool| { id: tool.id.to_s, name: tool.name, label: tool.title, url: tool.homepage.to_s } }
    end
    tools || []
  end

  def external_tool(tool_name)
    external_tools_list.find { |tool| tool[:name].eql?(tool_name.to_s) }
  end
end
