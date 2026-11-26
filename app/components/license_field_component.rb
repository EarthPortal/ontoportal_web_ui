# frozen_string_literal: true

class LicenseFieldComponent < ViewComponent::Base

  def initialize(value: )
    super
    @value = value
  end

  # Name of the license when it is one of the licenses proposed by the portal (the enforcedValues of hasLicense
  # given by the API, e.g. the SPDX licenses); nil for the other licenses
  def listed_license_name
    licenses = helpers.attr_metadata('hasLicense')&.dig('enforcedValues') || {}
    licenses[@value.to_s]
  rescue StandardError
    nil
  end

end
