--
-- PostgreSQL database dump
--

\restrict d7zZFH4MCumKxuljqrqVOSwHVMltIsPUBAZHNtAQEgI5kQCsZS5YxsMIDhKslcF

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.3 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: inspection_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.inspection_status AS ENUM (
    'ok',
    'issues_found'
);


ALTER TYPE public.inspection_status OWNER TO postgres;

--
-- Name: inspection_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.inspection_type AS ENUM (
    'pre_trip',
    'post_trip'
);


ALTER TYPE public.inspection_type OWNER TO postgres;

--
-- Name: maintenance_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.maintenance_status AS ENUM (
    'scheduled',
    'in_progress',
    'completed'
);


ALTER TYPE public.maintenance_status OWNER TO postgres;

--
-- Name: message_read_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.message_read_status AS ENUM (
    'sent',
    'delivered',
    'read'
);


ALTER TYPE public.message_read_status OWNER TO postgres;

--
-- Name: priority_level; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.priority_level AS ENUM (
    'low',
    'medium',
    'high'
);


ALTER TYPE public.priority_level OWNER TO postgres;

--
-- Name: trip_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.trip_status AS ENUM (
    'assigned',
    'in_progress',
    'completed',
    'cancelled',
    'pending'
);


ALTER TYPE public.trip_status OWNER TO postgres;

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_role AS ENUM (
    'driver',
    'fleet_manager',
    'maintenance'
);


ALTER TYPE public.user_role OWNER TO postgres;

--
-- Name: vehicle_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.vehicle_status AS ENUM (
    'active',
    'inactive',
    'under_maintenance'
);


ALTER TYPE public.vehicle_status OWNER TO postgres;

--
-- Name: vehicle_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.vehicle_type AS ENUM (
    'Bike',
    'Car',
    'Bus',
    'Truck'
);


ALTER TYPE public.vehicle_type OWNER TO postgres;

--
-- Name: work_order_priority; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.work_order_priority AS ENUM (
    'Low',
    'Medium',
    'High',
    'Urgent'
);


ALTER TYPE public.work_order_priority OWNER TO postgres;

--
-- Name: work_order_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.work_order_status AS ENUM (
    'Pending',
    'In Progress',
    'Completed',
    'Cancelled'
);


ALTER TYPE public.work_order_status OWNER TO postgres;

