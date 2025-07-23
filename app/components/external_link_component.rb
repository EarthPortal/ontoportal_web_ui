class ExternalLinkComponent < ViewComponent::Base
  def initialize(url:, text: nil)
    @url = url
    @text = text || url
  end

  attr_reader :url, :text
end