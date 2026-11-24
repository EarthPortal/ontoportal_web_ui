class RecommenderController < ApplicationController
  layout :determine_layout
  include ApplicationHelper, FederationHelper

  def index
    @text = params[:text]
    @results_table_header = [t('recommender.results_table.ontology'), t('recommender.results_table.final_score'),
                             t('recommender.results_table.coverage_score'), t('recommender.results_table.acceptance_score'),
                             t('recommender.results_table.detail_score'), t('recommender.results_table.specialization_score'),
                             t('recommender.results_table.annotations')]

    @advanced_options_open = false
    if params[:max_elements_set]
      @not_valid_max_num_set = (params[:max_elements_set] < '2') || (params[:max_elements_set] > '4')
    end
    return if params[:input].nil? || params[:input].empty? || @not_valid_max_num_set

    @advanced_options_open = !recommender_params_empty?
    @results = []
    api_params = {
      input: params[:input],
      ontologies: params[:ontologies],
      max_elements_set: params[:max_elements_set],
      input_type: params[:input_type],
      output_type: params[:output_type],
      wc: params[:wc],
      wa: params[:wa],
      wd: params[:wd],
      ws: params[:ws]
    }

    set_federated_portals
    @ontologies = LinkedData::Client::Models::Ontology.all({ include_views: true }).map { |o| [o.id.to_s, o] }.to_h

    filtered_params = {}
    request_portals.each do |portal|
      name = portal.downcase.eql?(portal_name.downcase) ? '' : portal.downcase
      filtered_params[name] = api_params.dup
      api_params[:ontologies] ||= ''
      filtered_params[name][:ontologies] = api_params[:ontologies].split(',').select do |ont|
        filtered_ontologies = @ontologies.values.select { |o| o.acronym == ont.split('/').last }
        next false if filtered_ontologies.empty?

        filtered_ontologies.any? do |ontology|
          config = ontology_portal_config(ontology.id)&.last || internal_portal_config(ontology.id) || {}
          next false if config.blank?

          portal.downcase.eql?(config[:name].downcase)
        end
      end.map { |x| x.split('/').last }.uniq.join(',')
    end
    filtered_params.select! { |_k, v| !v[:ontologies].blank? } unless params[:ontologies].blank?

    recommendations = LinkedData::Client::Models::Class.federated_get(filtered_params) do |url|
      "#{url}/recommender"
    end

    recommendations, @federation_errors = recommendations.partition { |x| !federation_error?(x) }
    @json_link = "#{rest_url}/recommender"
    @json_link += "?#{api_params.to_query}"
    recommendations.each do |recommendation|
      row = {
        ontologies: recommendation_ontologies(recommendation),
        final_score: percentage(recommendation.evaluationScore),
        coverage_score: percentage(recommendation.coverageResult&.normalizedScore),
        acceptance_score: percentage(recommendation.acceptanceResult&.normalizedScore),
        details_score: percentage(recommendation.detailResult&.normalizedScore),
        specialization_score: percentage(recommendation.specializationResult&.normalizedScore),
        annotations: recommendation_annotations(recommendation),
        highlighted: false
      }
      @results.push(row)
      @results.max_by { |element| element[:final_score] }[:highlighted] = true
    end

    @results = merge_recommender_results(@results)
  end

  def recommendation_ontologies(recommendation)
    Array(recommendation.ontologies).map do |ont|
      ont = @ontologies[ont.id] || ont
      { acronym: ont.acronym, name: ont.name, link: ont.id, id: ont.id }
    end
  end

  def recommendation_annotations(recommendation)
    Array(recommendation.coverageResult&.annotations).map { |annotation| { text: annotation.text, link: annotation.annotatedClass.links['ui'] } }
  end

  def percentage(string)
    result = string.to_f * 100
    result.round(1).to_s
  end

  def recommender_params_empty?
    (params[:wc].eql?('0.55') && params[:wa].eql?('0.15') && params[:wd].eql?('0.15') && params[:ws].eql?('0.15') && params[:max_elements_set].eql?('3') && params[:ontologies].nil?)
  end

  def merge_recommender_results(results)
    return unless results

    results.group_by { |x| x[:ontologies].first[:acronym] }.map do |_, x|
      ontologies = x.map { |y| y[:ontologies] }.flatten
      canonical_ontology = canonical_ontology(ontologies)
      out = x.select { |y| y[:ontologies].find { |z| z[:id].eql?(canonical_ontology[:id]) } }.first
      out[:sources] = ontologies
      out
    end
  end

end
