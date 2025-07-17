class ProjectChipComponent < ViewComponent::Base
  def initialize(project:)
    @project = project
  end

  private

  attr_reader :project

  def project_name
    return '' if project.nil?
    
    if project.is_a?(String)
      project
    else
      project.respond_to?(:acronym) ? (project.acronym || project.name) : project.name
    end
  end

  def project_acronym
    return nil if project.nil? || project.is_a?(String)
    
    project.respond_to?(:acronym) ? project.acronym : nil
  end

  def project_url
    return nil if project.nil? || project.is_a?(String) || project_acronym.nil?
    
    "/projects/#{project_acronym}"
  end

  def project_logo
    return nil if project.nil? || project.is_a?(String)
    
    project.respond_to?(:logo) ? project.logo : nil
  end

  def has_logo?
    !project_logo.nil? && !project_logo.to_s.empty?
  end

  def project_icon_or_logo
    # if has_logo?
    #   image_tag(project_logo, class: 'project-logo-icon', alt: project_name)
    # else
    inline_svg_tag('icons/project.svg', class: 'project-type-icon')
    # end
  end

  def chip_type
    project_url ? "clickable" : "static"
  end

  def project_tooltip
    return nil if project.is_a?(String) || project.nil?
    
    generate_project_tooltip(
      project_icon_or_logo,
      project.name
    )
  end

  def generate_project_tooltip(icon, name)
    content_tag(:div, class: 'project-container-simple') do
      content_tag(:div, icon, class: 'project-circle-simple') +
      content_tag(:div, class: 'project-info-simple') do
        content_tag(:div, name, class: 'project-name-simple')
      end
    end
  end
end