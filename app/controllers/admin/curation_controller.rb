# Curation tab of the administration console: every ontology (views, metadata-only and private ones included)
# with the Recommended fields of its latest submission that are still empty, and its current curation (curatedBy / curatedOn)
class Admin::CurationController < ApplicationController
  layout :determine_layout
  before_action :authorize_admin

  ONTOLOGY_ATTRIBUTES = %w[acronym name viewOf summaryOnly viewingRestriction].freeze
  SUBMISSION_ATTRIBUTES = (%w[ontology submissionId curatedBy curatedOn] +
                           SubmissionInputsHelper::RECOMMENDED_ATTRIBUTES).freeze

  # Same tabs, in the same order, as the Edit page (SubmissionsController#edit)
  EDIT_TABS = ['general', 'description', 'dates', 'licensing', 'agents', 'links', 'media', 'community', 'usage',
               'relations', 'content', 'methodology', 'object description properties'].freeze
  # Never asked to the authors: the curation fields (filled in by the system, CurationRecorder), the portal links
  # (greyed for the authors), and the fields the Edit page changes with other inputs
  # (pullLocation: the location of the file, hasDomain: the categories of the ontology)
  NOT_ASKED_ATTRIBUTES = (CurationRecorder::CURATION_ATTRIBUTES + SubmissionInputsHelper::PORTAL_GENERATED_ATTRIBUTES +
                          %w[pullLocation hasDomain]).freeze

  def index
    ontologies = LinkedData::Client::Models::Ontology.all(include: ONTOLOGY_ATTRIBUTES.join(','), also_include_views: true,
                                                          display_links: false, display_context: false)
    ontologies = Array(ontologies).reject(&:errors)

    # The latest submission of each ontology, whatever its status: a new deposit (not processed yet)
    # and a metadata-only entry (its processing always ends in error) are listed too.
    # It is the submission opened by the Edit button of the ontology page.
    submissions = LinkedData::Client::Models::OntologySubmission.all(include: SUBMISSION_ATTRIBUTES.join(','), include_status: 'ANY',
                                                                     also_include_views: true, display_links: false, display_context: false)
    submissions = Array(submissions).map { |s| s[:ontology] ? [s[:ontology][:id], s] : nil }.compact.to_h

    @recommended_total = SubmissionInputsHelper::RECOMMENDED_ATTRIBUTES.size
    # Most empty Recommended fields first, the ontologies without submission last
    @rows = ontologies.map { |ontology| curation_row(ontology, submissions[ontology.id]) }
                      .sort_by { |row| [-(row[:recommended_empty] || -1), row[:acronym].to_s] }

    # The numbers at the top of the tab
    @kpis = {
      entries: @rows.size,
      recommended_empty: @rows.sum { |row| row[:recommended_empty].to_i },
      curated: @rows.count { |row| row[:curated] }
    }
  end

  # "Ask the author" window, step 1: the empty fields of the submission opened by the Curate button
  # (Recommended or not), by tab of the Edit page. The filled fields are checked with the Curate button.
  # fields[]: the fields ticked before going back from step 2
  def ask
    load_ask_fields
    @ticked = Array(params[:fields]).map(&:to_s)
    render 'ask', layout: false
  end

  # Step 2: the email to the administrators of the ontology, pre-filled (in English) with the ticked fields
  def ask_mail
    load_ask_mail
    @subject, @body = default_ask_mail
    @error = t('admin.curation.ask_no_field') if @fields.empty?
    render 'ask_mail', layout: false
  end

  # Sends the email written by the administrator, like the processing emails of the portal:
  # from the support address to the administrators of the ontology, with a copy to the support.
  # Sent now (not in the background) to tell the administrator when it fails.
  def ask_send
    load_ask_mail
    @subject = params[:subject].to_s.strip
    @body = params[:body].to_s.strip
    @error = ask_mail_error
    if @error.nil?
      CurationRequestMailer.ask_author(to: @recipients.map { |admin| admin[:email] }, cc: @support, from: @sender,
                                       subject: @subject, body: @body).deliver_now
      return render 'ask_sent', layout: false
    end

    render 'ask_mail', layout: false, status: :unprocessable_entity
  rescue StandardError => e
    @error = t('admin.curation.ask_send_failed', message: e.message)
    render 'ask_mail', layout: false, status: :unprocessable_entity
  end

  private

  def load_ask_fields
    @acronym = params[:acronym]
    @submission_id = params[:submission_id].to_s
    @ontology = begin
      LinkedData::Client::Models::Ontology.find_by_acronym(@acronym).first
    rescue StandardError
      nil
    end
    submission = ask_submission(@ontology, @submission_id)
    # nil when the submission can not be read
    @fields_by_tab = submission && empty_fields_by_tab(submission)
  end

  # The ticked fields that are still empty and can be asked (the list of the window, in the order of the Edit tabs),
  # the administrators of the ontology, and the addresses of the email
  def load_ask_mail
    load_ask_fields
    ticked = Array(params[:fields]).map(&:to_s)
    @fields = Array(@fields_by_tab).flat_map(&:last).select { |field| ticked.include?(field[:attribute]) }
    @recipients = ontology_admins(@ontology)
    @support = $SUPPORT_EMAIL.to_s.strip.presence
    # Same sender as the processing emails: the support address of the portal (else the sender of the other emails of the site)
    @sender = @support || ApplicationMailer.default[:from]
  end

  def ask_submission(ontology, submission_id)
    return nil if ontology.nil? || submission_id.empty?

    submission = ontology.explore.submissions({ display: 'all' }, submission_id)
    submission.nil? || response_error?(submission) ? nil : submission
  rescue StandardError
    nil
  end

  # [{ username:, email: }] of the administrators of the ontology that have an email address
  def ontology_admins(ontology)
    Array(ontology&.administeredBy).filter_map do |user_id|
      user = LinkedData::Client::Models::User.find(user_id.to_s, include: 'username,email')
      email = user.respond_to?(:email) ? user.email.to_s.strip : ''
      { username: user.username, email: email } unless email.empty?
    rescue StandardError
      nil
    end
  end

  # Subject and text of the email, in English (the authors are not all French speakers); the administrator can change them.
  # The link opens the usual Edit page (all the tabs, with the Recommended badges)
  def default_ask_mail
    I18n.with_locale(:en) do
      values = { portal: helpers.portal_name, name: @ontology&.name.presence || @acronym, acronym: @acronym }
      fields = @fields.map { |field| t('admin.curation.ask_mail.field', label: field[:label], tab: field[:tab].humanize) }
      edit_url = "#{$UI_URL.to_s.chomp('/')}#{edit_ontology_submission_path(@acronym, @submission_id)}"
      [t('admin.curation.ask_mail.subject', **values),
       t('admin.curation.ask_mail.body', **values, fields: fields.join("\n"), edit_url: edit_url)]
    end
  end

  def ask_mail_error
    return t('admin.curation.ask_no_field') if @fields.empty?
    return t('admin.curation.ask_no_recipient', acronym: @acronym) if @recipients.empty?
    return t('admin.curation.ask_empty_mail') if @subject.empty? || @body.empty?

    nil
  end

  # [[tab, [{ attribute:, label:, recommended: }, ...]], ...] for the tabs with at least one empty field.
  # Empty: same rule as the Recommended badges of the Edit page (SubmissionInputsHelper#metadata_value_blank?).
  # Labels and tab names: the ones of the Edit page (labels of the API, tab names humanized)
  def empty_fields_by_tab(submission)
    fields = helpers.submission_metadata.filter_map do |metadata|
      attribute = metadata['attribute'].to_s
      next if NOT_ASKED_ATTRIBUTES.include?(attribute) || !EDIT_TABS.include?(metadata['category'])

      value = begin
        submission.send(attribute)
      rescue StandardError
        nil
      end
      next unless helpers.metadata_value_blank?(value)

      { attribute: attribute, tab: metadata['category'], label: metadata['label'].presence || attribute.humanize,
        recommended: SubmissionInputsHelper::RECOMMENDED_ATTRIBUTES.include?(attribute) }
    end
    EDIT_TABS.map { |tab| [tab, fields.select { |field| field[:tab] == tab }] }.reject { |_tab, list| list.empty? }
  end

  def curation_row(ontology, submission)
    curated_on = curation_dates(submission)
    curated_by = curation_agents(submission)
    {
      acronym: ontology.acronym,
      name: ontology.name,
      type: ontology_type(ontology),
      private: ontology.viewingRestriction.eql?('private'),
      submission_id: submission&.submissionId,
      # Same count as the sum of the tab counters of the Edit page (Recommended badges)
      recommended_empty: submission && helpers.recommended_empty_count(SubmissionInputsHelper::RECOMMENDED_ATTRIBUTES, submission),
      curated_on: curated_on,
      curated_by: curated_by,
      curated: curated_on.any? || curated_by.any?
    }
  end

  def ontology_type(ontology)
    if ontology.viewOf.present?
      :view
    elsif ontology.summaryOnly
      :metadata_only
    else
      :ontology
    end
  end

  # curatedOn is a list of dates in the API
  def curation_dates(submission)
    return [] unless submission

    Array(submission.curatedOn).map do |date|
      Date.parse(date.to_s).to_s
    rescue ArgumentError
      date.to_s
    end.reject(&:blank?)
  end

  # curatedBy is a list of Agents (persons or organizations)
  def curation_agents(submission)
    return [] unless submission

    Array(submission.curatedBy).map { |agent| agent_label(agent) }.reject(&:blank?)
  end

  def agent_label(agent)
    return agent.split('/').last if agent.is_a?(String)

    name = begin
      agent.name
    rescue StandardError
      nil
    end
    name.presence || agent.id.to_s.split('/').last
  end
end
