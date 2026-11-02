# AERO Task Hub user guide

This guide covers the existing release and the Sprint 3 sign-in, shared-project, roster, timeline and reporting changes. Open it any time from **Help** in the page header or from the sign-in page. Every step is written out in words; nothing depends on a screenshot or on color. Every link, field and button can be reached with Tab and used with Enter or Space.

Never put real passwords or private member records in screenshots, notes or training material.

## Sign in

1. Open the website address your team supplied.
2. Select **Sign in with Google** and choose the Google (TAMU) account whose email the Chief Engineer added for you.
3. If your team is still using practice accounts, enter the practice email and password under **or use a practice account** and select **Sign in**.
4. Select **Sign out** in the header when you finish.

Google sign-in does not require a separate website password. Your saved role, class (labeled **Team**) and subteam come from the Chief Engineer's People entry, not from your Google profile. Email matching ignores capitalization. The same approved account has the same access on a laptop or phone.

Use Tab to reach **Sign in with Google** and Enter or Space to activate it. Complete Google's account selection with the keyboard. If you choose an unapproved account, select **Sign in with Google** again and choose the approved TAMU account; no developer setup is needed to switch accounts.

If you see "Access not authorized", see [Messages and what to do](#messages-and-what-to-do). Rejected or cancelled Google sign-in signs you out of any previous website session. If your access is removed, your next page load or submitted action is denied, including an already-open form. Your saved tasks and hours remain.

## Find your work

1. Select **Tasks** to open the task board. It has three columns: Backlog, In progress and Completed.
2. Select **My Tasks** to see only the tasks assigned to you.
3. Select a task title to open its details: deliverables, work instructions, reference links, start and due dates, estimated hours and assigned members.

Members see the tasks assigned to them. Officers see their own team's tasks; the Chief Engineer sees every team.

## Search and filter tasks

1. On the board, My Tasks or the Timeline, type a word in **Search tasks** to match task titles and descriptions.
2. Choose a **Project**, a **Team** and, if needed, a **Subteam**. Projects are listed as "Team · Project" and are available to every subteam of that class. A subteam board includes a task when at least one active assignee belongs to that subteam. Subteams are listed with their team, for example "Regular Class · Aerodynamics".
3. Select **Apply**. Only permitted tasks matching the search and selected filters are shown. Leaders can also choose a **Member** and **Task dates from/to**; the date filter includes tasks overlapping that period. Use **Additional teams** or **Additional projects** to include more selections (hold Ctrl on Windows to select several).
4. Select **Clear** to show every task you are allowed to see again.

Your filters stay applied when you move between the board, My Tasks and the Timeline. A member's board first opens on their own team and subteam.

## Update task status

1. Open a task assigned to you.
2. Under **Update status**, choose Backlog, In progress or Completed.
3. Select **Save status**. The task moves to that column and stays there after you refresh.

## Record actual hours

1. Open a task assigned to you.
2. Under **Record actual hours**, enter the hours as a number greater than 0, such as `1` or `2.5`.
3. Choose the **Date worked** and, if you like, add a short note.
4. Select **Add hours**. The message "Hours were recorded." appears and the entry is listed under **Time entries**.

You can record at most 24 hours for one date across all your tasks.

## Correct or delete your hours

1. Open the task and find your entry under **Time entries**.
2. To correct it, select **Edit**, change the hours or date, and select **Save hours**.
3. To remove it, select **Delete**. The task's actual total updates straight away.

Members see and can change only their own entries. Leaders can see permitted task totals and member breakdowns, but can change only their own entries.

## For officers and the Chief Engineer

### Create or edit a task

1. Select **Add task** in a board column, or **New Task** in the header. The column's status is prefilled. Empty boards still have all three columns.
2. Enter a **Title** and choose the **Project**. A single selected project is prefilled; with several selected projects, choose the intended one. The project supplies the class. Officers see only their own class's projects.
3. Enter **Start date** (today by default), **Due date** and **Estimated hours** (0 or more). Deliverables, instructions and full reference addresses are optional.
4. Open **Assigned members** to browse eligible members and officers. Type part of a name to filter choices; capitalization does not matter. Use Arrow keys and Enter, or click a name. Selected names stay selected when the search changes; use a name's remove button to remove it. Choose an optional **Primary contact** from the selected assignees.
5. Select **Create Task**. When started from the board, you return to the same filters. A task appears once on each matching assignee's subteam board. An unassigned task appears only in team/project views; the save confirmation links to its project board. Error messages keep entered information, and **Cancel** returns without saving.
6. To edit, open the task and select **Edit task**. Removing an assignee ends that assignment period; it preserves past hours and history. Reassigning them starts a new period.

### Prerequisites and blockers

On the task form, leaders can select **Prerequisite tasks** within the same class. A task with unfinished prerequisites shows **Blocked**. Its detail page shows each prerequisite's status, assignees and link to the shared task page. Completing all prerequisites clears the blocked indicator. Dependencies do not change dates or automatically complete another task. Self-links and circular chains are refused. Members may update their assigned task's status but cannot edit prerequisites.

### Task history

Open a task you manage and read **History**. Each line gives the date and time, who acted, and what happened in words, for example "Olivia Officer removed Bailey Member" or "changed the status from Backlog to In progress". The newest entry is first, starting with the task creator and initial status. History cannot be edited or deleted. Tasks with history are retained.

### Board summary and hours (the project dashboard)

The task board doubles as the leader dashboard described in the acceptance tests.

1. Select **Tasks**. Each column heading shows how many tasks are in it, and any unfinished task past its due date shows a red **Overdue** label.
2. Choose a **Project**, team, subteam or search, and select **Apply**. The line above the board shows how many tasks are overdue and the actual hours against the estimate for the tasks shown.
3. Scroll to **Hours by member** below the board (or select its link above the board). Set **Hours from** and **Hours to** (both dates are included) and select **Show hours**. Each member's actual hours are shown against their assigned-task estimate as a chart and as a table with the difference.

### Timeline

1. Select **Timeline**. Each task is a bar from its start date to its due date, grouped by team and subteam. Gray is Backlog, blue is In progress, green is Completed, and red stripes mean overdue. The red vertical line is today.
2. Choose how many weeks to **Show** and use the search, team and subteam filters, then select **Apply**.
3. Select **Download timeline CSV** to save the task rows represented by the filtered chart, including the start and due dates. Rows marked Earlier or Later are included, as they are in the readable date list.
4. Use **‹ Previous**, **This week** and **Next ›** to move through time. A task outside the shown weeks says "Earlier" or "Later" on its row.
5. **Dates as a list** below the chart gives the same start and due dates in text.

### Teams, subteams and projects

1. Select **Teams**. Each class lists its subteams and its team-level projects.
2. Use **Add subteam** to create a subteam. To create a project, select **Add project**, choose its parent team, enter its name and save. Every subteam of that class can contribute; no participant list is needed.
3. Select **Rename** to change a name. Its parent team stays fixed in the form. Use **Archive** to remove a group from everyday lists while retaining its records.
4. Archived groups appear under **Archived**. Select one to see its tasks and hours, or select **Restore** to bring it back.

The Chief Engineer manages every team. Officers manage subteams and projects across their own team only.

### Subteam rosters

1. Select **Teams**, then a subteam's name, and find **Subteam roster**. Chief Engineers manage every roster; officers manage their own class. Members cannot open roster management.
2. Select an approved person under **Transfer approved person to this roster**, then **Transfer to roster**. Their single membership moves in one save; this does not assign a task.
3. Each row shows the person's assigned work and project, or **No assigned work**. Actual hours are 0 when none were recorded in the selected scope. Choose a project and **Hours from/to**, then **Apply roster scope**, to narrow work and dated hours.
4. To move someone out, select a destination beside their name and **Transfer membership**. Accounts, task IDs, assignment history and hours remain. Their active assignments determine the resulting subteam board visibility.

Each member and officer has exactly one membership. Chief Engineers have none and cannot be task assignees. Cross-class moves require resolving incompatible active assignments first. Zero recorded hours does not establish availability.

### Download reports

1. As a Chief Engineer or officer, apply the project, team(s), subteam, member, search and task-date filters on **Tasks**. A project filter combines work across its class's subteams; add a subteam filter to narrow it further.
2. Select **Download CSV** for the task rows matching that view. The file includes task, project, class, subteam, assignees, status, start/due dates, estimated hours and actual hours.
3. Select **Download member hours** for each relevant member's total, including members with no assignments or hours. **Download project hours** groups the same scoped hours by project. A single Class column identifies the parent team; it is not duplicated.
4. **Hours from/to** use the date the work was recorded for; both endpoint dates are included. Member/date filters apply equally to the displayed summary, task-card actual hours and downloaded totals. Shared task estimates are counted once in the project total.
5. Open the CSV in Excel or Google Sheets. Empty task results produce column headings; member reports still show relevant zero-hour members. Formula-looking names or task titles are exported as literal text for spreadsheet safety.

Members have no export controls. Direct requests are denied. Officers' downloads contain only their own class's permitted work, even if a request supplies another class's filters.

### People (Chief Engineer)

1. Select **People**.
2. Select **Add person**, enter the name and Google email, and choose the role and **Class · Subteam** membership. Select **Add person** to save. The person can sign in with Google straight away, with no separate password. Email capitalization does not matter. The class is derived from the selected subteam. Chief Engineers have no membership.
3. Select **Change role** to change someone's role, team or subteam. The change applies the next time they load a page.
4. Select **Remove access** to stop someone signing in; their tasks and hours are kept. **Restore access** lets them sign in again. Removal also blocks actions submitted from already-open pages. Officers and members cannot open People or change the allowed-users list.

## Messages and what to do

| Message | What it means | What to do |
| --- | --- | --- |
| Access not authorized. Email or password is incorrect, or the account has not been approved yet. | The practice email or password is wrong, or the account is not on the approved list. | Check the email and password and try again. If it still fails, ask the Chief Engineer to add you under People. |
| Access not authorized. Ask the Chief Engineer to add your email to the allowed people list. | Your Google email is not on the approved list. | Sign in with the Google account the Chief Engineer added, or ask them to add this email. |
| Access not authorized. Your access has been removed. | The Chief Engineer removed your access. | Ask the Chief Engineer to restore your access. |
| Google sign-in was cancelled or failed. Please try again. | The Google window was closed or Google refused the request. | Select Sign in with Google again and finish choosing your account. |
| Please sign in to view that page. | You are signed out. | Sign in, then open the page again. |
| Title can't be blank (or another field "can't be blank") | A required field is empty. | Fill in the field named next to the message and save again. |
| Estimated hours is not a number / Hours is not a number | Letters or symbols were typed where a number is needed. | Type digits only, for example `1` or `2.5`, and save again. |
| Hours must be greater than 0 | Zero or a negative number was entered. | Enter a number above 0. |
| Hours for (date) would total (number); a member can record at most 24 hours per day | Your hours for that date across all tasks would pass 24. | Check your other entries for that date, then enter fewer hours or a different date. |
| Due date must be on or after the start date | The due date is earlier than the start date. | Choose a due date on or after the start date. |
| End date must be on or after the start date | Under Hours by member, Hours to is earlier than Hours from. | Choose a later Hours to date, or select Clear. |
| Start date is not a valid date / End date is not a valid date | Hours by member could not read a date. | Pick the date with the date picker or type it as YYYY-MM-DD. |
| Reference links must each be a full web address starting with http:// or https:// | A reference link is incomplete. | Put one full address per line, for example `https://example.com/plan`. |
| You can update only tasks assigned to you. | You tried to change a task that is not yours. | Ask an officer to assign you, or update one of your own tasks. |
| You cannot view that task. | The task belongs to work you are not allowed to see. | Return to Tasks or My Tasks. |
| You can change only your own hours. | You tried to edit or delete someone else's entry. | Ask that member to correct their own entry. |
| You can manage only tasks on your own team. | An officer tried to change another team's task. | Ask that team's officer or the Chief Engineer. |
| Project must belong to your team | An officer chose another team's project. | Choose one of your team's projects. |
| The timeline is available to team officers and the Chief Engineer. | Members cannot open the timeline. | Use Tasks and My Tasks to see your dates. |
| You can manage only your own team's subteams and projects. | An officer tried to change another team's group. | Ask the Chief Engineer. |
| Access denied. Only the Chief Engineer can manage people and roles. | Only the Chief Engineer can open People. | Ask the Chief Engineer to make the change. |
| Access denied. Reports are available to team officers and the Chief Engineer. | Your role cannot download leader reports. | Use your assigned task view or ask an officer for an authorized report. |
| Access denied. Only authorized leaders can manage this roster. | You do not manage this class's roster. | Ask its officer or the Chief Engineer. |
| Choose an approved member or officer from this class. | The selected person is unavailable or belongs to another class. | Select an approved person from this class. |
| Choose a destination subteam to transfer this membership. | Members and officers cannot be left without a membership. | Choose another subteam in the class and transfer in one save. |
| This person does not belong to this roster. | The membership changed or the wrong person was selected. | Refresh the roster. |
| Subteam is required for a member or officer | A membership is missing. | Choose Class · Subteam before saving. |
| Subteam must be blank for a Chief Engineer | An administrator cannot also have a roster membership. | Clear the membership; first resolve any active assignments. |
| cannot change teams until incompatible active assignments are resolved | The person's active task assignments belong to their former class. | End or otherwise resolve those assignments before changing class. |
| Prerequisite task would create a loop / cannot be the task itself | The proposed dependency is circular. | Select a different prerequisite. |
| Primary contact must be an active assignee | The selected contact is not assigned. | Assign them first or choose another active assignee. |
| Project must exist | The task has no valid project. | Select a permitted project. |
| Tasks with recorded history or logged hours cannot be deleted. | These records preserve project history. | Retain the task; archive its project when appropriate. |
| Access denied. The administrator guide is available to the Chief Engineer. | Your role cannot open the administrator guide. | Read the user guide or contact the Chief Engineer. |