--
-- Name: fn_cleanup_after_maintenance(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_cleanup_after_maintenance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.status = 'Completed' THEN
        UPDATE public.vehicles 
        SET status = 'active' 
        WHERE vehicle_id = NEW.vehicle_id;

        DELETE FROM public.maintenance_issues 
        WHERE vehicle_id = NEW.vehicle_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_cleanup_after_maintenance() OWNER TO postgres;

--
-- Name: handle_user_confirmed(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.handle_user_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  -- Fires when email_confirmed_at changes from NULL → a timestamp (first login)
  IF OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL THEN
    UPDATE public.users
    SET status = 'active'
    WHERE user_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.handle_user_confirmed() OWNER TO postgres;

--
-- Name: is_fleet_manager(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_fleet_manager() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE user_id = auth.uid()
      AND role = 'fleet_manager'
  );
$$;


ALTER FUNCTION public.is_fleet_manager() OWNER TO postgres;

--
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION public.rls_auto_enable() OWNER TO postgres;

--
-- Name: trigger_monitor_geofences(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trigger_monitor_geofences() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    supabase_url TEXT;
    service_role_key TEXT;
BEGIN
    -- Get Supabase URL and service role key from environment
    -- These should be set using: ALTER DATABASE postgres SET app.settings.supabase_url = 'https://[project-ref].supabase.co';
    -- and: ALTER DATABASE postgres SET app.settings.service_role_key = '[service-role-key]';
    supabase_url := current_setting('app.settings.supabase_url', true);
    service_role_key := current_setting('app.settings.service_role_key', true);
    
    -- If settings are not configured, log error and return
    -- This prevents the trigger from failing during development/testing
    IF supabase_url IS NULL OR service_role_key IS NULL THEN
        RAISE WARNING 'Supabase URL or service role key not configured. Skipping geofence monitoring.';
        RETURN NEW;
    END IF;
    
    -- Invoke Edge Function asynchronously using net.http_post
    -- This function is called after each INSERT or UPDATE on vehicle_locations
    PERFORM net.http_post(
        url := supabase_url || '/functions/v1/monitor-geofences',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || service_role_key
        ),
        body := jsonb_build_object(
            'vehicle_id', NEW.vehicle_id,
            'latitude', NEW.latitude,
            'longitude', NEW.longitude,
            'timestamp', NEW.timestamp
        )
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the location update
        RAISE WARNING 'Failed to invoke monitor-geofences Edge Function: %', SQLERRM;
        RETURN NEW;
END;
$$;


ALTER FUNCTION public.trigger_monitor_geofences() OWNER TO postgres;

--
-- Name: FUNCTION trigger_monitor_geofences(); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.trigger_monitor_geofences() IS 'Trigger function that invokes the monitor-geofences Edge Function asynchronously when vehicle locations are updated. 
Passes vehicle_id, latitude, longitude, and timestamp to the Edge Function for geofence monitoring.
Requirements: 6.1 (entry detection), 7.1 (exit detection)';


--
-- Name: update_inventory_on_work_order(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_inventory_on_work_order() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 1. When a part is ADDED to a work order (Reduce Inventory)
    IF TG_OP = 'INSERT' THEN
        UPDATE public.inventory
        SET quantity = quantity - NEW.quantity_required,
            updated_at = now()
        WHERE inventory_id = NEW.inventory_id;
        RETURN NEW;
        
    -- 2. When a part is REMOVED from a work order (Add back to Inventory)
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.inventory
        SET quantity = quantity + OLD.quantity_required,
            updated_at = now()
        WHERE inventory_id = OLD.inventory_id;
        RETURN OLD;
        
    -- 3. When a part quantity is UPDATED on an existing work order
    ELSIF TG_OP = 'UPDATE' THEN
        UPDATE public.inventory
        SET quantity = quantity + OLD.quantity_required - NEW.quantity_required,
            updated_at = now()
        WHERE inventory_id = NEW.inventory_id;
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_inventory_on_work_order() OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

--
-- Name: update_vehicle_doc_flags(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_vehicle_doc_flags() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.vehicles 
        SET 
            has_rc = CASE WHEN NEW.document_type = 'RC' THEN true ELSE has_rc END,
            has_insurance = CASE WHEN NEW.document_type = 'INSURANCE' THEN true ELSE has_insurance END,
            has_puc = CASE WHEN NEW.document_type = 'PUC' THEN true ELSE has_puc END
        WHERE vehicle_id = NEW.vehicle_id;
    ELSIF (TG_OP = 'DELETE') THEN
        -- Optional: Re-check existence on delete
        UPDATE public.vehicles v
        SET has_rc = EXISTS (SELECT 1 FROM vehicle_documents WHERE vehicle_id = v.vehicle_id AND document_type = 'RC')
        WHERE vehicle_id = OLD.vehicle_id;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_vehicle_doc_flags() OWNER TO postgres;

--
-- Name: update_vehicle_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_vehicle_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_vehicle_timestamp() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: chat_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chat_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    chat_room_id uuid,
    sender_id uuid,
    message_type text DEFAULT 'Text'::text,
    content text,
    media_url text,
    is_edited boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.chat_messages OWNER TO postgres;

--
-- Name: chat_participants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chat_participants (
    chat_room_id uuid NOT NULL,
    user_id uuid NOT NULL,
    joined_at timestamp without time zone DEFAULT now(),
    last_read_at timestamp without time zone
);


ALTER TABLE public.chat_participants OWNER TO postgres;

--
-- Name: chat_rooms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chat_rooms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type text NOT NULL,
    name text,
    work_order_id uuid,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.chat_rooms OWNER TO postgres;

--
-- Name: driver_reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.driver_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    driver_id uuid,
    vehicle_id uuid,
    trip_id uuid,
    category text NOT NULL,
    severity text NOT NULL,
    description text NOT NULL,
    status text DEFAULT 'reported'::text,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT driver_reports_category_check CHECK ((category = ANY (ARRAY['mechanical'::text, 'electrical'::text, 'tyre/wheel'::text, 'fluid leak'::text, 'body damage'::text, 'safety'::text, 'other'::text]))),
    CONSTRAINT driver_reports_severity_check CHECK ((severity = ANY (ARRAY['low'::text, 'medium'::text, 'critical'::text]))),
    CONSTRAINT driver_reports_status_check CHECK ((status = ANY (ARRAY['reported'::text, 'acknowledged'::text, 'converted_to_work_order'::text, 'resolved'::text])))
);


ALTER TABLE public.driver_reports OWNER TO postgres;

--
-- Name: drivers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.drivers (
    driver_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid,
    license_no text NOT NULL,
    license_expiry date NOT NULL,
    license_image_url text
);


ALTER TABLE public.drivers OWNER TO postgres;

--
-- Name: geofence_assignments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.geofence_assignments (
    assignment_id uuid DEFAULT gen_random_uuid() NOT NULL,
    geofence_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.geofence_assignments OWNER TO postgres;

--
-- Name: TABLE geofence_assignments; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.geofence_assignments IS 'Manages many-to-many relationship between geofences and vehicles with cascade delete';


--
-- Name: COLUMN geofence_assignments.assignment_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_assignments.assignment_id IS 'Unique identifier for the assignment';


--
-- Name: COLUMN geofence_assignments.geofence_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_assignments.geofence_id IS 'Foreign key to geofences table with CASCADE delete';


--
-- Name: COLUMN geofence_assignments.vehicle_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_assignments.vehicle_id IS 'Foreign key to vehicles table';


--
-- Name: COLUMN geofence_assignments.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_assignments.created_at IS 'Timestamp when assignment was created';


--
-- Name: geofence_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.geofence_events (
    event_id uuid DEFAULT gen_random_uuid() NOT NULL,
    geofence_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    event_type character varying(10) NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL,
    latitude numeric(10,8) NOT NULL,
    longitude numeric(11,8) NOT NULL,
    dwell_time integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT geofence_events_event_type_check CHECK (((event_type)::text = ANY ((ARRAY['entry'::character varying, 'exit'::character varying])::text[])))
);


ALTER TABLE public.geofence_events OWNER TO postgres;

--
-- Name: TABLE geofence_events; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.geofence_events IS 'Stores all geofence entry and exit events for vehicles with event history and dwell time tracking';


--
-- Name: COLUMN geofence_events.event_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_events.event_id IS 'Unique identifier for the event';


--
-- Name: COLUMN geofence_events.geofence_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_events.geofence_id IS 'Foreign key to geofences table with CASCADE delete';


--
-- Name: COLUMN geofence_events.vehicle_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_events.vehicle_id IS 'Foreign key to vehicles table';


--
-- Name: COLUMN geofence_events.event_type; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_events.event_type IS 'Type of event: entry or exit';


--
-- Name: COLUMN geofence_events."timestamp"; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_events."timestamp" IS 'Timestamp when the event occurred';


--
-- Name: COLUMN geofence_events.latitude; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_events.latitude IS 'Vehicle latitude at time of event';


--
-- Name: COLUMN geofence_events.longitude; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_events.longitude IS 'Vehicle longitude at time of event';


--
-- Name: COLUMN geofence_events.dwell_time; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_events.dwell_time IS 'Duration in seconds between entry and exit (only for exit events)';


--
-- Name: COLUMN geofence_events.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofence_events.created_at IS 'Timestamp when event record was created';


--
-- Name: geofences; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.geofences (
    geofence_id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    latitude numeric(10,8) NOT NULL,
    longitude numeric(11,8) NOT NULL,
    radius integer NOT NULL,
    type character varying(20) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT geofences_latitude_check CHECK (((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric))),
    CONSTRAINT geofences_longitude_check CHECK (((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric))),
    CONSTRAINT geofences_radius_check CHECK (((radius >= 50) AND (radius <= 10000))),
    CONSTRAINT geofences_type_check CHECK (((type)::text = ANY ((ARRAY['depot'::character varying, 'delivery'::character varying, 'restricted'::character varying])::text[])))
);


ALTER TABLE public.geofences OWNER TO postgres;

--
-- Name: TABLE geofences; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.geofences IS 'Stores geofence definitions with validation constraints for latitude, longitude, radius, and type';


--
-- Name: COLUMN geofences.geofence_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofences.geofence_id IS 'Unique identifier for the geofence';


--
-- Name: COLUMN geofences.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofences.name IS 'Geofence name (3-100 characters)';


--
-- Name: COLUMN geofences.latitude; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofences.latitude IS 'Center latitude in degrees (-90 to 90)';


--
-- Name: COLUMN geofences.longitude; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofences.longitude IS 'Center longitude in degrees (-180 to 180)';


--
-- Name: COLUMN geofences.radius; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofences.radius IS 'Radius in meters (50 to 10000)';


--
-- Name: COLUMN geofences.type; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofences.type IS 'Geofence type: depot, delivery, or restricted';


--
-- Name: COLUMN geofences.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofences.created_at IS 'Timestamp when geofence was created';


--
-- Name: COLUMN geofences.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.geofences.updated_at IS 'Timestamp when geofence was last updated';


--
-- Name: inspections; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inspections (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    trip_id uuid,
    type public.inspection_type,
    notes text,
    status public.inspection_status,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.inspections OWNER TO postgres;

--
-- Name: inventory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory (
    inventory_id uuid DEFAULT gen_random_uuid() NOT NULL,
    part_name character varying NOT NULL,
    vehicle_category character varying,
    category_description text,
    supplier character varying,
    quantity integer DEFAULT 0 NOT NULL,
    cost_per_unit numeric(10,2),
    sku character varying,
    location character varying,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.inventory OWNER TO postgres;

--
-- Name: maintenance_issues; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maintenance_issues (
    issue_id uuid DEFAULT gen_random_uuid() NOT NULL,
    vehicle_id uuid NOT NULL,
    maintenance_personnel_id uuid,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    issue_summary text,
    status text DEFAULT 'pending'::text,
    CONSTRAINT maintenance_issues_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'in_progress'::text, 'completed'::text])))
);


ALTER TABLE public.maintenance_issues OWNER TO postgres;

--
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recipient_id uuid NOT NULL,
    sender_id uuid,
    title text NOT NULL,
    message text NOT NULL,
    type text NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    related_entity_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- Name: otp_codes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.otp_codes (
    id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    email text NOT NULL,
    otp_hash text NOT NULL,
    expires_at timestamp without time zone NOT NULL
);


ALTER TABLE public.otp_codes OWNER TO postgres;

--
-- Name: TABLE otp_codes; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.otp_codes IS 'Contains otp-codes required for MFA';


--
-- Name: otp_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.otp_codes ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.otp_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: routes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.routes (
    route_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    start_location text NOT NULL,
    end_location text NOT NULL,
    distance double precision,
    estimated_time double precision,
    polyline_data text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.routes OWNER TO postgres;

--
-- Name: trips; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trips (
    trip_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    vehicle_id uuid,
    driver_id uuid,
    route_id uuid,
    start_location text,
    end_location text,
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    status public.trip_status DEFAULT 'assigned'::public.trip_status,
    fuel_used double precision,
    distance_travelled double precision,
    trip_name text,
    client_contact text,
    origin text,
    destination text,
    via_points jsonb,
    pickup_time timestamp without time zone,
    origin_latitude double precision,
    origin_longitude double precision,
    destination_latitude double precision,
    destination_longitude double precision,
    fleet_manager_id uuid,
    eta double precision
);


ALTER TABLE public.trips OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    user_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    role public.user_role NOT NULL,
    phone_no text,
    created_at timestamp without time zone DEFAULT now(),
    created_by uuid,
    status text DEFAULT 'pending'::text,
    CONSTRAINT users_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'pending'::text, 'blocked'::text])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: vehicle_documents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vehicle_documents (
    document_id uuid DEFAULT gen_random_uuid() NOT NULL,
    vehicle_id uuid NOT NULL,
    document_type text NOT NULL,
    file_url text NOT NULL,
    file_name text,
    file_size integer,
    uploaded_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.vehicle_documents OWNER TO postgres;

--
-- Name: vehicle_locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vehicle_locations (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    vehicle_id uuid,
    latitude double precision,
    longitude double precision,
    "timestamp" timestamp without time zone DEFAULT now()
);


ALTER TABLE public.vehicle_locations OWNER TO postgres;

--
-- Name: vehicles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vehicles (
    vehicle_id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    vin text NOT NULL,
    number_plate text NOT NULL,
    brand text,
    model_year integer,
    status public.vehicle_status DEFAULT 'active'::public.vehicle_status,
    vehicle_name text,
    vehicle_type text,
    fuel_type text,
    manufacturer text,
    model text,
    registration_date date,
    rc_expiry_date date,
    puc_expiry_date date,
    image_url text,
    updated_at timestamp with time zone DEFAULT now(),
    registration_no text,
    created_at timestamp with time zone DEFAULT now(),
    has_rc boolean DEFAULT false,
    has_insurance boolean DEFAULT false,
    has_puc boolean DEFAULT false
);


ALTER TABLE public.vehicles OWNER TO postgres;

--
-- Name: work_order_parts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.work_order_parts (
    work_order_id uuid NOT NULL,
    quantity_required integer NOT NULL,
    cost_at_time numeric(10,2),
    inventory_id uuid NOT NULL,
    CONSTRAINT work_order_parts_quantity_required_check CHECK ((quantity_required > 0))
);


ALTER TABLE public.work_order_parts OWNER TO postgres;

--
-- Name: work_order_reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.work_order_reports (
    report_id uuid DEFAULT gen_random_uuid() NOT NULL,
    work_order_id uuid,
    report_url text NOT NULL,
    report_name text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.work_order_reports OWNER TO postgres;

--
-- Name: work_order_tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.work_order_tasks (
    task_id uuid DEFAULT gen_random_uuid() NOT NULL,
    work_order_id uuid,
    description character varying NOT NULL,
    is_completed boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.work_order_tasks OWNER TO postgres;

--
-- Name: work_orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.work_orders (
    work_order_id uuid DEFAULT gen_random_uuid() NOT NULL,
    priority public.work_order_priority DEFAULT 'Low'::public.work_order_priority,
    status public.work_order_status DEFAULT 'Pending'::public.work_order_status,
    issue_title character varying NOT NULL,
    issue_description text,
    hours_worked numeric(5,2) DEFAULT 0.00,
    est_cost numeric(10,2) DEFAULT 0.00,
    internal_notes text,
    maintenance_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_approved boolean DEFAULT false NOT NULL,
    images text[],
    vehicle_id uuid NOT NULL,
    maintenance_personnel_id uuid
);


ALTER TABLE public.work_orders OWNER TO postgres;

--
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);


--
-- Name: chat_participants chat_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_pkey PRIMARY KEY (chat_room_id, user_id);


--
-- Name: chat_rooms chat_rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_rooms
    ADD CONSTRAINT chat_rooms_pkey PRIMARY KEY (id);


--
-- Name: driver_reports driver_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_reports
    ADD CONSTRAINT driver_reports_pkey PRIMARY KEY (id);


--
-- Name: drivers drivers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_pkey PRIMARY KEY (driver_id);


--
-- Name: drivers drivers_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_user_id_key UNIQUE (user_id);


--
-- Name: geofence_assignments geofence_assignments_geofence_id_vehicle_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.geofence_assignments
    ADD CONSTRAINT geofence_assignments_geofence_id_vehicle_id_key UNIQUE (geofence_id, vehicle_id);


--
-- Name: CONSTRAINT geofence_assignments_geofence_id_vehicle_id_key ON geofence_assignments; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON CONSTRAINT geofence_assignments_geofence_id_vehicle_id_key ON public.geofence_assignments IS 'Ensures a vehicle can only be assigned to a geofence once';


--
-- Name: geofence_assignments geofence_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.geofence_assignments
    ADD CONSTRAINT geofence_assignments_pkey PRIMARY KEY (assignment_id);


--
-- Name: geofence_events geofence_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.geofence_events
    ADD CONSTRAINT geofence_events_pkey PRIMARY KEY (event_id);


--
-- Name: geofences geofences_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.geofences
    ADD CONSTRAINT geofences_pkey PRIMARY KEY (geofence_id);


--
-- Name: inspections inspections_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inspections
    ADD CONSTRAINT inspections_pkey PRIMARY KEY (id);


--
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (inventory_id);


--
-- Name: inventory inventory_sku_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_sku_key UNIQUE (sku);


--
-- Name: maintenance_issues maintenance_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenance_issues
    ADD CONSTRAINT maintenance_tasks_pkey PRIMARY KEY (issue_id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: otp_codes otp_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.otp_codes
    ADD CONSTRAINT otp_codes_pkey PRIMARY KEY (id);


--
-- Name: routes routes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT routes_pkey PRIMARY KEY (route_id);


--
-- Name: trips trips_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT trips_pkey PRIMARY KEY (trip_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: vehicle_documents vehicle_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_documents
    ADD CONSTRAINT vehicle_documents_pkey PRIMARY KEY (document_id);


--
-- Name: vehicle_documents vehicle_documents_vehicle_id_document_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_documents
    ADD CONSTRAINT vehicle_documents_vehicle_id_document_type_key UNIQUE (vehicle_id, document_type);


--
-- Name: vehicle_locations vehicle_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_locations
    ADD CONSTRAINT vehicle_locations_pkey PRIMARY KEY (id);


--
-- Name: vehicles vehicles_number_plate_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_number_plate_key UNIQUE (number_plate);


--
-- Name: vehicles vehicles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_pkey PRIMARY KEY (vehicle_id);


--
-- Name: vehicles vehicles_vin_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_vin_key UNIQUE (vin);


--
-- Name: work_order_parts work_order_parts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.work_order_parts
    ADD CONSTRAINT work_order_parts_pkey PRIMARY KEY (work_order_id, inventory_id);


--
-- Name: work_order_reports work_order_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.work_order_reports
    ADD CONSTRAINT work_order_reports_pkey PRIMARY KEY (report_id);


--
-- Name: work_order_tasks work_order_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.work_order_tasks
    ADD CONSTRAINT work_order_tasks_pkey PRIMARY KEY (task_id);


--
-- Name: work_orders work_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT work_orders_pkey PRIMARY KEY (work_order_id);


--
-- Name: idx_assignments_geofence; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_assignments_geofence ON public.geofence_assignments USING btree (geofence_id);


--
-- Name: idx_assignments_vehicle; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_assignments_vehicle ON public.geofence_assignments USING btree (vehicle_id);


--
-- Name: idx_events_geofence; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_geofence ON public.geofence_events USING btree (geofence_id, "timestamp" DESC);


--
-- Name: idx_events_timestamp; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_timestamp ON public.geofence_events USING btree ("timestamp" DESC);


--
-- Name: idx_events_vehicle; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_vehicle ON public.geofence_events USING btree (vehicle_id, "timestamp" DESC);


--
-- Name: idx_geofences_coordinates; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_geofences_coordinates ON public.geofences USING btree (latitude, longitude);


--
-- Name: idx_geofences_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_geofences_type ON public.geofences USING btree (type);


--
-- Name: idx_routes_start_end; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_routes_start_end ON public.routes USING btree (start_location, end_location);


--
-- Name: idx_trips_driver; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_trips_driver ON public.trips USING btree (driver_id);


--
-- Name: idx_trips_fleet_manager; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_trips_fleet_manager ON public.trips USING btree (fleet_manager_id);


--
-- Name: idx_trips_vehicle; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_trips_vehicle ON public.trips USING btree (vehicle_id);


--
-- Name: idx_vehicle_location_vehicle_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_vehicle_location_vehicle_time ON public.vehicle_locations USING btree (vehicle_id, "timestamp" DESC);


--
-- Name: otp_codes_email_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX otp_codes_email_idx ON public.otp_codes USING btree (email);


--
-- Name: vehicle_locations on_vehicle_location_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER on_vehicle_location_update AFTER INSERT OR UPDATE ON public.vehicle_locations FOR EACH ROW EXECUTE FUNCTION public.trigger_monitor_geofences();


--
-- Name: TRIGGER on_vehicle_location_update ON vehicle_locations; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TRIGGER on_vehicle_location_update ON public.vehicle_locations IS 'Automatically invokes geofence monitoring when vehicle locations are inserted or updated.
Ensures entry and exit events are detected within 30 seconds (Requirements 6.4, 7.4).';


--
-- Name: vehicles tr_refresh_vehicle_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_refresh_vehicle_updated_at BEFORE UPDATE ON public.vehicles FOR EACH ROW EXECUTE FUNCTION public.update_vehicle_timestamp();


--
-- Name: work_orders tr_work_order_done; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_work_order_done AFTER UPDATE ON public.work_orders FOR EACH ROW WHEN (((new.status = 'Completed'::public.work_order_status) AND (old.status IS DISTINCT FROM 'Completed'::public.work_order_status))) EXECUTE FUNCTION public.fn_cleanup_after_maintenance();


--
-- Name: vehicle_documents trg_sync_vehicle_docs; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_sync_vehicle_docs AFTER INSERT OR DELETE ON public.vehicle_documents FOR EACH ROW EXECUTE FUNCTION public.update_vehicle_doc_flags();


--
-- Name: work_order_parts trigger_manage_inventory_levels; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_manage_inventory_levels AFTER INSERT OR DELETE OR UPDATE ON public.work_order_parts FOR EACH ROW EXECUTE FUNCTION public.update_inventory_on_work_order();


--
-- Name: chat_messages chat_messages_chat_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_chat_room_id_fkey FOREIGN KEY (chat_room_id) REFERENCES public.chat_rooms(id) ON DELETE CASCADE;


--
-- Name: chat_messages chat_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(user_id);


--
-- Name: chat_participants chat_participants_chat_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_chat_room_id_fkey FOREIGN KEY (chat_room_id) REFERENCES public.chat_rooms(id) ON DELETE CASCADE;


--
-- Name: chat_participants chat_participants_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: driver_reports driver_reports_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_reports
    ADD CONSTRAINT driver_reports_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(driver_id) ON DELETE SET NULL;


--
-- Name: driver_reports driver_reports_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_reports
    ADD CONSTRAINT driver_reports_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trips(trip_id) ON DELETE SET NULL;


--
-- Name: driver_reports driver_reports_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_reports
    ADD CONSTRAINT driver_reports_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id) ON DELETE SET NULL;


--
-- Name: drivers drivers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: geofence_assignments geofence_assignments_geofence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.geofence_assignments
    ADD CONSTRAINT geofence_assignments_geofence_id_fkey FOREIGN KEY (geofence_id) REFERENCES public.geofences(geofence_id) ON DELETE CASCADE;


--
-- Name: geofence_events geofence_events_geofence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.geofence_events
    ADD CONSTRAINT geofence_events_geofence_id_fkey FOREIGN KEY (geofence_id) REFERENCES public.geofences(geofence_id) ON DELETE CASCADE;


--
-- Name: inspections inspections_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inspections
    ADD CONSTRAINT inspections_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trips(trip_id) ON DELETE CASCADE;


--
-- Name: maintenance_issues maintenance_tasks_maintenance_personnel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenance_issues
    ADD CONSTRAINT maintenance_tasks_maintenance_personnel_id_fkey FOREIGN KEY (maintenance_personnel_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: maintenance_issues maintenance_tasks_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maintenance_issues
    ADD CONSTRAINT maintenance_tasks_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id) ON DELETE CASCADE;


--
-- Name: trips trips_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT trips_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(driver_id) ON DELETE SET NULL;


--
-- Name: trips trips_fleet_manager_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT trips_fleet_manager_id_fkey FOREIGN KEY (fleet_manager_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: trips trips_route_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT trips_route_id_fkey FOREIGN KEY (route_id) REFERENCES public.routes(route_id) ON DELETE SET NULL;


--
-- Name: trips trips_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT trips_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id) ON DELETE SET NULL;


--
-- Name: users users_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: vehicle_documents vehicle_documents_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_documents
    ADD CONSTRAINT vehicle_documents_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id) ON DELETE CASCADE;


--
-- Name: vehicle_locations vehicle_locations_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicle_locations
    ADD CONSTRAINT vehicle_locations_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id) ON DELETE CASCADE;


--
-- Name: work_order_parts work_order_parts_inventory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.work_order_parts
    ADD CONSTRAINT work_order_parts_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES public.inventory(inventory_id);


--
-- Name: work_orders work_orders_maintenance_personnel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT work_orders_maintenance_personnel_id_fkey FOREIGN KEY (maintenance_personnel_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: work_orders work_orders_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT work_orders_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id);


--
-- Name: inventory Allow delete for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow delete for all users" ON public.inventory FOR DELETE USING (true);


--
-- Name: vehicle_documents Allow delete vehicle documents; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow delete vehicle documents" ON public.vehicle_documents FOR DELETE TO anon USING (true);


--
-- Name: trips Allow insert for all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow insert for all" ON public.trips FOR INSERT WITH CHECK (true);


--
-- Name: inventory Allow insert for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow insert for all users" ON public.inventory FOR INSERT WITH CHECK (true);


--
-- Name: users Allow insert for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow insert for authenticated users" ON public.users FOR INSERT TO authenticated WITH CHECK ((auth.uid() = created_by));


--
-- Name: vehicle_documents Allow insert vehicle documents; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow insert vehicle documents" ON public.vehicle_documents FOR INSERT TO anon WITH CHECK (true);


--
-- Name: work_order_parts Allow inserts for all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow inserts for all" ON public.work_order_parts FOR INSERT WITH CHECK (true);


--
-- Name: work_order_tasks Allow inserts for all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow inserts for all" ON public.work_order_tasks FOR INSERT WITH CHECK (true);


--
-- Name: work_order_tasks Allow public delete access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public delete access" ON public.work_order_tasks FOR DELETE USING (true);


--
-- Name: work_order_parts Allow public delete access on work_order_parts; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public delete access on work_order_parts" ON public.work_order_parts FOR DELETE USING (true);


--
-- Name: work_order_tasks Allow public delete access on work_order_tasks; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public delete access on work_order_tasks" ON public.work_order_tasks FOR DELETE USING (true);


--
-- Name: work_order_tasks Allow public delete access on work_orders; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public delete access on work_orders" ON public.work_order_tasks FOR DELETE USING (true);


--
-- Name: vehicle_locations Allow public insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public insert" ON public.vehicle_locations FOR INSERT WITH CHECK (true);


--
-- Name: work_order_tasks Allow public insert access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public insert access" ON public.work_order_tasks FOR INSERT WITH CHECK (true);


--
-- Name: work_order_parts Allow public insert access on work_order_parts; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public insert access on work_order_parts" ON public.work_order_parts FOR INSERT WITH CHECK (true);


--
-- Name: work_order_tasks Allow public insert access on work_order_tasks; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public insert access on work_order_tasks" ON public.work_order_tasks FOR INSERT WITH CHECK (true);


--
-- Name: work_order_tasks Allow public insert access on work_orders; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public insert access on work_orders" ON public.work_order_tasks FOR INSERT WITH CHECK (true);


--
-- Name: notifications Allow public inserts; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public inserts" ON public.notifications FOR INSERT WITH CHECK (true);


--
-- Name: work_order_reports Allow public inserts to reports table; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public inserts to reports table" ON public.work_order_reports FOR INSERT WITH CHECK (true);


--
-- Name: inventory Allow public read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read" ON public.inventory FOR SELECT USING (true);


--
-- Name: work_order_tasks Allow public read access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read access" ON public.work_order_tasks FOR SELECT USING (true);


--
-- Name: work_order_tasks Allow public read access on work_order; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read access on work_order" ON public.work_order_tasks FOR SELECT USING (true);


--
-- Name: work_order_parts Allow public read access on work_order_parts; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read access on work_order_parts" ON public.work_order_parts FOR SELECT USING (true);


--
-- Name: work_order_tasks Allow public read access on work_order_tasks; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read access on work_order_tasks" ON public.work_order_tasks FOR SELECT USING (true);


--
-- Name: work_order_reports Allow public select on reports table; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public select on reports table" ON public.work_order_reports FOR SELECT USING (true);


--
-- Name: vehicle_locations Allow public update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public update" ON public.vehicle_locations FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: work_order_tasks Allow public update access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public update access" ON public.work_order_tasks FOR UPDATE USING (true);


--
-- Name: work_order_parts Allow public update access on work_order_parts; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public update access on work_order_parts" ON public.work_order_parts FOR UPDATE USING (true);


--
-- Name: work_order_tasks Allow public update access on work_order_tasks; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public update access on work_order_tasks" ON public.work_order_tasks FOR UPDATE USING (true);


--
-- Name: work_order_tasks Allow public update access on work_orders; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public update access on work_orders" ON public.work_order_tasks FOR UPDATE USING (true);


--
-- Name: notifications Allow public updates; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public updates" ON public.notifications FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: inventory Allow read access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow read access" ON public.inventory FOR SELECT USING (true);


--
-- Name: vehicle_documents Allow read vehicle documents; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow read vehicle documents" ON public.vehicle_documents FOR SELECT TO anon USING (true);


--
-- Name: trips Allow select for all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow select for all" ON public.trips FOR SELECT USING (true);


--
-- Name: vehicles Allow select for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow select for authenticated users" ON public.vehicles FOR SELECT TO authenticated USING (true);


--
-- Name: inventory Allow update for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow update for all users" ON public.inventory FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: vehicle_documents Allow update vehicle documents; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow update vehicle documents" ON public.vehicle_documents FOR UPDATE TO anon USING (true) WITH CHECK (true);


--
-- Name: vehicles Allow updates for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow updates for authenticated users" ON public.vehicles FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: driver_reports Drivers can insert their own reports; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Drivers can insert their own reports" ON public.driver_reports FOR INSERT TO authenticated WITH CHECK ((driver_id IN ( SELECT drivers.driver_id
   FROM public.drivers
  WHERE (drivers.user_id = auth.uid()))));


--
-- Name: drivers Enable delete for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable delete for all users" ON public.drivers FOR DELETE USING (true);


--
-- Name: drivers Enable insert for authenticated users only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users only" ON public.drivers FOR INSERT WITH CHECK (true);


--
-- Name: drivers Enable read access for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all users" ON public.drivers FOR SELECT USING (true);


--
-- Name: drivers Enable update for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable update for all users" ON public.drivers FOR UPDATE USING (true);


--
-- Name: work_orders Full Access Policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Full Access Policy" ON public.work_orders USING (true) WITH CHECK (true);


--
-- Name: users Managers can delete staff; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Managers can delete staff" ON public.users FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.users users_1
  WHERE ((users_1.user_id = auth.uid()) AND (users_1.role = 'fleet_manager'::public.user_role)))));


