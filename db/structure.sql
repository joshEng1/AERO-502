--
-- PostgreSQL database dump
--


-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: aero_guard_assignment_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aero_guard_assignment_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
     IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'Assignment periods cannot be deleted.' USING ERRCODE = '23514'; END IF;
     IF TG_OP = 'UPDATE' THEN
          IF (NEW.task_id, NEW.user_id, NEW.assigned_by_id, NEW.assigned_at) IS DISTINCT FROM
             (OLD.task_id, OLD.user_id, OLD.assigned_by_id, OLD.assigned_at) THEN
               RAISE EXCEPTION 'The beginning of an assignment period cannot be rewritten.' USING ERRCODE = '23514';
          END IF;
          IF OLD.unassigned_at IS NOT NULL AND (NEW.unassigned_by_id, NEW.unassigned_at) IS DISTINCT FROM
             (OLD.unassigned_by_id, OLD.unassigned_at) THEN
               RAISE EXCEPTION 'An ended assignment cannot be reopened or rewritten; create a new period.' USING ERRCODE = '23514';
          END IF;
     END IF;
     RETURN NEW;
END $$;


--
-- Name: aero_guard_status_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aero_guard_status_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE previous integer; previous_time timestamp;
BEGIN
     IF TG_OP <> 'INSERT' THEN RAISE EXCEPTION 'Status history cannot be edited or deleted.' USING ERRCODE = '23514'; END IF;
     SELECT to_status, created_at INTO previous, previous_time FROM task_status_changes WHERE task_id = NEW.task_id ORDER BY created_at DESC, id DESC LIMIT 1;
     IF previous = NEW.to_status THEN RAISE EXCEPTION 'The status has not changed.' USING ERRCODE = '23514'; END IF;
     IF previous_time IS NOT NULL AND NEW.created_at < previous_time THEN
          RAISE EXCEPTION 'A status change cannot precede the latest recorded change.' USING ERRCODE = '23514';
     END IF;
     IF previous IS NULL AND NOT EXISTS (
          SELECT 1 FROM tasks WHERE id = NEW.task_id AND creator_id = NEW.actor_id AND created_at = NEW.created_at
     ) THEN RAISE EXCEPTION 'Initial status history must identify the task creator and creation time.' USING ERRCODE = '23514'; END IF;
     IF NOT EXISTS (
          SELECT 1 FROM users u JOIN tasks t ON t.id = NEW.task_id JOIN projects p ON p.id = t.project_id
          LEFT JOIN memberships m ON m.user_id = u.id LEFT JOIN subteams s ON s.id = m.subteam_id
          WHERE u.id = NEW.actor_id AND u.access_revoked_at IS NULL AND (
               u.role = 2 OR (u.role = 1 AND s.team_id = p.team_id) OR EXISTS (
                    SELECT 1 FROM task_assignments a WHERE a.task_id = t.id AND a.user_id = u.id AND a.unassigned_at IS NULL
               )
          )
     ) THEN RAISE EXCEPTION 'The status actor must have access to this task.' USING ERRCODE = '23514'; END IF;
     RETURN NEW;
END $$;


