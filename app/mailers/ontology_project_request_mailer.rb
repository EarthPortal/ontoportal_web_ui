class OntologyProjectRequestMailer < ApplicationMailer
  def project_access_request(project:, ontology:, user:, action:, recipients:)
    @project = project.is_a?(Hash) ? OpenStruct.new(project) : project
    @ontology = ontology.is_a?(Hash) ? OpenStruct.new(ontology) : ontology
    @user = user.is_a?(Hash) ? OpenStruct.new(user) : user
    @action = action
    @portal_url = $UI_URL
    
    direction = action == 'add' ? 'to' : 'from'
    
    mail(
      to: recipients,
      subject: I18n.t('mailers.ontology_project_request.subject', 
                     project: @project.name || @project.acronym, 
                     ontology: @ontology.acronym,
                     action: @action.capitalize,
                     direction: direction)
    )
  end
end