--
-- Name: users Managers can update any user; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Managers can update any user" ON public.users FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.users manager_record
  WHERE ((manager_record.user_id = auth.uid()) AND (manager_record.role = 'fleet_manager'::public.user_role)))));


--
-- Name: maintenance_issues Public delete maintenance issues; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public delete maintenance issues" ON public.maintenance_issues FOR DELETE USING (true);


--
-- Name: maintenance_issues Public insert maintenance issues; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public insert maintenance issues" ON public.maintenance_issues FOR INSERT WITH CHECK (true);


--
-- Name: maintenance_issues Public read maintenance issues; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public read maintenance issues" ON public.maintenance_issues FOR SELECT USING (true);


--
-- Name: maintenance_issues Public update maintenance issues; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public update maintenance issues" ON public.maintenance_issues FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: users User can update own status; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "User can update own status" ON public.users FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: notifications Users can delete own notifications; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can delete own notifications" ON public.notifications FOR DELETE TO authenticated USING ((auth.uid() = recipient_id));


--
-- Name: notifications Users can read own notifications; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can read own notifications" ON public.notifications FOR SELECT USING (true);


--
-- Name: users Users can view own data; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view own data" ON public.users FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: routes allow_select_routes; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY allow_select_routes ON public.routes FOR SELECT TO anon USING (true);