--
-- Name: aero_integrity_lock(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aero_integrity_lock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
     PERFORM pg_advisory_xact_lock(5023001);
     RETURN NULL;
END $$;


--
-- Name: aero_validate_integrity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aero_validate_integrity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
     IF EXISTS (
          SELECT 1 FROM users u LEFT JOIN memberships m ON m.user_id = u.id
          WHERE (u.role = 2 AND m.user_id IS NOT NULL) OR (u.role <> 2 AND m.user_id IS NULL)
     ) THEN RAISE EXCEPTION 'Members and officers require exactly one subteam; administrators require none.' USING ERRCODE = '23514'; END IF;
     IF EXISTS (
          SELECT 1 FROM task_assignments a JOIN tasks t ON t.id = a.task_id
          JOIN projects p ON p.id = t.project_id LEFT JOIN memberships m ON m.user_id = a.user_id
          LEFT JOIN subteams s ON s.id = m.subteam_id
          WHERE a.unassigned_at IS NULL AND (m.user_id IS NULL OR s.team_id <> p.team_id)
     ) THEN RAISE EXCEPTION 'An active assignee must belong to the project team; resolve assignments before transferring ownership.' USING ERRCODE = '23514'; END IF;
     IF EXISTS (
          SELECT 1 FROM tasks t LEFT JOIN LATERAL (
               SELECT to_status FROM task_status_changes WHERE task_id = t.id ORDER BY created_at DESC, id DESC LIMIT 1
          ) latest ON TRUE WHERE latest.to_status IS NULL OR latest.to_status <> t.status
     ) THEN RAISE EXCEPTION 'Task status must match its complete status history.' USING ERRCODE = '23514'; END IF;
     IF EXISTS (
          SELECT 1 FROM task_dependencies d JOIN tasks t ON t.id = d.task_id JOIN projects p ON p.id = t.project_id
          JOIN tasks r ON r.id = d.prerequisite_task_id JOIN projects q ON q.id = r.project_id WHERE p.team_id <> q.team_id
     ) THEN RAISE EXCEPTION 'Prerequisites must stay within the same team.' USING ERRCODE = '23514'; END IF;
     IF EXISTS (
          WITH RECURSIVE paths(start_id, end_id) AS (
               SELECT task_id, prerequisite_task_id FROM task_dependencies
               UNION SELECT paths.start_id, d.prerequisite_task_id FROM paths JOIN task_dependencies d ON d.task_id = paths.end_id
          ) SELECT 1 FROM paths WHERE start_id = end_id
     ) THEN RAISE EXCEPTION 'Prerequisites cannot form a loop.' USING ERRCODE = '23514'; END IF;
     RETURN NULL;
END $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    user_id bigint NOT NULL,
    subteam_id bigint NOT NULL
);


--
-- Name: memberships_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.memberships_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: memberships_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.memberships_user_id_seq OWNED BY public.memberships.user_id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    archived_at timestamp(6) without time zone,
    team_id bigint NOT NULL
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: subteams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subteams (
    id bigint NOT NULL,
    name character varying NOT NULL,
    team_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    archived_at timestamp(6) without time zone
);


--
-- Name: subteams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subteams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subteams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subteams_id_seq OWNED BY public.subteams.id;


--
-- Name: task_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_assignments (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    assigned_by_id bigint NOT NULL,
    unassigned_by_id bigint,
    assigned_at timestamp(6) without time zone NOT NULL,
    unassigned_at timestamp(6) without time zone,
    is_primary_contact boolean DEFAULT false NOT NULL,
    CONSTRAINT assignment_ending_pair CHECK ((((unassigned_by_id IS NULL) AND (unassigned_at IS NULL)) OR ((unassigned_by_id IS NOT NULL) AND (unassigned_at IS NOT NULL) AND (unassigned_at >= assigned_at)))),
    CONSTRAINT primary_contact_is_active CHECK (((NOT is_primary_contact) OR (unassigned_at IS NULL)))
);


--
-- Name: task_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_assignments_id_seq OWNED BY public.task_assignments.id;


--
-- Name: task_dependencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_dependencies (
    task_id bigint NOT NULL,
    prerequisite_task_id bigint NOT NULL,
    CONSTRAINT no_self_dependency CHECK ((task_id <> prerequisite_task_id))
);


--
-- Name: task_status_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_status_changes (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    actor_id bigint NOT NULL,
    to_status integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT valid_history_status CHECK ((to_status = ANY (ARRAY[0, 1, 2])))
);


--
-- Name: task_status_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_status_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_status_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_status_changes_id_seq OWNED BY public.task_status_changes.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id bigint NOT NULL,
    title character varying NOT NULL,
    description text,
    instructions text,
    due_date date NOT NULL,
    estimated_hours numeric(7,2) NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    creator_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    start_date date NOT NULL,
    project_id bigint NOT NULL
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    archived_at timestamp(6) without time zone
);


