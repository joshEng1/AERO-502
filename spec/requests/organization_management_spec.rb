require "rails_helper"

# KAN-19 / scope S01 / UAT B1: teams contain subteams, subteams contain projects,
# and tasks belong to projects.
RSpec.describe "Organization management", type: :request do
     def create_team(name)
          post teams_path, params: { team: { name: name } }
          Team.find_by!(name: name)
     end

     def create_subteam(name, team)
          post subteams_path, params: { subteam: { name: name, team_id: team.id } }
          team.subteams.find_by!(name: name)
     end

     def create_project(name, subteam)
          post projects_path, params: { project: { name: name, team_id: subteam.team_id, subteam_ids: [ subteam.id ] } }
          subteam.projects.find_by!(name: name)
     end

     it "B1.1/B1.2: builds Team > Subteam > Project and shows the saved parents when reopened" do
          sign_in(users(:chief))

          team_a = create_team("Team A")
          project_a = create_project("Wing ribs", create_subteam("Wings", team_a))
          team_b = create_team("Team B")
          project_b = create_project("Landing gear", create_subteam("Gear", team_b))
          expect(response).to redirect_to(organization_path)

          get project_path(project_a)
          expect(response.parsed_body.at_css("[data-parents]").text.squish).to eq("Team A · Wings")

          get organization_path
          team_b_card = response.parsed_body.at_css("[data-team='#{team_b.id}']").text
          expect(team_b_card).to include("Gear", "Landing gear")
          expect(team_b_card).not_to include("Wing ribs")
          expect(project_b.reload.team).to eq(team_b)
     end

     it "B1.3: lets an officer add a second project to their subteam without duplicating it" do
          sign_in(users(:officer))

          expect { create_project("Tail section", subteams(:wing)) }.not_to change(Subteam, :count)
          expect(subteams(:wing).projects.map(&:name)).to contain_exactly("SAE AERO Design", "Archive Project", "Tail section")
     end

     it "B1.4/B1.8: refuses a missing name or parent, identifies the field and creates nothing" do
          sign_in(users(:chief))

          expect { post teams_path, params: { team: { name: "" } } }.not_to change(Team, :count)
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.at_css("#team_name_error").text).to include("Name can't be blank")

          expect { post subteams_path, params: { subteam: { name: "Wings", team_id: "" } } }.not_to change(Subteam, :count)
          expect(response.parsed_body.at_css("#subteam_team_error").text).to include("Team must exist")

          expect { post projects_path, params: { project: { name: "Ribs", team_id: "", subteam_ids: [] } } }.not_to change(Project, :count)
          expect(response.parsed_body.at_css("#project_team_error").text).to include("Team must exist")
     end

     it "B1.5/B1.8: keeps a new subteam under its team after refreshing and offers its projects in the task form" do
          sign_in(users(:chief))
          subteam = create_subteam("Propulsion", teams(:aerodynamics))
          create_project("Motor test", subteam)

          get organization_path
          card = response.parsed_body.at_css("[data-team='#{teams(:aerodynamics).id}']").text
          expect(card).to include("Propulsion", "Motor test")

          get new_task_path
          expect(response.parsed_body.css("#task_project_id option").map(&:text))
               .to include("Aerodynamics · Motor test")
     end

     it "B1.7: renames and archives records; archived ones leave everyday lists but their tasks and hours stay viewable" do
          sign_in(users(:chief))

          patch team_path(teams(:structures)), params: { team: { name: "Micro Class" } }
          patch subteam_path(subteams(:airframe)), params: { subteam: { name: "Fuselage" } }
          patch project_path(projects(:airframe_build)), params: { project: { name: "Spar build" } }
          expect([ teams(:structures), subteams(:airframe), projects(:airframe_build) ].map { |record| record.reload.name })
               .to eq([ "Micro Class", "Fuselage", "Spar build" ])

          patch archive_project_path(projects(:airframe_build))
          patch archive_subteam_path(subteams(:airframe))
          patch archive_team_path(teams(:structures))

          get new_task_path
          options = response.parsed_body.css("select option").map(&:text).join(" ")
          expect(options).not_to include("Micro Class", "Fuselage", "Spar build")

          get organization_path
          archived = response.parsed_body.at_css("[data-archived]")
          expect(archived.text).to include("Micro Class", "Fuselage", "Spar build")
          expect(archived.at_css("a[href='#{project_path(projects(:airframe_build))}']")).to be_present

          get project_path(projects(:airframe_build))
          record = response.parsed_body
          expect(record.at_css("[data-archived-notice]")).to be_present
          expect(record.at_css("[data-record-tasks]").text).to include("Verify spar dimensions", "1.5 hours")

          patch restore_team_path(teams(:structures))
          expect(teams(:structures).reload).not_to be_archived
     end

     it "B1.9: lets a Team A officer manage only Team A subteams and projects, including direct requests" do
          sign_in(users(:officer))

          create_subteam("Wind Tunnel", teams(:aerodynamics))
          patch subteam_path(subteams(:wing)), params: { subteam: { name: "Wing Design" } }
          patch project_path(projects(:aero)), params: { project: { name: "Wing build" } }
          expect([ subteams(:wing).reload.name, projects(:aero).reload.name ]).to eq([ "Wing Design", "Wing build" ])

          expect { post subteams_path, params: { subteam: { name: "Sneaky", team_id: teams(:structures).id } } }
               .not_to change(Subteam, :count)
          expect { post projects_path, params: { project: { name: "Sneaky", team_id: teams(:structures).id, subteam_ids: [ subteams(:airframe).id ] } } }
               .not_to change(Project, :count)
          patch subteam_path(subteams(:airframe)), params: { subteam: { name: "Hijacked" } }
          patch archive_project_path(projects(:airframe_build))
          expect(subteams(:airframe).reload.name).to eq("Airframe")
          expect(projects(:airframe_build).reload).not_to be_archived
          expect(response).to redirect_to(organization_path)

          expect { post teams_path, params: { team: { name: "New team" } } }.not_to change(Team, :count)
          get new_team_path
          expect(response).to redirect_to(organization_path)
          get project_path(projects(:airframe_build))
          expect(response).to redirect_to(organization_path)
     end

     it "groups each record's Rename and Archive actions in a Manage menu and shows counts per team" do
          sign_in(users(:chief))
          get organization_path

          card = response.parsed_body.at_css("[data-team='#{teams(:aerodynamics).id}']")
          expect(card.at_css(".org-team-header").text.squish).to include("1 subteam · 2 projects")
          menus = card.css("details.manage-menu")
          expect(menus.size).to eq(4)
          menus.each do |menu|
               expect(menu.at_css("summary").text.squish).to start_with("Manage")
               expect(menu.css("a, button").map { |control| control.text.strip }).to eq([ "Rename", "Archive" ])
          end
          expect(card.css("a.add-action").map(&:text).map(&:squish)).to eq([ "+ Add project", "+ Add subteam" ])
     end

     it "keeps a record's parent fixed after creation so its tasks stay consistent" do
          sign_in(users(:chief))
          patch project_path(projects(:aero)), params: { project: { subteam_id: subteams(:airframe).id } }
          patch subteam_path(subteams(:wing)), params: { subteam: { team_id: teams(:structures).id } }

          expect(projects(:aero).reload.subteams).to include(subteams(:wing))
          expect(subteams(:wing).reload.team).to eq(teams(:aerodynamics))
     end

     it "shows officers only their own team, offers only their subteams as parents, and gives members nothing" do
          sign_in(users(:officer))
          get organization_path
          expect(response.body).to include("Aerodynamics", "Wing Analysis")
          expect(response.body).not_to include("Airframe")
          get new_project_path
          expect(response.parsed_body.css("#project_team_id option").map(&:text))
               .to eq([ "Select a team", "Aerodynamics" ])
          get new_subteam_path
          expect(response.parsed_body.css("#subteam_team_id option").map(&:text)).to eq([ "Select a team", "Aerodynamics" ])

          sign_in(users(:member))
          [ organization_path, new_subteam_path, project_path(projects(:aero)) ].each do |path|
               get path
               expect(response).to redirect_to(root_path)
          end
     end

     it "opens the create, rename and record pages for each kind of record" do
          sign_in(users(:chief))

          [ new_team_path, new_subteam_path(team_id: teams(:aerodynamics).id), new_project_path(subteam_id: subteams(:wing).id),
            edit_team_path(teams(:aerodynamics)), edit_subteam_path(subteams(:wing)), edit_project_path(projects(:aero)),
            team_path(teams(:aerodynamics)), subteam_path(subteams(:wing)), project_path(projects(:aero)) ].each do |path|
               get path
               expect(response).to have_http_status(:ok)
          end
          patch team_path(teams(:aerodynamics)), params: { team: { name: "" } }
          expect(response).to have_http_status(:unprocessable_content)
     end

     it "lets the Chief Engineer place a person in a subteam of their team" do
          sign_in(users(:chief))

          patch user_path(users(:member)), params: { user: { subteam_id: subteams(:wing).id } }
          expect(users(:member).reload.subteam).to eq(subteams(:wing))

          patch user_path(users(:member)), params: { user: { subteam_id: subteams(:airframe).id } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("cannot change teams until incompatible active assignments are resolved")
     end

     it "seeds the SAE AERO classes, their subteams and starter projects" do
          expect { load Rails.root.join("db/seeds.rb") }.to output(/Seeded SAE AERO practice data/).to_stdout

          structure = %w[Regular Micro Advanced].to_h do |name|
               team = Team.find_by!(name: "#{name} Class")
               [ team.name, team.subteams.order(:name).map(&:name) ]
          end
          expect(structure).to eq(
               "Regular Class" => [ "Aerodynamics", "Structures" ],
               "Micro Class" => [ "Aerodynamics", "Structures" ],
               "Advanced Class" => [ "Aerodynamics", "Autonomous Systems", "Structures" ]
          )
          expect(Task.find_by!(title: "Wing load test", project: Project.find_by!(name: "Wing design")).subteams.order(:name).first.name).to eq("Aerodynamics")
     end
end
