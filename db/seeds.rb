# Practice data matching SAE AERO's structure (approved scope S01): three
# independent classes (teams), their subteams, and team-owned projects.
# Subteam and project names are confirmed with the customer before
# production seeding.
structure = {
     "Regular Class" => {
          "Aerodynamics" => [ "Wing design" ],
          "Structures" => [ "Fuselage build" ]
     },
     "Micro Class" => {
          "Aerodynamics" => [ "Airfoil study" ],
          "Structures" => [ "Spar redesign" ]
     },
     "Advanced Class" => {
          "Aerodynamics" => [ "Control surfaces" ],
          "Structures" => [ "Payload bay" ],
          "Autonomous Systems" => [ "Flight controller" ]
     }
}
projects = {}
structure.each do |team_name, subteams|
     team = Team.find_or_create_by!(name: team_name)
     subteams.each do |subteam_name, project_names|
          subteam = Subteam.find_or_create_by!(team: team, name: subteam_name)
          project_names.each do |project_name|
               projects[[ team_name, subteam_name ]] = Project.find_or_create_by!(team: team, name: project_name)
          end
     end
end
regular_wing = projects.fetch([ "Regular Class", "Aerodynamics" ])
micro_spar = projects.fetch([ "Micro Class", "Structures" ])

password = ENV.fetch("DEMO_PASSWORD", "AeroSprint1!")

def seed_user(email, password, **attributes)
     user = User.find_or_initialize_by(email: email)
     user.update!(password: password, password_confirmation: password, **attributes)
     user
end

regular = regular_wing.team
micro = micro_spar.team
seed_user("chief@example.test", password, name: "Casey Chief", role: :chief_engineer, team: nil, subteam: nil)
officer_a = seed_user("officer.a@example.test", password, name: "Olivia Officer", role: :officer,
                      team: regular, subteam: regular.subteams.find_by!(name: "Aerodynamics"))
officer_b = seed_user("officer.b@example.test", password, name: "Owen Officer", role: :officer,
                      team: micro, subteam: micro.subteams.find_by!(name: "Structures"))
member_a = seed_user("member.a@example.test", password, name: "Morgan Member", role: :member,
                     team: regular, subteam: regular.subteams.find_by!(name: "Aerodynamics"))
member_b = seed_user("member.b@example.test", password, name: "Bailey Member", role: :member,
                     team: regular, subteam: regular.subteams.find_by!(name: "Structures"))
member_c = seed_user("member.c@example.test", password, name: "Cameron Member", role: :member,
                     team: micro, subteam: micro.subteams.find_by!(name: "Structures"))

wing_task = Task.find_or_initialize_by(title: "Wing load test", project: regular_wing)
wing_task.acting_user = officer_a
wing_task.update!(
     project: regular_wing,
     creator: officer_a,
     description: "Complete the load-test worksheet and attach a reviewed summary.",
     instructions: "Use the approved test fixture. Record each run and flag any result outside tolerance.",
     reference_links_text: "https://example.com/wing-load-test",
     start_date: Date.current - 3,
     due_date: 10.days.from_now.to_date,
     estimated_hours: 10,
     status: :in_progress
)
wing_task.assign_members([ member_a.id, member_b.id ], actor: officer_a)

backlog_task = Task.find_or_initialize_by(title: "Review airfoil candidates", project: regular_wing)
backlog_task.acting_user = officer_a
backlog_task.update!(project: regular_wing, creator: officer_a,
                     description: "Compare the three shortlisted airfoils.",
                     instructions: "Summarize lift, drag, and manufacturability tradeoffs.",
                     start_date: Date.current, due_date: 14.days.from_now.to_date,
                     estimated_hours: 6, status: :backlog)
backlog_task.assign_members([ member_a.id ], actor: officer_a)

completed_task = Task.find_or_initialize_by(title: "Verify spar dimensions", project: micro_spar)
completed_task.acting_user = officer_b
completed_task.update!(project: micro_spar, creator: officer_b,
                       description: "Confirm the current spar dimensions against the drawing.",
                       instructions: "Record the drawing revision used.",
                       start_date: 9.days.ago.to_date, due_date: 2.days.ago.to_date,
                       estimated_hours: 4, status: :completed)
completed_task.assign_members([ member_c.id ], actor: officer_b)

TimeEntry.find_or_create_by!(task: wing_task, user: member_a, hours: 2.5,
                             worked_on: Date.current - 2, note: "Fixture setup")
TimeEntry.find_or_create_by!(task: wing_task, user: member_a, hours: 1.5,
                             worked_on: Date.current - 1, note: "Test run")
TimeEntry.find_or_create_by!(task: wing_task, user: member_b, hours: 3,
                             worked_on: Date.current, note: "Results review")

puts "Seeded SAE AERO practice data."
