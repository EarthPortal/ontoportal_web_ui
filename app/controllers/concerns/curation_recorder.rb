# Curation of a submission (rule of the EarthPortal team, 2026-11): every save of the Edit page records
# who curated the metadata and when, i.e. the person who clicked Save and the date of this save, with or without changes.
# This person is a site administrator (e.g. from the Curate button of the Curation tab of the administration console)
# or an administrator of the ontology (even a librarian): the API only lets them update the submission.
# The previous curation is replaced (one curator, one date) and is never cancelled: the next save replaces it.
# The values are sent with the metadata, in the same update: if the save fails, no curation is recorded.
# Not counted: the "Metadata administration" tool of the administration console (bulk edit and its inline edit).
module CurationRecorder
  extend ActiveSupport::Concern

  CURATION_ATTRIBUTES = %w[curatedOn curatedBy].freeze

  # The metadata sent by the Edit form, with the curation values set by the system in place of the sent ones.
  # When no Agent can be found nor created for the current user, the curation is left unchanged.
  def with_curation_values(submission_values)
    submission_values.except(*CURATION_ATTRIBUTES).merge(curation_values)
  end

  # Save of the Edit form when only ontology fields were sent (e.g. only "Name" chosen in the metadata selector):
  # the submission is not updated with the metadata, so the curation is saved alone.
  def record_curation(acronym, submission_id, ontology)
    values = curation_values
    return if values.empty?

    _submission, response = update_submission(ActiveSupport::HashWithIndifferentAccess.new(values.merge('ontology' => acronym)),
                                              submission_id, ontology)
    Rails.logger.warn("Curation of #{acronym} not saved: #{response_errors(response)}") if response_error?(response)
  end

  private

  # { 'curatedOn' => [date of today], 'curatedBy' => [Agent of the current user] }, or {} when there is no Agent
  def curation_values
    agent_id = current_user_agent_id
    return {} unless agent_id

    { 'curatedOn' => [Date.current.to_s], 'curatedBy' => [agent_id] }
  end

  # The Agent with the email of the account of the current user, created (as a person) when there is none
  def current_user_agent_id
    user = session[:user]
    email = user.respond_to?(:email) ? user.email.to_s.strip : ''
    return nil if email.empty?

    agent = find_agent_by_email(email) || create_user_agent(user, email)
    agent&.id
  rescue StandardError => e
    Rails.logger.warn("Curation: no Agent for the current user: #{e.message}")
    nil
  end

  # The API filters the Agents by email (exact value); the email is compared again here, without the case
  def find_agent_by_email(email)
    agents = LinkedData::Client::Models::Agent.all(email: email, display: 'name,email', invalidate_cache: true,
                                                    display_links: false, display_context: false)
    Array(agents).find { |agent| agent.respond_to?(:email) && agent.email.to_s.strip.casecmp?(email) }
  end

  # Same values as an Agent created from the Agents page (AgentsController#save_agent): the creator is the user
  def create_user_agent(user, email)
    value = ->(attr) { user.respond_to?(attr) ? user.send(attr).to_s.strip : '' }
    name = [value.call(:firstName), value.call(:lastName)].reject(&:empty?).join(' ')
    name = value.call(:username) if name.empty?
    agent = LinkedData::Client::Models::Agent.new(values: { agentType: 'person', name: name, email: email, creator: user.id })
    saved = agent.save
    if saved.nil? || (saved.respond_to?(:errors) && saved.errors)
      Rails.logger.warn("Curation: the Agent of the current user could not be created: #{saved&.errors}")
      return nil
    end

    saved
  end
end