--
-- Name: chat_messages; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: chat_participants; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.chat_participants ENABLE ROW LEVEL SECURITY;

--
-- Name: chat_participants chat_participants_delete_all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY chat_participants_delete_all ON public.chat_participants FOR DELETE USING (true);


--
-- Name: chat_participants chat_participants_insert_all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY chat_participants_insert_all ON public.chat_participants FOR INSERT WITH CHECK (true);


--
-- Name: chat_participants chat_participants_select_all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY chat_participants_select_all ON public.chat_participants FOR SELECT USING (true);


--
-- Name: chat_participants chat_participants_update_all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY chat_participants_update_all ON public.chat_participants FOR UPDATE USING (true);


--
-- Name: chat_rooms; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;

--
-- Name: chat_rooms chat_rooms_delete_all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY chat_rooms_delete_all ON public.chat_rooms FOR DELETE USING (true);


--
-- Name: chat_rooms chat_rooms_insert_all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY chat_rooms_insert_all ON public.chat_rooms FOR INSERT WITH CHECK (true);


--
-- Name: chat_rooms chat_rooms_select_all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY chat_rooms_select_all ON public.chat_rooms FOR SELECT USING (true);


--
-- Name: chat_rooms chat_rooms_update_all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY chat_rooms_update_all ON public.chat_rooms FOR UPDATE USING (true);