--
-- Name: teams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.teams_id_seq OWNED BY public.teams.id;


--
-- Name: time_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.time_entries (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    user_id bigint NOT NULL,
    hours numeric(7,2) NOT NULL,
    note character varying,
    worked_on date NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: time_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.time_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: time_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.time_entries_id_seq OWNED BY public.time_entries.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    name character varying NOT NULL,
    email character varying NOT NULL,
    password_digest character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    access_revoked_at timestamp(6) without time zone,
    role integer DEFAULT 0 CONSTRAINT users_role_not_null1 NOT NULL,
    CONSTRAINT approved_user_roles CHECK ((role = ANY (ARRAY[0, 1, 2])))
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: memberships user_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships ALTER COLUMN user_id SET DEFAULT nextval('public.memberships_user_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: subteams id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subteams ALTER COLUMN id SET DEFAULT nextval('public.subteams_id_seq'::regclass);


--
-- Name: task_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments ALTER COLUMN id SET DEFAULT nextval('public.task_assignments_id_seq'::regclass);


--
-- Name: task_status_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_status_changes ALTER COLUMN id SET DEFAULT nextval('public.task_status_changes_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);


--
-- Name: teams id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams ALTER COLUMN id SET DEFAULT nextval('public.teams_id_seq'::regclass);


--
-- Name: time_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_entries ALTER COLUMN id SET DEFAULT nextval('public.time_entries_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (user_id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: subteams subteams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subteams
    ADD CONSTRAINT subteams_pkey PRIMARY KEY (id);


--
-- Name: task_assignments task_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_pkey PRIMARY KEY (id);


--
-- Name: task_dependencies task_dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT task_dependencies_pkey PRIMARY KEY (task_id, prerequisite_task_id);


--
-- Name: task_status_changes task_status_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_status_changes
    ADD CONSTRAINT task_status_changes_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: time_entries time_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_entries
    ADD CONSTRAINT time_entries_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_memberships_on_subteam_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_subteam_id ON public.memberships USING btree (subteam_id);


--
-- Name: index_projects_on_team_and_normalized_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_team_and_normalized_name ON public.projects USING btree (team_id, lower((name)::text));


--
-- Name: index_projects_on_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_team_id ON public.projects USING btree (team_id);


--
-- Name: index_subteams_on_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subteams_on_team_id ON public.subteams USING btree (team_id);


--
-- Name: index_subteams_on_team_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_subteams_on_team_id_and_name ON public.subteams USING btree (team_id, name);


--
-- Name: index_task_assignments_on_assigned_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_assignments_on_assigned_by_id ON public.task_assignments USING btree (assigned_by_id);


--
-- Name: index_task_assignments_on_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_assignments_on_task_id ON public.task_assignments USING btree (task_id);


--
-- Name: index_task_assignments_on_unassigned_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_assignments_on_unassigned_by_id ON public.task_assignments USING btree (unassigned_by_id);


--
-- Name: index_task_assignments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_assignments_on_user_id ON public.task_assignments USING btree (user_id);


--
-- Name: index_task_dependencies_on_prerequisite_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_dependencies_on_prerequisite_task_id ON public.task_dependencies USING btree (prerequisite_task_id);


--
-- Name: index_task_dependencies_on_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_dependencies_on_task_id ON public.task_dependencies USING btree (task_id);


--
-- Name: index_task_status_changes_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_status_changes_on_actor_id ON public.task_status_changes USING btree (actor_id);


--
-- Name: index_task_status_changes_on_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_status_changes_on_task_id ON public.task_status_changes USING btree (task_id);


--
-- Name: index_tasks_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_creator_id ON public.tasks USING btree (creator_id);


--
-- Name: index_tasks_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_project_id ON public.tasks USING btree (project_id);


--
-- Name: index_teams_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_teams_on_name ON public.teams USING btree (name);


--
-- Name: index_time_entries_on_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_time_entries_on_task_id ON public.time_entries USING btree (task_id);


--
-- Name: index_time_entries_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_time_entries_on_user_id ON public.time_entries USING btree (user_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: one_active_assignment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_active_assignment ON public.task_assignments USING btree (task_id, user_id) WHERE (unassigned_at IS NULL);


--
-- Name: one_primary_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_primary_contact ON public.task_assignments USING btree (task_id) WHERE (is_primary_contact AND (unassigned_at IS NULL));


--
-- Name: ordered_status_history; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ordered_status_history ON public.task_status_changes USING btree (task_id, created_at, id);


--
-- Name: unique_assignment_period; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_assignment_period ON public.task_assignments USING btree (task_id, user_id, assigned_at);


--
-- Name: task_assignments immutable_assignment_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER immutable_assignment_history BEFORE DELETE OR UPDATE ON public.task_assignments FOR EACH ROW EXECUTE FUNCTION public.aero_guard_assignment_history();


--
-- Name: task_status_changes immutable_status_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER immutable_status_history BEFORE INSERT OR DELETE OR UPDATE ON public.task_status_changes FOR EACH ROW EXECUTE FUNCTION public.aero_guard_status_history();


--
-- Name: memberships lock_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lock_approved_integrity BEFORE INSERT OR DELETE OR UPDATE ON public.memberships FOR EACH STATEMENT EXECUTE FUNCTION public.aero_integrity_lock();


--
-- Name: projects lock_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lock_approved_integrity BEFORE INSERT OR DELETE OR UPDATE ON public.projects FOR EACH STATEMENT EXECUTE FUNCTION public.aero_integrity_lock();


--
-- Name: subteams lock_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lock_approved_integrity BEFORE INSERT OR DELETE OR UPDATE ON public.subteams FOR EACH STATEMENT EXECUTE FUNCTION public.aero_integrity_lock();


--
-- Name: task_assignments lock_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lock_approved_integrity BEFORE INSERT OR DELETE OR UPDATE ON public.task_assignments FOR EACH STATEMENT EXECUTE FUNCTION public.aero_integrity_lock();


--
-- Name: task_dependencies lock_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lock_approved_integrity BEFORE INSERT OR DELETE OR UPDATE ON public.task_dependencies FOR EACH STATEMENT EXECUTE FUNCTION public.aero_integrity_lock();


--
-- Name: task_status_changes lock_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lock_approved_integrity BEFORE INSERT OR DELETE OR UPDATE ON public.task_status_changes FOR EACH STATEMENT EXECUTE FUNCTION public.aero_integrity_lock();


--
-- Name: tasks lock_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lock_approved_integrity BEFORE INSERT OR DELETE OR UPDATE ON public.tasks FOR EACH STATEMENT EXECUTE FUNCTION public.aero_integrity_lock();


--
-- Name: users lock_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lock_approved_integrity BEFORE INSERT OR DELETE OR UPDATE ON public.users FOR EACH STATEMENT EXECUTE FUNCTION public.aero_integrity_lock();


--
-- Name: memberships validate_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER validate_approved_integrity AFTER INSERT OR DELETE OR UPDATE ON public.memberships DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.aero_validate_integrity();


--
-- Name: projects validate_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER validate_approved_integrity AFTER INSERT OR DELETE OR UPDATE ON public.projects DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.aero_validate_integrity();


--
-- Name: subteams validate_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER validate_approved_integrity AFTER INSERT OR DELETE OR UPDATE ON public.subteams DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.aero_validate_integrity();


--
-- Name: task_assignments validate_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER validate_approved_integrity AFTER INSERT OR DELETE OR UPDATE ON public.task_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.aero_validate_integrity();


--
-- Name: task_dependencies validate_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER validate_approved_integrity AFTER INSERT OR DELETE OR UPDATE ON public.task_dependencies DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.aero_validate_integrity();


--
-- Name: task_status_changes validate_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER validate_approved_integrity AFTER INSERT OR DELETE OR UPDATE ON public.task_status_changes DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.aero_validate_integrity();


--
-- Name: tasks validate_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER validate_approved_integrity AFTER INSERT OR DELETE OR UPDATE ON public.tasks DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.aero_validate_integrity();


--
-- Name: users validate_approved_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER validate_approved_integrity AFTER INSERT OR DELETE OR UPDATE ON public.users DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.aero_validate_integrity();


--
-- Name: tasks fk_rails_00f6e5b7b4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_00f6e5b7b4 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: tasks fk_rails_02e851e3b7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_02e851e3b7 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: task_dependencies fk_rails_113ebe41a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT fk_rails_113ebe41a9 FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: time_entries fk_rails_55dd5dcf98; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_entries
    ADD CONSTRAINT fk_rails_55dd5dcf98 FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: memberships fk_rails_65274aae84; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_65274aae84 FOREIGN KEY (subteam_id) REFERENCES public.subteams(id);


--
-- Name: task_status_changes fk_rails_85787e2d07; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_status_changes
    ADD CONSTRAINT fk_rails_85787e2d07 FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: task_assignments fk_rails_8d61fc0e26; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT fk_rails_8d61fc0e26 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: memberships fk_rails_99326fb65d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_99326fb65d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: task_dependencies fk_rails_a66a632c65; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT fk_rails_a66a632c65 FOREIGN KEY (prerequisite_task_id) REFERENCES public.tasks(id);


--
-- Name: task_status_changes fk_rails_a94f80021b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_status_changes
    ADD CONSTRAINT fk_rails_a94f80021b FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: time_entries fk_rails_b471d1824b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_entries
    ADD CONSTRAINT fk_rails_b471d1824b FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: task_assignments fk_rails_b7a2056e80; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT fk_rails_b7a2056e80 FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: task_assignments fk_rails_ca3ffd900d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT fk_rails_ca3ffd900d FOREIGN KEY (assigned_by_id) REFERENCES public.users(id);


--
-- Name: task_assignments fk_rails_e13d4762da; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT fk_rails_e13d4762da FOREIGN KEY (unassigned_by_id) REFERENCES public.users(id);


--
-- Name: subteams fk_rails_e9665928e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subteams
    ADD CONSTRAINT fk_rails_e9665928e5 FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: projects fk_rails_ecc227a0c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_ecc227a0c2 FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- PostgreSQL database dump complete
--



INSERT INTO public.schema_migrations (version) VALUES ('20260927224355');
INSERT INTO public.schema_migrations (version) VALUES ('20260927224356');
INSERT INTO public.schema_migrations (version) VALUES ('20260927224357');
INSERT INTO public.schema_migrations (version) VALUES ('20260927224358');
INSERT INTO public.schema_migrations (version) VALUES ('20260927224359');
INSERT INTO public.schema_migrations (version) VALUES ('20260927224360');
INSERT INTO public.schema_migrations (version) VALUES ('20260927224361');
INSERT INTO public.schema_migrations (version) VALUES ('20261007120000');
INSERT INTO public.schema_migrations (version) VALUES ('20261007130000');
INSERT INTO public.schema_migrations (version) VALUES ('20261007140000');
INSERT INTO public.schema_migrations (version) VALUES ('20261007150000');
INSERT INTO public.schema_migrations (version) VALUES ('20261007160000');
INSERT INTO public.schema_migrations (version) VALUES ('20261007170000');
INSERT INTO public.schema_migrations (version) VALUES ('20261023120000');
INSERT INTO public.schema_migrations (version) VALUES ('20261023121000');
INSERT INTO public.schema_migrations (version) VALUES ('20261102000000');
