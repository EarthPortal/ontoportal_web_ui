# Curation tab of the administration console: every ontology (views, metadata-only and private ones included)
# with the Recommended fields of its latest submission that are still empty, and its current curation (curatedBy / curatedOn)
class Admin::CurationController < ApplicationController
  layout :determine_layout
  before_action :authorize_admin

  ONTOLOGY_ATTRIBUTES = %w[acronym name viewOf summaryOnly viewingRestriction].freeze
  SUBMISSION_ATTRIBUTES = (%w[ontology submissionId curatedBy curatedOn] +
                           SubmissionInputsHelper::RECOMMENDED_ATTRIBUTES).freeze

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

  private

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