--
-- Name: driver_reports; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.driver_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: drivers; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;

--
-- Name: drivers drivers_select_for_app; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY drivers_select_for_app ON public.drivers FOR SELECT TO authenticated, anon USING (true);


--
-- Name: users fleet_manager_can_insert_users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY fleet_manager_can_insert_users ON public.users FOR INSERT TO authenticated, anon WITH CHECK (true);


--
-- Name: geofence_assignments; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.geofence_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: geofence_assignments geofence_assignments_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY geofence_assignments_delete ON public.geofence_assignments FOR DELETE TO authenticated USING (public.is_fleet_manager());


--
-- Name: geofence_assignments geofence_assignments_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY geofence_assignments_insert ON public.geofence_assignments FOR INSERT TO authenticated WITH CHECK (public.is_fleet_manager());


--
-- Name: geofence_assignments geofence_assignments_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY geofence_assignments_select ON public.geofence_assignments FOR SELECT TO authenticated USING (true);


--
-- Name: geofence_events; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.geofence_events ENABLE ROW LEVEL SECURITY;

--
-- Name: geofence_events geofence_events_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY geofence_events_select ON public.geofence_events FOR SELECT TO authenticated USING (true);


--
-- Name: geofences; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.geofences ENABLE ROW LEVEL SECURITY;

