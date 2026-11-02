class ProjectsController < OrganizationRecordsController
     private

     def model_class
          Project
     end

     def parent_field
          :team_id
     end

     def parent_options
          Team.where(id: team_ids_for_choices).order(:name)
     end

     def team_id_for(project)
          project.team_id
     end
end
