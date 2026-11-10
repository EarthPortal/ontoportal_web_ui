module SubmissionUpdater
  extend ActiveSupport::Concern

  def submission_from_params(new_submission_hash)
    convert_values_to_types(new_submission_hash)
    LinkedData::Client::Models::OntologySubmission.new(values: submission_params(new_submission_hash))
  end
  def save_submission(new_submission_hash)
    @submission = submission_from_params(new_submission_hash)

    update_ontology_summary_only
    @submission.save(cache_refresh_all: false)
  end

  def update_submission(new_submission_hash, submission_id , ontology = nil)

    convert_values_to_types(new_submission_hash)

    @ontology = ontology || LinkedData::Client::Models::Ontology.find_by_acronym(new_submission_hash[:ontology]).first
    new_submission_hash.delete(:ontology)

    @submission = @ontology.explore.submissions({ include: 'all' }, submission_id)

    new_values = new_submission_hash
    new_values.each do |key, values|
      @submission.send("#{key}=", values)
    rescue StandardError
      next
    end

    update_ontology_summary_only
    [@submission, @submission.update(values: new_values, cache_refresh_all: false)]
  end

  # Fields that only the interface requires (SubmissionInputsHelper::INTERFACE_REQUIRED_*_ATTRIBUTES).
  # The API does not require them, so the ontologies saved before this rule stay valid.
  # Both checks return the errors in the same shape as the API ones, e.g. { hasLicense: { existence: '...' } }, or {}

  # Submission form (new ontology or new version): each of these fields must be filled
  def interface_required_errors(submission_values, ontology_values)
    interface_required_values(submission_values, ontology_values).each_with_object({}) do |(attr, value), errors|
      errors[attr.to_sym] = interface_required_message(attr) if interface_blank?(value)
    end
  end

  # Edit mode: a saved value can not be erased, but a field that was already empty does not block the save,
  # so the existing ontologies that miss these fields can still be edited.
  # Only the fields sent by the form are checked (the Edit form only sends the fields of the opened tabs).
  def interface_erased_errors(submission_values, ontology_values, saved_submission, saved_ontology)
    sent_values = interface_required_values(submission_values, ontology_values, sent_only: true)
    sent_values.each_with_object({}) do |(attr, value), errors|
      saved = SubmissionInputsHelper::INTERFACE_REQUIRED_SUBMISSION_ATTRIBUTES.include?(attr) ? saved_submission : saved_ontology
      next unless interface_blank?(value) && !interface_blank?(saved&.send(attr))

      errors[attr.to_sym] = interface_required_message(attr)
    end
  end

  # { attribute => value sent by the form } for the fields required by the interface
  #   sent_only: keep only the fields present in the form
  def interface_required_values(submission_values, ontology_values, sent_only: false)
    fields = [[SubmissionInputsHelper::INTERFACE_REQUIRED_SUBMISSION_ATTRIBUTES, submission_values || {}],
              [interface_required_ontology_attributes, ontology_values || {}]]

    fields.each_with_object({}) do |(attributes, values), result|
      attributes.each do |attr|
        next if sent_only && !values.key?(attr)

        result[attr] = values[attr]
      end
    end
  end

  # When the portal has no category (new installation, local API), the categories can not be required
  def interface_required_ontology_attributes
    attributes = SubmissionInputsHelper::INTERFACE_REQUIRED_ONTOLOGY_ATTRIBUTES
    return attributes unless attributes.include?('hasDomain')

    categories = LinkedData::Client::Models::Category.all(display_links: false, display_context: false)
    Array(categories).empty? ? attributes - ['hasDomain'] : attributes
  end

  # Also true for the empty rows sent by the list inputs, e.g. hasCreator: { '0' => { 'id' => '' } }
  # or hasDomain: ['']
  def interface_blank?(value)
    case value
    when Hash, ActionController::Parameters
      value.values.all? { |v| interface_blank?(v) }
    when Array
      value.all? { |v| interface_blank?(v) }
    else
      value.blank?
    end
  end

  def interface_required_message(attr)
    { existence: t("submissions.interface_required.#{attr}") }
  end

  def add_ontologies_to_object(ontologies,object)
    ontologies.each do |ont|
      next if object.ontologies.include?(ont)
      ontology = LinkedData::Client::Models::Ontology.find(ont)
      if object.type.match(/\/([^\/]+)$/)[1] == 'Group'
        ontology.group.push(object.id)
      else
        ontology.hasDomain.push(object.id)
      end
      ontology.update
    end
  end

  def delete_ontologies_from_object(new_ontologies,old_ontologies,object)
    new_ontologies = [] if new_ontologies.nil?
    ontologies = old_ontologies - new_ontologies
    ontologies.each do |ont|
      ontology = LinkedData::Client::Models::Ontology.find(ont)
      if object.type.match(/\/([^\/]+)$/)[1] == 'Group'
        ontology.group.delete(object.id)
      else
        ontology.hasDomain.delete(object.id)
      end
      ontology.update
    end
  end

  private

  def update_ontology_summary_only(is_remote = @submission.isRemote)
    if is_remote && @ontology.summaryOnly != is_remote.eql?('3')
      @ontology.update(values: {summaryOnly: is_remote.eql?('3')}, cache_refresh_all: false)
    end
  end

  def convert_values_to_types(new_submission_hash)
    unless new_submission_hash[:contact].nil?
      new_submission_hash[:contact] = new_submission_hash[:contact].values unless new_submission_hash[:contact].is_a?(Array)
      new_submission_hash[:contact].delete_if { |c| c[:name].empty? || c[:email].empty? }
    end

    # Convert metadata that needs to be integer to int
    submission_metadata.map do |hash|
      if hash["enforce"].include?("integer")
        if !new_submission_hash[hash["attribute"]].nil? && !new_submission_hash[hash["attribute"]].eql?("")
          new_submission_hash[hash["attribute"].to_s.to_sym] = Integer(new_submission_hash[hash["attribute"].to_s.to_sym])
        end
      end
      if hash["enforce"].include?("boolean") && !new_submission_hash[hash["attribute"]].nil?
        if new_submission_hash[hash["attribute"]].eql?("true")
          new_submission_hash[hash["attribute"].to_s.to_sym] = true
        elsif new_submission_hash[hash["attribute"]].eql?("false")
          new_submission_hash[hash["attribute"].to_s.to_sym] = false
        else
          new_submission_hash[hash["attribute"].to_s.to_sym] = nil
        end
      end
    end
  end


  def submission_params(params)
    attributes = [
      :ontology,
      :description,
      :hasOntologyLanguage,
      :prefLabelProperty,
      :synonymProperty,
      :definitionProperty,
      :authorProperty,
      :obsoleteProperty,
      :obsoleteParent,
      :version,
      :status,
      :released,
      :isRemote,
      :pullLocation,
      :filePath,
      { contact: [:name, :email] },
      :homepage,
      :documentation,
      :publication,
      {copyrightHolder: {}} # TODO add automatically no list Agents
    ]

    submission_metadata.each do |m|
      m_attr = m["attribute"].to_sym
      m_attr =  Array(m["enforce"]).include?("list") ? [{ m_attr => {} }, { m_attr => []}] : m_attr
      attributes << m_attr
    end
    p = params.permit(attributes.uniq)
    # the location radio buttons only hide the other inputs, their values are still submitted:
    # keep only the value matching the selected location type ('0' local file, '1' pull URL, '3' metadata only)
    unless p['isRemote'].nil?
      p['pullLocation'] = '' unless p['isRemote'].eql?('1')
      p.delete('filePath') unless p['isRemote'].eql?('0')
    end
    p = p.to_h.transform_values do |value|
      if value.is_a?(Hash)
        value.values.map { |v| normalize(v) }.reject { |v| v.respond_to?(:empty?) && v.empty? }
      else
        normalize(value)
      end
    end

    if p["copyrightHolder"]&.first&.include?("id") # TODO automatize
      p["copyrightHolder"] = p["copyrightHolder"].first["id"]
    elsif p["copyrightHolder"]
      p["copyrightHolder"] = ''
    end


    submission_metadata.each do |m|
      m_attr = m['attribute'].to_sym
      if p[m_attr] && m['enforce'].include?('list')
        p[m_attr] = Array(p[m_attr]) unless p[m_attr].is_a?(Array)
        p[m_attr] = p[m_attr].map { |x| x.is_a?(Hash) ? x.values.reject(&:empty?) : x.reject(&:empty?) }.flatten.uniq if m['enforce'].include?('Agent')
      end
    end

    p
  end

  # this function will strip the values of all the types to ensure no spaces are kept in the user input
  def normalize(value)
    case value
    when String
      value.strip
    when Array
      value.map { |el| normalize(el) }.reject { |el| el.respond_to?(:empty?) && el.empty? }
    when Hash
      value.transform_values { |v| normalize(v) }.reject { |_, v| v.respond_to?(:empty?) && v.empty? }
    else
      value
    end
  end

end