--
-- Name: geofences geofences_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY geofences_delete ON public.geofences FOR DELETE TO authenticated USING (public.is_fleet_manager());


--
-- Name: geofences geofences_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY geofences_insert ON public.geofences FOR INSERT TO authenticated WITH CHECK (public.is_fleet_manager());


--
-- Name: geofences geofences_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY geofences_select ON public.geofences FOR SELECT TO authenticated USING (true);


--
-- Name: geofences geofences_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY geofences_update ON public.geofences FOR UPDATE TO authenticated USING (public.is_fleet_manager()) WITH CHECK (public.is_fleet_manager());


--
-- Name: inspections; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.inspections ENABLE ROW LEVEL SECURITY;

--
-- Name: inventory; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;

--
-- Name: maintenance_issues; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.maintenance_issues ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: otp_codes; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

--
-- Name: chat_messages read messages; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "read messages" ON public.chat_messages FOR SELECT USING (true);


--
-- Name: routes; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;

--
-- Name: routes routes: authenticated insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "routes: authenticated insert" ON public.routes FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: routes routes: authenticated select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "routes: authenticated select" ON public.routes FOR SELECT TO authenticated USING (true);


--
-- Name: routes routes: authenticated update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "routes: authenticated update" ON public.routes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: chat_messages send messages; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "send messages" ON public.chat_messages FOR INSERT WITH CHECK (true);


