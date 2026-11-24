module RecommenderHelper

  def edit_recommender_button
    regular_button('edit-recommender', t('recommender.edit'), variant: 'primary') do |btn|
      btn.icon_left do
        inline_svg_tag "edit.svg"
      end
    end
  end

  def recommendation_ontology_link(recommendation)
    ontology = recommendation[:ontologies].first
    other_sources = Array(recommendation[:sources]).map { |s| s[:id] }
    config = ontology_portal_config(ontology[:id])&.last || internal_portal_config(ontology[:id]) || {}
    label = "#{ontology[:name]}(#{ontology[:acronym]})"
    content_tag :div, class: 'd-flex align-items-center justify-content-between' do
      out = link_to federation_link(id: ontology[:id], title: label, color: config[:color], name: config[:name]), ontoportal_ui_link(ontology[:id])
      out += federation_buttons(other_sources)
      out
    end
  end

end