--
-- Name: driver_reports simulator_insert_driver_reports; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY simulator_insert_driver_reports ON public.driver_reports FOR INSERT TO anon WITH CHECK (true);


--
-- Name: vehicle_locations simulator_insert_vehicle_locations; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY simulator_insert_vehicle_locations ON public.vehicle_locations FOR INSERT TO anon WITH CHECK (true);


--
-- Name: vehicle_locations simulator_select_vehicle_locations; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY simulator_select_vehicle_locations ON public.vehicle_locations FOR SELECT TO anon USING (true);


--
-- Name: trips simulator_update_trips; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY simulator_update_trips ON public.trips FOR UPDATE TO anon USING (true) WITH CHECK (true);


--
-- Name: vehicle_locations simulator_update_vehicle_locations; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY simulator_update_vehicle_locations ON public.vehicle_locations FOR UPDATE TO anon USING (true) WITH CHECK (true);


--
-- Name: trips; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

--
-- Name: trips trips_select_for_app; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY trips_select_for_app ON public.trips FOR SELECT TO authenticated, anon USING (true);


--
-- Name: trips trips_update_for_driver; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY trips_update_for_driver ON public.trips FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.drivers d
  WHERE ((d.driver_id = trips.driver_id) AND (d.user_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.drivers d
  WHERE ((d.driver_id = trips.driver_id) AND (d.user_id = auth.uid())))));


--
-- Name: chat_messages update messages; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "update messages" ON public.chat_messages FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_select_for_app; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY users_select_for_app ON public.users FOR SELECT TO authenticated, anon USING (true);


--
-- Name: vehicle_documents; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.vehicle_documents ENABLE ROW LEVEL SECURITY;

--
-- Name: vehicle_locations; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.vehicle_locations ENABLE ROW LEVEL SECURITY;

--
-- Name: vehicle_locations vehicle_locations_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY vehicle_locations_select_public ON public.vehicle_locations FOR SELECT USING (true);


--
-- Name: vehicles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

--
-- Name: vehicles vehicles_select_for_app; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY vehicles_select_for_app ON public.vehicles FOR SELECT TO authenticated, anon USING (true);


--
-- Name: work_order_parts; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.work_order_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: work_order_reports; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.work_order_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: work_order_tasks; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.work_order_tasks ENABLE ROW LEVEL SECURITY;

--
-- Name: work_orders; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.work_orders ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION fn_cleanup_after_maintenance(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_cleanup_after_maintenance() TO anon;
GRANT ALL ON FUNCTION public.fn_cleanup_after_maintenance() TO authenticated;
GRANT ALL ON FUNCTION public.fn_cleanup_after_maintenance() TO service_role;


--
-- Name: FUNCTION handle_user_confirmed(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.handle_user_confirmed() TO anon;
GRANT ALL ON FUNCTION public.handle_user_confirmed() TO authenticated;
GRANT ALL ON FUNCTION public.handle_user_confirmed() TO service_role;


--
-- Name: FUNCTION is_fleet_manager(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.is_fleet_manager() TO anon;
GRANT ALL ON FUNCTION public.is_fleet_manager() TO authenticated;
GRANT ALL ON FUNCTION public.is_fleet_manager() TO service_role;


--
-- Name: FUNCTION rls_auto_enable(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.rls_auto_enable() TO anon;
GRANT ALL ON FUNCTION public.rls_auto_enable() TO authenticated;
GRANT ALL ON FUNCTION public.rls_auto_enable() TO service_role;


--
-- Name: FUNCTION trigger_monitor_geofences(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.trigger_monitor_geofences() TO anon;
GRANT ALL ON FUNCTION public.trigger_monitor_geofences() TO authenticated;
GRANT ALL ON FUNCTION public.trigger_monitor_geofences() TO service_role;


--
-- Name: FUNCTION update_inventory_on_work_order(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_inventory_on_work_order() TO anon;
GRANT ALL ON FUNCTION public.update_inventory_on_work_order() TO authenticated;
GRANT ALL ON FUNCTION public.update_inventory_on_work_order() TO service_role;


--
-- Name: FUNCTION update_updated_at_column(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_updated_at_column() TO anon;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO authenticated;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO service_role;


--
-- Name: FUNCTION update_vehicle_doc_flags(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_vehicle_doc_flags() TO anon;
GRANT ALL ON FUNCTION public.update_vehicle_doc_flags() TO authenticated;
GRANT ALL ON FUNCTION public.update_vehicle_doc_flags() TO service_role;


--
-- Name: FUNCTION update_vehicle_timestamp(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_vehicle_timestamp() TO anon;
GRANT ALL ON FUNCTION public.update_vehicle_timestamp() TO authenticated;
GRANT ALL ON FUNCTION public.update_vehicle_timestamp() TO service_role;


--
-- Name: TABLE chat_messages; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.chat_messages TO anon;
GRANT ALL ON TABLE public.chat_messages TO authenticated;
GRANT ALL ON TABLE public.chat_messages TO service_role;


--
-- Name: TABLE chat_participants; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.chat_participants TO anon;
GRANT ALL ON TABLE public.chat_participants TO authenticated;
GRANT ALL ON TABLE public.chat_participants TO service_role;


--
-- Name: TABLE chat_rooms; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.chat_rooms TO anon;
GRANT ALL ON TABLE public.chat_rooms TO authenticated;
GRANT ALL ON TABLE public.chat_rooms TO service_role;


--
-- Name: TABLE driver_reports; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.driver_reports TO anon;
GRANT ALL ON TABLE public.driver_reports TO authenticated;
GRANT ALL ON TABLE public.driver_reports TO service_role;


--
-- Name: TABLE drivers; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.drivers TO anon;
GRANT ALL ON TABLE public.drivers TO authenticated;
GRANT ALL ON TABLE public.drivers TO service_role;


--
-- Name: TABLE geofence_assignments; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.geofence_assignments TO anon;
GRANT ALL ON TABLE public.geofence_assignments TO authenticated;
GRANT ALL ON TABLE public.geofence_assignments TO service_role;


--
-- Name: TABLE geofence_events; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.geofence_events TO anon;
GRANT ALL ON TABLE public.geofence_events TO authenticated;
GRANT ALL ON TABLE public.geofence_events TO service_role;


--
-- Name: TABLE geofences; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.geofences TO anon;
GRANT ALL ON TABLE public.geofences TO authenticated;
GRANT ALL ON TABLE public.geofences TO service_role;


--
-- Name: TABLE inspections; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.inspections TO anon;
GRANT ALL ON TABLE public.inspections TO authenticated;
GRANT ALL ON TABLE public.inspections TO service_role;


--
-- Name: TABLE inventory; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.inventory TO anon;
GRANT ALL ON TABLE public.inventory TO authenticated;
GRANT ALL ON TABLE public.inventory TO service_role;


--
-- Name: TABLE maintenance_issues; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.maintenance_issues TO anon;
GRANT ALL ON TABLE public.maintenance_issues TO authenticated;
GRANT ALL ON TABLE public.maintenance_issues TO service_role;


--
-- Name: TABLE notifications; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.notifications TO anon;
GRANT ALL ON TABLE public.notifications TO authenticated;
GRANT ALL ON TABLE public.notifications TO service_role;


--
-- Name: TABLE otp_codes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.otp_codes TO anon;
GRANT ALL ON TABLE public.otp_codes TO authenticated;
GRANT ALL ON TABLE public.otp_codes TO service_role;


--
-- Name: SEQUENCE otp_codes_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.otp_codes_id_seq TO anon;
GRANT ALL ON SEQUENCE public.otp_codes_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.otp_codes_id_seq TO service_role;


--
-- Name: TABLE routes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.routes TO anon;
GRANT ALL ON TABLE public.routes TO authenticated;
GRANT ALL ON TABLE public.routes TO service_role;


--
-- Name: TABLE trips; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.trips TO anon;
GRANT ALL ON TABLE public.trips TO authenticated;
GRANT ALL ON TABLE public.trips TO service_role;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users TO anon;
GRANT ALL ON TABLE public.users TO authenticated;
GRANT ALL ON TABLE public.users TO service_role;


--
-- Name: TABLE vehicle_documents; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vehicle_documents TO anon;
GRANT ALL ON TABLE public.vehicle_documents TO authenticated;
GRANT ALL ON TABLE public.vehicle_documents TO service_role;


--
-- Name: TABLE vehicle_locations; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vehicle_locations TO anon;
GRANT ALL ON TABLE public.vehicle_locations TO authenticated;
GRANT ALL ON TABLE public.vehicle_locations TO service_role;


--
-- Name: TABLE vehicles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vehicles TO anon;
GRANT ALL ON TABLE public.vehicles TO authenticated;
GRANT ALL ON TABLE public.vehicles TO service_role;


--
-- Name: TABLE work_order_parts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.work_order_parts TO anon;
GRANT ALL ON TABLE public.work_order_parts TO authenticated;
GRANT ALL ON TABLE public.work_order_parts TO service_role;


--
-- Name: TABLE work_order_reports; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.work_order_reports TO anon;
GRANT ALL ON TABLE public.work_order_reports TO authenticated;
GRANT ALL ON TABLE public.work_order_reports TO service_role;


--
-- Name: TABLE work_order_tasks; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.work_order_tasks TO anon;
GRANT ALL ON TABLE public.work_order_tasks TO authenticated;
GRANT ALL ON TABLE public.work_order_tasks TO service_role;


--
-- Name: TABLE work_orders; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.work_orders TO anon;
GRANT ALL ON TABLE public.work_orders TO authenticated;
GRANT ALL ON TABLE public.work_orders TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

\unrestrict d7zZFH4MCumKxuljqrqVOSwHVMltIsPUBAZHNtAQEgI5kQCsZS5YxsMIDhKslcF

