--
-- PostgreSQL database dump
--

-- Dumped from database version 10.10
-- Dumped by pg_dump version 10.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

SET search_path = public, pg_catalog;

--
-- Name: audit_typ; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE audit_typ AS ENUM (
    'All',
    'Special'
);


--
-- Name: fake_id(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fake_id(id text) RETURNS bigint
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT hex_to_int(concat(left(md5(substring(id from '(.*?)(?:-\d+)?$')), 10), coalesce(
    lpad(to_hex(substring(id from '.*-(\d+)$')::BIGINT), 4, '0')
)))
$_$;


--
-- Name: fake_macaddr(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fake_macaddr(id text) RETURNS macaddr
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT left(md5(id), 12)::macaddr;
$$;


--
-- Name: generate_date_series(timestamp with time zone, timestamp with time zone, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION generate_date_series(from_date timestamp with time zone, to_date timestamp with time zone, tz_time text, intval text) RETURNS SETOF timestamp with time zone
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    r TIMESTAMPTZ;
BEGIN
    PERFORM set_config('timezone', 'UTC', FALSE);
    PERFORM set_config('timezone', (tz_time::timestamptz - tz_time::timestamp)::text, FALSE);
    FOR r IN SELECT
        date_trunc(intval, series)
    FROM generate_series(from_date , to_date-'1s'::INTERVAL, concat('1 ', intval)::interval) AS series LOOP
        RETURN NEXT r;
    END LOOP;
    RETURN;
END;
$$;


--
-- Name: hex_to_int(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION hex_to_int(id text) RETURNS bigint
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
  result BIGINT;
BEGIN
  EXECUTE 'SELECT x''' || id || '''::bigint' INTO result;
  RETURN result;
END;
$$;


--
-- Name: id_generator(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION id_generator() RETURNS bigint
    LANGUAGE sql
    AS $$
SELECT
			(((EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT - 946684800000) << 22) |
			(1 << 12) |
			(nextval('global_id_sequence') % 4096)
$$;


--
-- Name: id_generator_msec(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION id_generator_msec(msec bigint) RETURNS bigint
    LANGUAGE sql
    AS $$
SELECT
			((msec - 946684800000) << 22) |
			(1 << 12) |
			(nextval('global_id_sequence') % 4096)
$$;


--
-- Name: id_generator_sec(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION id_generator_sec(sec bigint) RETURNS bigint
    LANGUAGE sql
    AS $$
SELECT
			((sec * 1000 + ((EXTRACT(MILLISECONDS FROM clock_timestamp()) * 1000)::BIGINT % 1000) - 946684800000) << 22) |
			(1 << 12) |
			(nextval('global_id_sequence') % 4096)
$$;


--
-- Name: to_jsonb_ext(anyelement); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION to_jsonb_ext(value anyelement) RETURNS jsonb
    LANGUAGE sql
    AS $$
SELECT coalesce(to_jsonb(value), '{}'::jsonb)
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: app; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE app (
    app_instance_id bigint NOT NULL,
    enterprise_id bigint NOT NULL,
    access_key text NOT NULL,
    access_secret text NOT NULL,
    app_id bigint NOT NULL,
    note text,
    bucket text,
    endpoint text,
    secure boolean DEFAULT true
);


--
-- Name: audit_annual_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_annual_plans (
    id bigint DEFAULT id_generator() NOT NULL,
    app_instance_id bigint NOT NULL,
    sn text NOT NULL,
    year text NOT NULL,
    file_sn text NOT NULL,
    file_name text NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    attaches jsonb
);


--
-- Name: TABLE audit_annual_plans; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE audit_annual_plans IS '年度审核计划表';


--
-- Name: COLUMN audit_annual_plans.app_instance_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_annual_plans.app_instance_id IS 'app 实例id';


--
-- Name: COLUMN audit_annual_plans.sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_annual_plans.sn IS '年度计划编号';


--
-- Name: COLUMN audit_annual_plans.year; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_annual_plans.year IS '年度';


--
-- Name: COLUMN audit_annual_plans.file_sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_annual_plans.file_sn IS '文件编号';


--
-- Name: COLUMN audit_annual_plans.file_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_annual_plans.file_name IS '文件名称';


--
-- Name: COLUMN audit_annual_plans.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_annual_plans.created_by IS '创建人';


--
-- Name: COLUMN audit_annual_plans.attaches; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_annual_plans.attaches IS '附件';


--
-- Name: audit_check_lists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_check_lists (
    id bigint DEFAULT id_generator() NOT NULL,
    sn text NOT NULL,
    implement_plan_id bigint,
    audit_project text NOT NULL,
    audit_leader_id bigint NOT NULL,
    onsite_audit_date timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    app_instance_id bigint NOT NULL,
    audited_department_ids bigint[] DEFAULT '{}'::bigint[],
    auditor_ids bigint[] DEFAULT '{}'::bigint[],
    attaches text[] DEFAULT '{}'::text[]
);


--
-- Name: TABLE audit_check_lists; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE audit_check_lists IS '审核检查单';


--
-- Name: COLUMN audit_check_lists.sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_check_lists.sn IS '检查单编号';


--
-- Name: COLUMN audit_check_lists.implement_plan_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_check_lists.implement_plan_id IS '所属实施计划id';


--
-- Name: COLUMN audit_check_lists.audit_project; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_check_lists.audit_project IS '审核项目';


--
-- Name: COLUMN audit_check_lists.audit_leader_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_check_lists.audit_leader_id IS '审核组长';


--
-- Name: COLUMN audit_check_lists.onsite_audit_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_check_lists.onsite_audit_date IS '现场审核日期';


--
-- Name: COLUMN audit_check_lists.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_check_lists.created_by IS '创建者';


--
-- Name: COLUMN audit_check_lists.app_instance_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_check_lists.app_instance_id IS '申请的平台的id';


--
-- Name: audit_department_evaluations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_department_evaluations (
    id bigint DEFAULT id_generator() NOT NULL,
    implement_plan_id bigint NOT NULL,
    audited_department_id bigint NOT NULL,
    remark text,
    accept_auditor text,
    audit_preparation integer DEFAULT 0 NOT NULL,
    audit_attitude integer DEFAULT 0 NOT NULL,
    provide_materials integer DEFAULT 0 NOT NULL,
    safety_consciousness integer DEFAULT 0 NOT NULL,
    continuous_improvement integer DEFAULT 0 NOT NULL,
    department_safety_consciousness integer DEFAULT 0 NOT NULL,
    other text,
    internal_auditor_id bigint NOT NULL,
    audited_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    nonconformity_management_num integer DEFAULT 0 NOT NULL,
    rectification_timeliness integer DEFAULT 0 NOT NULL,
    rectification_serious integer DEFAULT 0 NOT NULL,
    overall_evaluation text,
    audit_leader_id bigint DEFAULT 0 NOT NULL,
    examined_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    app_instance_id bigint NOT NULL,
    sn text NOT NULL,
    deleted boolean DEFAULT false NOT NULL
);


--
-- Name: COLUMN audit_department_evaluations.implement_plan_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.implement_plan_id IS '审核实施计划';


--
-- Name: COLUMN audit_department_evaluations.audited_department_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.audited_department_id IS '受审核部门';


--
-- Name: COLUMN audit_department_evaluations.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.remark IS '备注';


--
-- Name: COLUMN audit_department_evaluations.accept_auditor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.accept_auditor IS '接受审核者';


--
-- Name: COLUMN audit_department_evaluations.audit_preparation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.audit_preparation IS '审核准备的充分性： 0～5';


--
-- Name: COLUMN audit_department_evaluations.audit_attitude; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.audit_attitude IS '对待审核的态度：0～5';


--
-- Name: COLUMN audit_department_evaluations.provide_materials; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.provide_materials IS '提供材料的及时性：0~5';


--
-- Name: COLUMN audit_department_evaluations.safety_consciousness; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.safety_consciousness IS '被审核者的质量安全意识：0~5';


--
-- Name: COLUMN audit_department_evaluations.continuous_improvement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.continuous_improvement IS '持续改进意识:0~5';


--
-- Name: COLUMN audit_department_evaluations.department_safety_consciousness; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.department_safety_consciousness IS '部门总体质量安全意识：0～5';


--
-- Name: COLUMN audit_department_evaluations.other; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.other IS '其他';


--
-- Name: COLUMN audit_department_evaluations.internal_auditor_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.internal_auditor_id IS '内审员id';


--
-- Name: COLUMN audit_department_evaluations.audited_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.audited_at IS '审核日期';


--
-- Name: COLUMN audit_department_evaluations.nonconformity_management_num; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.nonconformity_management_num IS '不符合项数量';


--
-- Name: COLUMN audit_department_evaluations.rectification_timeliness; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.rectification_timeliness IS '整体的及时性：0～5';


--
-- Name: COLUMN audit_department_evaluations.rectification_serious; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.rectification_serious IS '整改的认真程度：0～5';


--
-- Name: COLUMN audit_department_evaluations.overall_evaluation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.overall_evaluation IS '整体的评价';


--
-- Name: COLUMN audit_department_evaluations.audit_leader_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.audit_leader_id IS '审核组长ID';


--
-- Name: COLUMN audit_department_evaluations.examined_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.examined_at IS '验证日期';


--
-- Name: COLUMN audit_department_evaluations.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.created_by IS '创建者';


--
-- Name: COLUMN audit_department_evaluations.app_instance_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.app_instance_id IS '平台的id';


--
-- Name: COLUMN audit_department_evaluations.sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_department_evaluations.sn IS '编号';


--
-- Name: audit_external_nonconformities_correct; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_external_nonconformities_correct (
    id bigint DEFAULT id_generator() NOT NULL,
    correct_measure_sn text NOT NULL,
    actual_desc text NOT NULL,
    type text NOT NULL,
    correct_measure text,
    check_status text,
    effective_check text,
    attaches jsonb,
    status text,
    deleted boolean DEFAULT false NOT NULL,
    app_instance_id bigint NOT NULL,
    created_by bigint NOT NULL,
    auditor_id bigint,
    audited_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    correct_desc text,
    checked_at timestamp with time zone,
    checker_id bigint
);


--
-- Name: TABLE audit_external_nonconformities_correct; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE audit_external_nonconformities_correct IS '不符合项整改措施';


--
-- Name: COLUMN audit_external_nonconformities_correct.correct_measure_sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.correct_measure_sn IS '整改措施编号';


--
-- Name: COLUMN audit_external_nonconformities_correct.actual_desc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.actual_desc IS '不符合项事实描述';


--
-- Name: COLUMN audit_external_nonconformities_correct.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.type IS '类别 纠正:correct,纠正计划:correct_plan';


--
-- Name: COLUMN audit_external_nonconformities_correct.correct_measure; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.correct_measure IS '纠正措施/计划';


--
-- Name: COLUMN audit_external_nonconformities_correct.check_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.check_status IS '举一反三情况';


--
-- Name: COLUMN audit_external_nonconformities_correct.effective_check; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.effective_check IS '受审核方对纠正和纠正措施有效性/纠正和纠正措施计划适宜性的验证';


--
-- Name: COLUMN audit_external_nonconformities_correct.attaches; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.attaches IS '见证材料';


--
-- Name: COLUMN audit_external_nonconformities_correct.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.status IS '状态';


--
-- Name: COLUMN audit_external_nonconformities_correct.auditor_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.auditor_id IS '审核人';


--
-- Name: COLUMN audit_external_nonconformities_correct.audited_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.audited_at IS '审核日期';


--
-- Name: COLUMN audit_external_nonconformities_correct.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.created_at IS '记录创建日期';


--
-- Name: COLUMN audit_external_nonconformities_correct.correct_desc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.correct_desc IS '纠正/纠正计划';


--
-- Name: COLUMN audit_external_nonconformities_correct.checked_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.checked_at IS '验证人审核时间';


--
-- Name: COLUMN audit_external_nonconformities_correct.checker_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_nonconformities_correct.checker_id IS '验证人id';


--
-- Name: audit_external_plan_rectifies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_external_plan_rectifies (
    id bigint DEFAULT id_generator() NOT NULL,
    sn text NOT NULL,
    external_plan_id bigint NOT NULL,
    description text NOT NULL,
    terms_id bigint,
    terms_content text,
    rectify_demand text NOT NULL,
    department_id bigint NOT NULL,
    completed_at timestamp with time zone NOT NULL,
    responsible_id bigint NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    app_instance_id bigint NOT NULL,
    type text NOT NULL,
    is_nonconformity boolean NOT NULL,
    attaches text[] DEFAULT '{}'::text[] NOT NULL
);


--
-- Name: COLUMN audit_external_plan_rectifies.sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plan_rectifies.sn IS '编号';


--
-- Name: COLUMN audit_external_plan_rectifies.external_plan_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plan_rectifies.external_plan_id IS '外审计划ID';


--
-- Name: COLUMN audit_external_plan_rectifies.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plan_rectifies.description IS '描述';


--
-- Name: COLUMN audit_external_plan_rectifies.terms_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plan_rectifies.terms_id IS '条款id';


--
-- Name: COLUMN audit_external_plan_rectifies.terms_content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plan_rectifies.terms_content IS '条款内容';


--
-- Name: COLUMN audit_external_plan_rectifies.rectify_demand; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plan_rectifies.rectify_demand IS '整改要求';


--
-- Name: COLUMN audit_external_plan_rectifies.department_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plan_rectifies.department_id IS '涉及部门id';


--
-- Name: COLUMN audit_external_plan_rectifies.completed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plan_rectifies.completed_at IS '完成时间';


--
-- Name: COLUMN audit_external_plan_rectifies.responsible_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plan_rectifies.responsible_id IS '责任人ID';


--
-- Name: COLUMN audit_external_plan_rectifies.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plan_rectifies.created_by IS '创建者';


--
-- Name: COLUMN audit_external_plan_rectifies.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plan_rectifies.type IS '审核类别：second 二方；tripartite 三方；';


--
-- Name: COLUMN audit_external_plan_rectifies.is_nonconformity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plan_rectifies.is_nonconformity IS '是否是不符合项：true是 false不是';


--
-- Name: audit_external_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_external_plans (
    id bigint DEFAULT id_generator() NOT NULL,
    sn text NOT NULL,
    name text NOT NULL,
    annual_plan_id bigint NOT NULL,
    type text NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    app_instance_id bigint NOT NULL,
    auditee text NOT NULL,
    responsible text NOT NULL,
    completed_at timestamp with time zone NOT NULL,
    attaches jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: COLUMN audit_external_plans.sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plans.sn IS '编号';


--
-- Name: COLUMN audit_external_plans.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plans.name IS '审核名称';


--
-- Name: COLUMN audit_external_plans.annual_plan_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plans.annual_plan_id IS '所属年度计划ID';


--
-- Name: COLUMN audit_external_plans.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plans.type IS '审核类别：second 二方；tripartite 三方；';


--
-- Name: COLUMN audit_external_plans.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plans.created_by IS '创建者';


--
-- Name: COLUMN audit_external_plans.app_instance_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plans.app_instance_id IS '申请的平台的ID';


--
-- Name: COLUMN audit_external_plans.auditee; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plans.auditee IS '受审核方名称';


--
-- Name: COLUMN audit_external_plans.responsible; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plans.responsible IS '责任人';


--
-- Name: COLUMN audit_external_plans.completed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_external_plans.completed_at IS '完成时间';


--
-- Name: audit_function_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_function_settings (
    id bigint DEFAULT id_generator() NOT NULL,
    name text NOT NULL,
    description text,
    role_id bigint,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    code text NOT NULL,
    app_instance_id bigint NOT NULL
);


--
-- Name: TABLE audit_function_settings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE audit_function_settings IS '职能设置';


--
-- Name: COLUMN audit_function_settings.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_function_settings.name IS '职能的名字';


--
-- Name: COLUMN audit_function_settings.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_function_settings.description IS '描述';


--
-- Name: COLUMN audit_function_settings.role_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_function_settings.role_id IS '角色id';


--
-- Name: COLUMN audit_function_settings.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_function_settings.code IS '唯一标示';


--
-- Name: audit_implement_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_implement_plans (
    id bigint DEFAULT id_generator() NOT NULL,
    sn text NOT NULL,
    audit_name text NOT NULL,
    annual_plan_id bigint,
    audit_type text NOT NULL,
    audit_leader_id bigint NOT NULL,
    audit_date timestamp with time zone NOT NULL,
    remark text DEFAULT ''::text NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    app_instance_id bigint NOT NULL,
    attaches text[] DEFAULT '{}'::text[]
);


--
-- Name: TABLE audit_implement_plans; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE audit_implement_plans IS '审核实施计划表';


--
-- Name: COLUMN audit_implement_plans.sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_implement_plans.sn IS '实施计划编号';


--
-- Name: COLUMN audit_implement_plans.audit_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_implement_plans.audit_name IS '审核 名称';


--
-- Name: COLUMN audit_implement_plans.annual_plan_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_implement_plans.annual_plan_id IS '所归属年度计划';


--
-- Name: COLUMN audit_implement_plans.audit_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_implement_plans.audit_type IS '审核类别,All:全过程审核,Special:专项审核';


--
-- Name: COLUMN audit_implement_plans.audit_leader_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_implement_plans.audit_leader_id IS '审核组长';


--
-- Name: COLUMN audit_implement_plans.audit_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_implement_plans.audit_date IS '计划审核日期';


--
-- Name: COLUMN audit_implement_plans.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_implement_plans.remark IS '备注';


--
-- Name: COLUMN audit_implement_plans.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_implement_plans.created_by IS '创建人';


--
-- Name: COLUMN audit_implement_plans.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_implement_plans.created_at IS '创建时间';


--
-- Name: COLUMN audit_implement_plans.app_instance_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_implement_plans.app_instance_id IS '申请的平台的id';


--
-- Name: audit_internal_evaluations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_internal_evaluations (
    id bigint DEFAULT id_generator() NOT NULL,
    internal_auditor_id bigint NOT NULL,
    implement_plan_id bigint NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    app_instance_id bigint NOT NULL,
    sn text NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    evaluation_lists jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: COLUMN audit_internal_evaluations.internal_auditor_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_internal_evaluations.internal_auditor_id IS '内审员id';


--
-- Name: COLUMN audit_internal_evaluations.implement_plan_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_internal_evaluations.implement_plan_id IS '审核实施计划id';


--
-- Name: COLUMN audit_internal_evaluations.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_internal_evaluations.created_by IS '创建者';


--
-- Name: audit_nonconformities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_nonconformities (
    id bigint DEFAULT id_generator() NOT NULL,
    questions_sn text NOT NULL,
    sn text NOT NULL,
    audited_department_id bigint,
    audit_cate text,
    auditor_id bigint,
    severity_cate text,
    accompanying_person text DEFAULT ''::text,
    audit_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    incompatible_factual_desc text,
    incompatible_terms_id bigint,
    incompatible_content text,
    responsible_department_id bigint,
    responsible_department_leader_id bigint,
    audited_department_leader_id bigint,
    audit_team_leader_id bigint,
    audit_status text NOT NULL,
    remark text DEFAULT ''::text,
    app_instance_id bigint NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    responsible_person_id bigint
);


--
-- Name: TABLE audit_nonconformities; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE audit_nonconformities IS '不符合项';


--
-- Name: COLUMN audit_nonconformities.questions_sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.questions_sn IS '问题编号';


--
-- Name: COLUMN audit_nonconformities.sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.sn IS '不符合项编号';


--
-- Name: COLUMN audit_nonconformities.audited_department_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.audited_department_id IS '受审核部门(id)';


--
-- Name: COLUMN audit_nonconformities.audit_cate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.audit_cate IS '类别 systematic:体系性，implementability:实施性';


--
-- Name: COLUMN audit_nonconformities.auditor_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.auditor_id IS '审核员';


--
-- Name: COLUMN audit_nonconformities.severity_cate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.severity_cate IS '严重程度 serious:严重的，normal:一般';


--
-- Name: COLUMN audit_nonconformities.accompanying_person; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.accompanying_person IS '陪同人员';


--
-- Name: COLUMN audit_nonconformities.audit_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.audit_date IS '审核日期';


--
-- Name: COLUMN audit_nonconformities.incompatible_factual_desc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.incompatible_factual_desc IS '不符合项事实描述';


--
-- Name: COLUMN audit_nonconformities.incompatible_terms_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.incompatible_terms_id IS '不符合条款(id)';


--
-- Name: COLUMN audit_nonconformities.incompatible_content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.incompatible_content IS '不符合项内容';


--
-- Name: COLUMN audit_nonconformities.responsible_department_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.responsible_department_id IS '责任部门(id)';


--
-- Name: COLUMN audit_nonconformities.responsible_department_leader_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.responsible_department_leader_id IS '责任部门负责人(id)';


--
-- Name: COLUMN audit_nonconformities.audited_department_leader_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.audited_department_leader_id IS '受审核部门负责人(id)';


--
-- Name: COLUMN audit_nonconformities.audit_team_leader_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.audit_team_leader_id IS '审核组长(id)';


--
-- Name: COLUMN audit_nonconformities.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.remark IS '备注';


--
-- Name: COLUMN audit_nonconformities.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.created_by IS '创建者(id)';


--
-- Name: COLUMN audit_nonconformities.responsible_person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities.responsible_person_id IS '责任人，由审核第三步录入';


--
-- Name: audit_nonconformities_applies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_nonconformities_applies (
    id bigint DEFAULT id_generator() NOT NULL,
    nonconformity_id bigint NOT NULL,
    audit_intent text,
    audit_opinion text,
    cause_analysis text,
    corrective_action_plan text,
    correction_completion_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    rectification_completed text,
    corrective_action text,
    correction_check jsonb,
    app_instance_id bigint NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status text,
    attaches jsonb
);


--
-- Name: TABLE audit_nonconformities_applies; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE audit_nonconformities_applies IS '审核记录表，包括审核状态，纠正方案和验证';


--
-- Name: COLUMN audit_nonconformities_applies.nonconformity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities_applies.nonconformity_id IS '不符合项(id)';


--
-- Name: COLUMN audit_nonconformities_applies.audit_intent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities_applies.audit_intent IS '审核意向,同意:passed,拒绝:refused';


--
-- Name: COLUMN audit_nonconformities_applies.audit_opinion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities_applies.audit_opinion IS '审核意见';


--
-- Name: COLUMN audit_nonconformities_applies.cause_analysis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities_applies.cause_analysis IS '原因分析';


--
-- Name: COLUMN audit_nonconformities_applies.corrective_action_plan; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities_applies.corrective_action_plan IS '纠正措施计划';


--
-- Name: COLUMN audit_nonconformities_applies.correction_completion_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities_applies.correction_completion_date IS '整改完成日期';


--
-- Name: COLUMN audit_nonconformities_applies.rectification_completed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities_applies.rectification_completed IS '整改完成情况';


--
-- Name: COLUMN audit_nonconformities_applies.corrective_action; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities_applies.corrective_action IS '整改计划,纠正措施的跟踪';


--
-- Name: COLUMN audit_nonconformities_applies.correction_check; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities_applies.correction_check IS '验证结果,json';


--
-- Name: COLUMN audit_nonconformities_applies.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities_applies.status IS '执行此审核前的状态';


--
-- Name: COLUMN audit_nonconformities_applies.attaches; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformities_applies.attaches IS '整改附件';


--
-- Name: audit_nonconformity_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_nonconformity_terms (
    id bigint DEFAULT id_generator() NOT NULL,
    accordance text NOT NULL,
    term_sn text NOT NULL,
    term_name text NOT NULL,
    remark text DEFAULT ''::text NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    app_instance_id bigint NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: TABLE audit_nonconformity_terms; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE audit_nonconformity_terms IS '不符合项条款';


--
-- Name: COLUMN audit_nonconformity_terms.accordance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformity_terms.accordance IS '审核依据';


--
-- Name: COLUMN audit_nonconformity_terms.term_sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformity_terms.term_sn IS '条款编号';


--
-- Name: COLUMN audit_nonconformity_terms.term_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformity_terms.term_name IS '条款名称';


--
-- Name: COLUMN audit_nonconformity_terms.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_nonconformity_terms.remark IS '备注';


--
-- Name: audit_questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_questions (
    id bigint DEFAULT id_generator() NOT NULL,
    app_instance_id bigint NOT NULL,
    sn text NOT NULL,
    spec text NOT NULL,
    audited_department_id bigint NOT NULL,
    implement_plan_id bigint,
    incompatible_desc text DEFAULT ''::text,
    match boolean NOT NULL,
    responsible_department_id bigint NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    nonconformity_id bigint
);


--
-- Name: TABLE audit_questions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE audit_questions IS '审核问题清单表';


--
-- Name: COLUMN audit_questions.sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_questions.sn IS '审核问题编号';


--
-- Name: COLUMN audit_questions.spec; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_questions.spec IS '问题描述';


--
-- Name: COLUMN audit_questions.audited_department_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_questions.audited_department_id IS '受审核部门';


--
-- Name: COLUMN audit_questions.implement_plan_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_questions.implement_plan_id IS '所属于实施计划id';


--
-- Name: COLUMN audit_questions.incompatible_desc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_questions.incompatible_desc IS '不符合要素';


--
-- Name: COLUMN audit_questions.match; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_questions.match IS '是否符合';


--
-- Name: COLUMN audit_questions.responsible_department_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_questions.responsible_department_id IS '责任部门id';


--
-- Name: COLUMN audit_questions.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_questions.created_by IS '创建者';


--
-- Name: COLUMN audit_questions.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_questions.created_at IS '创建时间';


--
-- Name: COLUMN audit_questions.nonconformity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_questions.nonconformity_id IS '问题关联的不符合项';


--
-- Name: audit_report_applies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_report_applies (
    id bigint DEFAULT id_generator() NOT NULL,
    report_id bigint NOT NULL,
    status text NOT NULL,
    user_id bigint NOT NULL,
    operator_id bigint NOT NULL,
    remark text,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    step_status text NOT NULL
);


--
-- Name: COLUMN audit_report_applies.report_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_report_applies.report_id IS '审核报告的ID';


--
-- Name: COLUMN audit_report_applies.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_report_applies.status IS '状态：refused 拒绝;passed 通过；';


--
-- Name: COLUMN audit_report_applies.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_report_applies.user_id IS '创建者';


--
-- Name: COLUMN audit_report_applies.operator_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_report_applies.operator_id IS '审核人员';


--
-- Name: COLUMN audit_report_applies.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_report_applies.remark IS '审核意见';


--
-- Name: COLUMN audit_report_applies.step_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_report_applies.step_status IS '总体的审核状态';


--
-- Name: audit_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audit_reports (
    id bigint DEFAULT id_generator() NOT NULL,
    sn text NOT NULL,
    name text NOT NULL,
    implement_plan_id bigint NOT NULL,
    audit_leader_id bigint NOT NULL,
    status text NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    app_instance_id bigint NOT NULL,
    attaches text[] DEFAULT '{}'::text[]
);


--
-- Name: COLUMN audit_reports.sn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_reports.sn IS '报告编号';


--
-- Name: COLUMN audit_reports.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_reports.name IS '报告名称';


--
-- Name: COLUMN audit_reports.implement_plan_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_reports.implement_plan_id IS '审核计划ID';


--
-- Name: COLUMN audit_reports.audit_leader_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_reports.audit_leader_id IS '审核组长ID';


--
-- Name: COLUMN audit_reports.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_reports.status IS '状态：draft 草稿；refused 拒绝;reviewStepQuality 待质检处审核；reviewStepAdmin 待管理员审核；passed 通过；';


--
-- Name: COLUMN audit_reports.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_reports.deleted IS '是否删除：true 是；';


--
-- Name: COLUMN audit_reports.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_reports.user_id IS '创建者ID';


--
-- Name: COLUMN audit_reports.app_instance_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN audit_reports.app_instance_id IS '平台申请的ID';


--
-- Name: document_approval; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE document_approval (
    id bigint DEFAULT id_generator() NOT NULL,
    valid_id bigint NOT NULL,
    depart_id bigint,
    approver_id bigint,
    state text,
    comments text,
    app_instance_id bigint NOT NULL,
    sort integer
);


--
-- Name: TABLE document_approval; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE document_approval IS '审批流程表';


--
-- Name: COLUMN document_approval.valid_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_approval.valid_id IS '体系文件ID';


--
-- Name: COLUMN document_approval.depart_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_approval.depart_id IS '审批部门ID';


--
-- Name: COLUMN document_approval.approver_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_approval.approver_id IS '审批人ID';


--
-- Name: COLUMN document_approval.state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_approval.state IS '审核意向(即审核状态)';


--
-- Name: COLUMN document_approval.comments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_approval.comments IS '审批意见';


--
-- Name: COLUMN document_approval.sort; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_approval.sort IS '审批顺序';


--
-- Name: document_classify_setting; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE document_classify_setting (
    id bigint DEFAULT id_generator() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    app_instance_id bigint,
    deleted integer,
    code integer NOT NULL
);


--
-- Name: TABLE document_classify_setting; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE document_classify_setting IS '文件分类设置';


--
-- Name: COLUMN document_classify_setting.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_classify_setting.name IS '类别名称';


--
-- Name: COLUMN document_classify_setting.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_classify_setting.deleted IS '标记是否删除（0是,1否）';


--
-- Name: COLUMN document_classify_setting.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_classify_setting.code IS '文件序号（自增）';


--
-- Name: document_classify_setting_code_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE document_classify_setting_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_classify_setting_code_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE document_classify_setting_code_seq OWNED BY document_classify_setting.code;


--
-- Name: document_countersign_dept; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE document_countersign_dept (
    id bigint DEFAULT id_generator(),
    depart_id bigint,
    approver_ids bigint[],
    app_instance_id bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    deleted integer
);


--
-- Name: TABLE document_countersign_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE document_countersign_dept IS '会签部门审批表';


--
-- Name: COLUMN document_countersign_dept.depart_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_countersign_dept.depart_id IS '会签部门Id';


--
-- Name: COLUMN document_countersign_dept.approver_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_countersign_dept.approver_ids IS '会审人ID';


--
-- Name: COLUMN document_countersign_dept.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_countersign_dept.created_at IS '创建时间';


--
-- Name: COLUMN document_countersign_dept.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_countersign_dept.deleted IS '是否被删除（0是，1否）';


--
-- Name: document_external; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE document_external (
    id bigint DEFAULT id_generator() NOT NULL,
    name text,
    "time" date DEFAULT CURRENT_DATE,
    level text,
    attachments text[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    app_instance_id bigint
);


--
-- Name: TABLE document_external; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE document_external IS '外来文件管理';


--
-- Name: COLUMN document_external.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_external.name IS '文件名称';


--
-- Name: COLUMN document_external."time"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_external."time" IS '时间';


--
-- Name: COLUMN document_external.level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_external.level IS '级别';


--
-- Name: COLUMN document_external.attachments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_external.attachments IS '附件名称';


--
-- Name: document_function_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE document_function_settings (
    id bigint DEFAULT id_generator(),
    name text NOT NULL,
    description text,
    role_id bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    code text NOT NULL,
    app_instance_id bigint NOT NULL
);


--
-- Name: TABLE document_function_settings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE document_function_settings IS '体系文件职能设置';


--
-- Name: COLUMN document_function_settings.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_function_settings.name IS '职能名称';


--
-- Name: COLUMN document_function_settings.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_function_settings.description IS '描述';


--
-- Name: COLUMN document_function_settings.role_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_function_settings.role_id IS '系统角色';


--
-- Name: COLUMN document_function_settings.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_function_settings.code IS '唯一标识';


--
-- Name: document_valid; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE document_valid (
    id bigint DEFAULT id_generator() NOT NULL,
    number text,
    standard_no text,
    edition text,
    name text,
    type text,
    classify_setting_id bigint,
    background_desc text,
    propose_people text,
    compile_depart_id bigint,
    sign_depart_ids bigint[],
    write_date date DEFAULT CURRENT_DATE,
    writer_id bigint,
    attachments text[],
    effect_date date,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    app_instance_id bigint,
    state text
);


--
-- Name: TABLE document_valid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE document_valid IS '有效体系文件';


--
-- Name: COLUMN document_valid.number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.number IS '文件编号';


--
-- Name: COLUMN document_valid.standard_no; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.standard_no IS '标准号';


--
-- Name: COLUMN document_valid.edition; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.edition IS '版次';


--
-- Name: COLUMN document_valid.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.name IS '体系文件名称';


--
-- Name: COLUMN document_valid.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.type IS '文件类型';


--
-- Name: COLUMN document_valid.classify_setting_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.classify_setting_id IS '文件分类ID';


--
-- Name: COLUMN document_valid.background_desc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.background_desc IS '编辑背景和文件内容简要陈述';


--
-- Name: COLUMN document_valid.propose_people; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.propose_people IS '提出部门/人员';


--
-- Name: COLUMN document_valid.compile_depart_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.compile_depart_id IS '编制部门/人员（部门ID）';


--
-- Name: COLUMN document_valid.sign_depart_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.sign_depart_ids IS '会签部门Ids';


--
-- Name: COLUMN document_valid.write_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.write_date IS '编写日期';


--
-- Name: COLUMN document_valid.writer_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.writer_id IS '编写人（用户ID）';


--
-- Name: COLUMN document_valid.attachments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.attachments IS '附件';


--
-- Name: COLUMN document_valid.effect_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.effect_date IS '生效日期';


--
-- Name: COLUMN document_valid.state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid.state IS '状态';


--
-- Name: document_valid_update; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE document_valid_update (
    id bigint DEFAULT id_generator() NOT NULL,
    valid_id bigint,
    change_reason text,
    change_before_edition text,
    change_after_edition text,
    change_before_statement text,
    change_after_statement text,
    change_person_id bigint,
    change_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    app_instance_id bigint,
    name text
);


--
-- Name: TABLE document_valid_update; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE document_valid_update IS '有效体系文件更改单';


--
-- Name: COLUMN document_valid_update.valid_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid_update.valid_id IS '有效体系文件ID';


--
-- Name: COLUMN document_valid_update.change_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid_update.change_reason IS '变更理由';


--
-- Name: COLUMN document_valid_update.change_before_edition; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid_update.change_before_edition IS '更改前版次';


--
-- Name: COLUMN document_valid_update.change_after_edition; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid_update.change_after_edition IS '更改后版次';


--
-- Name: COLUMN document_valid_update.change_before_statement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid_update.change_before_statement IS '更改前陈述';


--
-- Name: COLUMN document_valid_update.change_after_statement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid_update.change_after_statement IS '更改后陈述';


--
-- Name: COLUMN document_valid_update.change_person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid_update.change_person_id IS '更改人(更改登陆人ID)';


--
-- Name: COLUMN document_valid_update.change_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid_update.change_date IS '更改单提交日期';


--
-- Name: COLUMN document_valid_update.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN document_valid_update.name IS '体系文件名称';


--
-- Name: evaluation_function_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE evaluation_function_settings (
    id bigint DEFAULT id_generator() NOT NULL,
    name text NOT NULL,
    description text,
    role_id bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    code text NOT NULL,
    app_instance_id bigint NOT NULL
);


--
-- Name: TABLE evaluation_function_settings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE evaluation_function_settings IS '职能设置';


--
-- Name: COLUMN evaluation_function_settings.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_function_settings.name IS '职能名称';


--
-- Name: COLUMN evaluation_function_settings.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_function_settings.description IS '描述';


--
-- Name: COLUMN evaluation_function_settings.role_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_function_settings.role_id IS '系统角色';


--
-- Name: evaluation_rectify_plan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE evaluation_rectify_plan (
    id bigint DEFAULT id_generator() NOT NULL,
    evaluation_elements text,
    problem_description text,
    rectify_measures text,
    completion_form text,
    completion_time date,
    attachments text[],
    state text,
    app_instance_id bigint,
    responsible_dept_id bigint,
    created_at timestamp with time zone DEFAULT clock_timestamp(),
    updated_at timestamp with time zone DEFAULT clock_timestamp()
);


--
-- Name: TABLE evaluation_rectify_plan; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE evaluation_rectify_plan IS '现场评估问题的整改及举一反三计划';


--
-- Name: COLUMN evaluation_rectify_plan.evaluation_elements; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_rectify_plan.evaluation_elements IS '评估要素';


--
-- Name: COLUMN evaluation_rectify_plan.problem_description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_rectify_plan.problem_description IS '问题描述';


--
-- Name: COLUMN evaluation_rectify_plan.rectify_measures; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_rectify_plan.rectify_measures IS '整改措施及举一反三要求';


--
-- Name: COLUMN evaluation_rectify_plan.completion_form; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_rectify_plan.completion_form IS '完成形式';


--
-- Name: COLUMN evaluation_rectify_plan.completion_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_rectify_plan.completion_time IS '完成时间';


--
-- Name: COLUMN evaluation_rectify_plan.attachments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_rectify_plan.attachments IS '附件';


--
-- Name: COLUMN evaluation_rectify_plan.state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_rectify_plan.state IS '状态';


--
-- Name: COLUMN evaluation_rectify_plan.responsible_dept_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_rectify_plan.responsible_dept_id IS '责任部门id';


--
-- Name: evaluation_review_form; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE evaluation_review_form (
    id bigint DEFAULT id_generator() NOT NULL,
    evaluation_elements text,
    evaluation_problem text,
    review_results text,
    rectification_measures text,
    responsible_dept_ids bigint[],
    completion_form text,
    completion_time date,
    remarks text,
    attachments text[],
    state text,
    app_instance_id bigint,
    created_at timestamp with time zone DEFAULT clock_timestamp(),
    updated_at timestamp with time zone DEFAULT clock_timestamp()
);


--
-- Name: TABLE evaluation_review_form; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE evaluation_review_form IS '现场评估问题举一反三复查表';


--
-- Name: COLUMN evaluation_review_form.evaluation_elements; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_review_form.evaluation_elements IS '评估要素';


--
-- Name: COLUMN evaluation_review_form.evaluation_problem; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_review_form.evaluation_problem IS '集团现场评估问题';


--
-- Name: COLUMN evaluation_review_form.review_results; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_review_form.review_results IS '复查结果';


--
-- Name: COLUMN evaluation_review_form.rectification_measures; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_review_form.rectification_measures IS '整改措施';


--
-- Name: COLUMN evaluation_review_form.responsible_dept_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_review_form.responsible_dept_ids IS '责任部门id';


--
-- Name: COLUMN evaluation_review_form.completion_form; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_review_form.completion_form IS '完成形式';


--
-- Name: COLUMN evaluation_review_form.completion_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_review_form.completion_time IS '完成时间';


--
-- Name: COLUMN evaluation_review_form.remarks; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_review_form.remarks IS '备注';


--
-- Name: COLUMN evaluation_review_form.attachments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_review_form.attachments IS '附件';


--
-- Name: COLUMN evaluation_review_form.state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_review_form.state IS '状态';


--
-- Name: evaluation_situation_record; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE evaluation_situation_record (
    id bigint DEFAULT id_generator() NOT NULL,
    evaluation_elements text,
    evaluation_time date,
    last_problems_advice text,
    development_situation text,
    current_problems_advice text,
    experience_practice text,
    full_marks text,
    maturity_level text,
    score text,
    evaluator_id bigint,
    team_leader_id bigint,
    attachments text[],
    state text,
    app_instance_id bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: TABLE evaluation_situation_record; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE evaluation_situation_record IS '评估情况记录表';


--
-- Name: COLUMN evaluation_situation_record.evaluation_elements; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.evaluation_elements IS '评估要素及编号';


--
-- Name: COLUMN evaluation_situation_record.evaluation_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.evaluation_time IS '评估时间';


--
-- Name: COLUMN evaluation_situation_record.last_problems_advice; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.last_problems_advice IS '上次评估中发现的主要问题（薄弱环节）及建议';


--
-- Name: COLUMN evaluation_situation_record.development_situation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.development_situation IS '本次评估工作开展情况（含对上次评估发现问题、薄弱环节、建议的真整改落实情况）';


--
-- Name: COLUMN evaluation_situation_record.current_problems_advice; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.current_problems_advice IS '本次评估中发现问题（薄弱环节）及建议';


--
-- Name: COLUMN evaluation_situation_record.experience_practice; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.experience_practice IS '本次评估中发现好的经验和做法';


--
-- Name: COLUMN evaluation_situation_record.full_marks; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.full_marks IS '评估要素的满分值';


--
-- Name: COLUMN evaluation_situation_record.maturity_level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.maturity_level IS '评估要素成熟度等级';


--
-- Name: COLUMN evaluation_situation_record.score; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.score IS '评估要素得分';


--
-- Name: COLUMN evaluation_situation_record.evaluator_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.evaluator_id IS '评估员id
';


--
-- Name: COLUMN evaluation_situation_record.team_leader_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.team_leader_id IS '评估组组长id';


--
-- Name: COLUMN evaluation_situation_record.attachments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.attachments IS '附件';


--
-- Name: COLUMN evaluation_situation_record.state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_situation_record.state IS '状态';


--
-- Name: evaluation_work_plan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE evaluation_work_plan (
    id bigint DEFAULT id_generator() NOT NULL,
    annual text,
    created_by bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    remarks text,
    attachments text[],
    state text,
    app_instance_id bigint,
    relevant_dept_ids bigint[],
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    reviewed_by bigint,
    reviewed_at timestamp with time zone
);


--
-- Name: TABLE evaluation_work_plan; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE evaluation_work_plan IS '自评估工作计划';


--
-- Name: COLUMN evaluation_work_plan.annual; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_work_plan.annual IS '年度';


--
-- Name: COLUMN evaluation_work_plan.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_work_plan.created_by IS '编制人id';


--
-- Name: COLUMN evaluation_work_plan.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_work_plan.created_at IS '编制日期';


--
-- Name: COLUMN evaluation_work_plan.remarks; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_work_plan.remarks IS '备注';


--
-- Name: COLUMN evaluation_work_plan.attachments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_work_plan.attachments IS '附件';


--
-- Name: COLUMN evaluation_work_plan.state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_work_plan.state IS '状态';


--
-- Name: COLUMN evaluation_work_plan.relevant_dept_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_work_plan.relevant_dept_ids IS '分发相关部门id';


--
-- Name: COLUMN evaluation_work_plan.reviewed_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_work_plan.reviewed_by IS '审核人';


--
-- Name: COLUMN evaluation_work_plan.reviewed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN evaluation_work_plan.reviewed_at IS '审核时间';


--
-- Name: general_relationships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE general_relationships (
    id bigint DEFAULT id_generator() NOT NULL,
    relation_type text NOT NULL,
    source_type text NOT NULL,
    source_id bigint NOT NULL,
    target_type text NOT NULL,
    target_id bigint NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: TABLE general_relationships; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE general_relationships IS '通用关联关系';


--
-- Name: global_id_sequence; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE global_id_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: global_serial_numbers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE global_serial_numbers (
    id bigint DEFAULT id_generator() NOT NULL,
    sn text NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    handler_id bigint NOT NULL,
    sequence_rule_id bigint
);


--
-- Name: sequence_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sequence_rules (
    id bigint DEFAULT id_generator() NOT NULL,
    name text DEFAULT ''::text NOT NULL,
    rule jsonb DEFAULT '{}'::jsonb NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    appcode text NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    state smallint DEFAULT 1 NOT NULL
);


--
-- Name: sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sequences (
    id bigint DEFAULT id_generator() NOT NULL,
    scope text NOT NULL,
    number bigint NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: supervise_agency_matter_applies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE supervise_agency_matter_applies (
    id bigint DEFAULT id_generator() NOT NULL,
    reviewer bigint NOT NULL,
    status text NOT NULL,
    agency_matter_id bigint NOT NULL,
    implementer bigint NOT NULL,
    attaches text DEFAULT '{}'::text[] NOT NULL,
    implementation text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: COLUMN supervise_agency_matter_applies.reviewer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matter_applies.reviewer IS '审核人';


--
-- Name: COLUMN supervise_agency_matter_applies.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matter_applies.status IS '审核状态：passed 通过；refused 拒绝；';


--
-- Name: COLUMN supervise_agency_matter_applies.agency_matter_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matter_applies.agency_matter_id IS '代办事项id';


--
-- Name: COLUMN supervise_agency_matter_applies.implementer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matter_applies.implementer IS '落实者';


--
-- Name: COLUMN supervise_agency_matter_applies.attaches; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matter_applies.attaches IS '落实的文件';


--
-- Name: COLUMN supervise_agency_matter_applies.implementation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matter_applies.implementation IS '落实情况';


--
-- Name: supervise_agency_matters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE supervise_agency_matters (
    id bigint DEFAULT id_generator() NOT NULL,
    minute_name text NOT NULL,
    agency_matters text NOT NULL,
    department_id bigint NOT NULL,
    completed_at timestamp with time zone NOT NULL,
    implementation text,
    attaches text DEFAULT '{}'::text[] NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    app_instance_id bigint NOT NULL,
    implementer bigint,
    status text NOT NULL,
    deleted boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE supervise_agency_matters; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE supervise_agency_matters IS '代办事项';


--
-- Name: COLUMN supervise_agency_matters.minute_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matters.minute_name IS '纪要名称';


--
-- Name: COLUMN supervise_agency_matters.agency_matters; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matters.agency_matters IS '代办事项';


--
-- Name: COLUMN supervise_agency_matters.department_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matters.department_id IS '责任部门';


--
-- Name: COLUMN supervise_agency_matters.completed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matters.completed_at IS '完成时间';


--
-- Name: COLUMN supervise_agency_matters.implementation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matters.implementation IS '落实情况';


--
-- Name: COLUMN supervise_agency_matters.implementer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matters.implementer IS '落实者';


--
-- Name: COLUMN supervise_agency_matters.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_agency_matters.status IS '状态：pending待提交;auditing 待审核；passed 通过；refused 拒绝；';


--
-- Name: supervise_job_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE supervise_job_contents (
    id bigint DEFAULT id_generator() NOT NULL,
    thematic_activity_id bigint NOT NULL,
    work_contents text NOT NULL,
    type text NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    department_id bigint NOT NULL,
    completed_at timestamp(6) with time zone NOT NULL,
    attaches text DEFAULT '{}'::text[] NOT NULL,
    deleted boolean DEFAULT false NOT NULL
);


--
-- Name: COLUMN supervise_job_contents.work_contents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_job_contents.work_contents IS '工作内容';


--
-- Name: COLUMN supervise_job_contents.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_job_contents.type IS '类型';


--
-- Name: COLUMN supervise_job_contents.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_job_contents.created_by IS '创建者';


--
-- Name: COLUMN supervise_job_contents.department_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_job_contents.department_id IS '责任部门';


--
-- Name: COLUMN supervise_job_contents.completed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_job_contents.completed_at IS '完成时间';


--
-- Name: COLUMN supervise_job_contents.attaches; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_job_contents.attaches IS '附件';


--
-- Name: supervise_problems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE supervise_problems (
    id bigint DEFAULT id_generator() NOT NULL,
    code character varying(100),
    dept_type character varying(100),
    sur_time timestamp(0) without time zone,
    sur_content character varying(100),
    problem_description character varying(100),
    sur_advice character varying(100),
    improve_progress character varying(100),
    supervisor character varying(100),
    dept_leader character varying(100),
    state character varying(100),
    app_instance_id bigint
);


--
-- Name: COLUMN supervise_problems.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_problems.id IS '质量监督问题id';


--
-- Name: COLUMN supervise_problems.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_problems.code IS '编号';


--
-- Name: COLUMN supervise_problems.dept_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_problems.dept_type IS '部门或型号';


--
-- Name: COLUMN supervise_problems.sur_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_problems.sur_time IS '监督时间';


--
-- Name: COLUMN supervise_problems.sur_content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_problems.sur_content IS '监督内容';


--
-- Name: COLUMN supervise_problems.problem_description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_problems.problem_description IS '主要问题描述';


--
-- Name: COLUMN supervise_problems.sur_advice; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_problems.sur_advice IS '监督意见或建议';


--
-- Name: COLUMN supervise_problems.improve_progress; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_problems.improve_progress IS '改进/纠正措施完成情况';


--
-- Name: COLUMN supervise_problems.supervisor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_problems.supervisor IS '监督人员';


--
-- Name: COLUMN supervise_problems.dept_leader; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_problems.dept_leader IS '部门领导';


--
-- Name: COLUMN supervise_problems.state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_problems.state IS '状态';


--
-- Name: supervise_quality_inspection_notices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE supervise_quality_inspection_notices (
    id bigint DEFAULT id_generator() NOT NULL,
    sn text NOT NULL,
    department_model text NOT NULL,
    supervise_time timestamp with time zone NOT NULL,
    supervise_content text NOT NULL,
    question_desc text NOT NULL,
    opinion_suggest text NOT NULL,
    completed_status text NOT NULL,
    status text NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    audited_by bigint,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    app_instance_id bigint NOT NULL
);


--
-- Name: TABLE supervise_quality_inspection_notices; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE supervise_quality_inspection_notices IS '质量监督通知单';


--
-- Name: COLUMN supervise_quality_inspection_notices.department_model; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspection_notices.department_model IS '部门/型号';


--
-- Name: COLUMN supervise_quality_inspection_notices.supervise_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspection_notices.supervise_time IS '监督时间';


--
-- Name: COLUMN supervise_quality_inspection_notices.supervise_content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspection_notices.supervise_content IS '监督内容';


--
-- Name: COLUMN supervise_quality_inspection_notices.question_desc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspection_notices.question_desc IS '主要问题描述';


--
-- Name: COLUMN supervise_quality_inspection_notices.opinion_suggest; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspection_notices.opinion_suggest IS '监督意见或建议';


--
-- Name: COLUMN supervise_quality_inspection_notices.completed_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspection_notices.completed_status IS '纠正/纠正措施完成情况';


--
-- Name: COLUMN supervise_quality_inspection_notices.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspection_notices.status IS '审核状态';


--
-- Name: COLUMN supervise_quality_inspection_notices.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspection_notices.created_by IS '创建人(监督人员)';


--
-- Name: COLUMN supervise_quality_inspection_notices.audited_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspection_notices.audited_by IS '审核人(部门领导)';


--
-- Name: supervise_quality_inspections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE supervise_quality_inspections (
    id bigint DEFAULT id_generator() NOT NULL,
    question_first text NOT NULL,
    question_second text NOT NULL,
    question_desc text NOT NULL,
    suggest text NOT NULL,
    analogy text,
    responsible_department_id bigint NOT NULL,
    complete_modus text NOT NULL,
    complete_date timestamp without time zone NOT NULL,
    completed_situation text,
    attaches jsonb,
    status text NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    recorded_by bigint,
    audited_by bigint,
    app_instance_id bigint NOT NULL
);


--
-- Name: TABLE supervise_quality_inspections; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE supervise_quality_inspections IS '质量综合检查';


--
-- Name: COLUMN supervise_quality_inspections.question_first; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.question_first IS '问题类别一级';


--
-- Name: COLUMN supervise_quality_inspections.question_second; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.question_second IS '问题类别二级';


--
-- Name: COLUMN supervise_quality_inspections.question_desc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.question_desc IS '问题描述';


--
-- Name: COLUMN supervise_quality_inspections.suggest; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.suggest IS '改进建议';


--
-- Name: COLUMN supervise_quality_inspections.analogy; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.analogy IS '举一反三';


--
-- Name: COLUMN supervise_quality_inspections.responsible_department_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.responsible_department_id IS '责任部门';


--
-- Name: COLUMN supervise_quality_inspections.complete_modus; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.complete_modus IS '完成形式';


--
-- Name: COLUMN supervise_quality_inspections.complete_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.complete_date IS '完成时间';


--
-- Name: COLUMN supervise_quality_inspections.completed_situation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.completed_situation IS '完成情况';


--
-- Name: COLUMN supervise_quality_inspections.attaches; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.attaches IS '附件';


--
-- Name: COLUMN supervise_quality_inspections.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.status IS '流程状态:WaitResponsibleEdit待责任部门编辑,WaitAudited待审核,Passed审核通过,Backed审核退回,Canceled已取消';


--
-- Name: COLUMN supervise_quality_inspections.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.created_by IS '基础信息创建者';


--
-- Name: COLUMN supervise_quality_inspections.recorded_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.recorded_by IS '责任部门录入者';


--
-- Name: COLUMN supervise_quality_inspections.audited_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_quality_inspections.audited_by IS '审核者';


--
-- Name: supervise_special_inspections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE supervise_special_inspections (
    id bigint DEFAULT id_generator() NOT NULL,
    name text NOT NULL,
    category text NOT NULL,
    question_desc text NOT NULL,
    responsible_department_id bigint NOT NULL,
    complete_date timestamp without time zone NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    app_instance_id bigint NOT NULL
);


--
-- Name: TABLE supervise_special_inspections; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE supervise_special_inspections IS '专项监督检查';


--
-- Name: COLUMN supervise_special_inspections.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_special_inspections.name IS '专项名称';


--
-- Name: COLUMN supervise_special_inspections.category; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_special_inspections.category IS '专项类型,建议项suggest,整改项rectify';


--
-- Name: COLUMN supervise_special_inspections.question_desc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_special_inspections.question_desc IS '问题描述';


--
-- Name: COLUMN supervise_special_inspections.responsible_department_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_special_inspections.responsible_department_id IS '责任部门';


--
-- Name: supervise_thematic_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE supervise_thematic_activities (
    id bigint DEFAULT id_generator() NOT NULL,
    name text NOT NULL,
    work_requirements text DEFAULT '{}'::text[],
    work_summaries text DEFAULT '{}'::text[],
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    app_instance_id bigint NOT NULL
);


--
-- Name: COLUMN supervise_thematic_activities.work_requirements; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_thematic_activities.work_requirements IS '工作要求';


--
-- Name: COLUMN supervise_thematic_activities.work_summaries; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_thematic_activities.work_summaries IS '工作总结';


--
-- Name: COLUMN supervise_thematic_activities.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_thematic_activities.created_by IS '创建者';


--
-- Name: COLUMN supervise_thematic_activities.app_instance_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN supervise_thematic_activities.app_instance_id IS '申请的平台的id';


--
-- Name: zero_operation_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE zero_operation_log (
    name text NOT NULL,
    create_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    content text NOT NULL,
    app_instance_id bigint NOT NULL,
    quality_problem_id bigint NOT NULL
);


--
-- Name: COLUMN zero_operation_log.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_operation_log.name IS '操作人';


--
-- Name: COLUMN zero_operation_log.create_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_operation_log.create_at IS '操作时间';


--
-- Name: COLUMN zero_operation_log.content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_operation_log.content IS '操作内容';


--
-- Name: COLUMN zero_operation_log.quality_problem_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_operation_log.quality_problem_id IS '质量问题id';


--
-- Name: zero_problems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE zero_problems (
    id bigint DEFAULT id_generator() NOT NULL,
    name text NOT NULL,
    model text NOT NULL,
    develop_stage text NOT NULL,
    production_batch text NOT NULL,
    problem_time date NOT NULL,
    problem_location text NOT NULL,
    product_name text,
    code_name text,
    product_batches text,
    product_number text,
    discovery_site text,
    report_superior integer NOT NULL,
    problem_find_stage text,
    problem_generation_stage text,
    problem_cause_sort text,
    twolevel_cause_sort text,
    zero_require text,
    droft_duty_unit text,
    state text NOT NULL,
    app_instance_id bigint NOT NULL,
    number text NOT NULL,
    create_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    express text,
    problem_describe text
);


--
-- Name: COLUMN zero_problems.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.name IS '质量问题名称';


--
-- Name: COLUMN zero_problems.model; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.model IS '所属型号';


--
-- Name: COLUMN zero_problems.develop_stage; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.develop_stage IS '研制阶段';


--
-- Name: COLUMN zero_problems.production_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.production_batch IS '生产批次';


--
-- Name: COLUMN zero_problems.problem_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.problem_time IS '发生问题日期';


--
-- Name: COLUMN zero_problems.problem_location; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.problem_location IS '发生问题地点';


--
-- Name: COLUMN zero_problems.product_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.product_name IS '问题产品名称';


--
-- Name: COLUMN zero_problems.code_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.code_name IS '图（代）号';


--
-- Name: COLUMN zero_problems.product_batches; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.product_batches IS '产品批次';


--
-- Name: COLUMN zero_problems.product_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.product_number IS '产品编号';


--
-- Name: COLUMN zero_problems.discovery_site; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.discovery_site IS '发现地点';


--
-- Name: COLUMN zero_problems.report_superior; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.report_superior IS '是否上报上级 0是 1否';


--
-- Name: COLUMN zero_problems.problem_find_stage; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.problem_find_stage IS '研制生产 developProduction,总装测试 finalAssembly,发射场 launchingSite,飞行试验 flightTest,在轨运行 orbitOperation,售后服务 AfterSaleService';


--
-- Name: COLUMN zero_problems.problem_generation_stage; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.problem_generation_stage IS '问题产生阶段 developProduction,总装测试 finalAssembly,发射场 launchingSite,飞行试验 flightTest,在轨运行 orbitOperation,售后服务 AfterSaleService';


--
-- Name: COLUMN zero_problems.problem_cause_sort; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.problem_cause_sort IS '问题原因分类';


--
-- Name: COLUMN zero_problems.twolevel_cause_sort; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.twolevel_cause_sort IS '二层次原因分类';


--
-- Name: COLUMN zero_problems.zero_require; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.zero_require IS '技术和管理归零 TechnologyAndManagementRequire,管理归零 ManagementRequire,OtherRequire 其他归零';


--
-- Name: COLUMN zero_problems.droft_duty_unit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.droft_duty_unit IS '拟定归零责任单位';


--
-- Name: COLUMN zero_problems.state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.state IS '问题填写中 fillingIn,问题审核中 problemUnderReview,问题处理中 solving,完成情况审核中 CompletUnderReview,已完成completed,已取消 cancelled';


--
-- Name: COLUMN zero_problems.number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.number IS '质量问题单号';


--
-- Name: COLUMN zero_problems.express; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.express IS '质量问题快报';


--
-- Name: COLUMN zero_problems.problem_describe; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems.problem_describe IS '问题描述';


--
-- Name: zero_problems_completion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE zero_problems_completion (
    id bigint DEFAULT id_generator() NOT NULL,
    quality_problem_id bigint NOT NULL,
    location text,
    cause_analysis text,
    correct text,
    correct_measures text,
    manage_reason_analysis text,
    measures_implement text,
    other_witness jsonb DEFAULT '{}'::jsonb,
    whether_todo integer,
    state text NOT NULL,
    app_instance_id bigint NOT NULL,
    create_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    technology_report jsonb DEFAULT '{}'::jsonb,
    management_report jsonb DEFAULT '{}'::jsonb,
    technology_review jsonb DEFAULT '{}'::jsonb,
    management_review jsonb DEFAULT '{}'::jsonb
);


--
-- Name: COLUMN zero_problems_completion.location; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.location IS '定位';


--
-- Name: COLUMN zero_problems_completion.cause_analysis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.cause_analysis IS '原因分析';


--
-- Name: COLUMN zero_problems_completion.correct; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.correct IS '纠正';


--
-- Name: COLUMN zero_problems_completion.correct_measures; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.correct_measures IS '纠正措施';


--
-- Name: COLUMN zero_problems_completion.manage_reason_analysis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.manage_reason_analysis IS '管理原因分析';


--
-- Name: COLUMN zero_problems_completion.measures_implement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.measures_implement IS '措施落实';


--
-- Name: COLUMN zero_problems_completion.other_witness; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.other_witness IS '见证材料：可上传归零报告、评审结论及其他相关材料';


--
-- Name: COLUMN zero_problems_completion.whether_todo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.whether_todo IS '0是 1否';


--
-- Name: COLUMN zero_problems_completion.state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.state IS '问题填写中 fillingIn,问题审核中 problemUnderReview,问题处理中 solving,完成情况审核中 CompletUnderReview,已完成completed,已取消 cancelled';


--
-- Name: COLUMN zero_problems_completion.technology_report; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.technology_report IS '技术归零报告';


--
-- Name: COLUMN zero_problems_completion.management_report; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.management_report IS '管理归零报告';


--
-- Name: COLUMN zero_problems_completion.technology_review; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.technology_review IS '技术归零评审结论';


--
-- Name: COLUMN zero_problems_completion.management_review; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_completion.management_review IS '管理归零评审结论';


--
-- Name: zero_problems_progress; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE zero_problems_progress (
    id bigint DEFAULT id_generator() NOT NULL,
    quality_problem_id bigint NOT NULL,
    fill_name text NOT NULL,
    fill_time date NOT NULL,
    description text,
    app_instance_id bigint,
    create_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: COLUMN zero_problems_progress.quality_problem_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_progress.quality_problem_id IS '质量问题id';


--
-- Name: COLUMN zero_problems_progress.fill_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_progress.fill_name IS '填报人';


--
-- Name: COLUMN zero_problems_progress.fill_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_progress.fill_time IS '填报时间';


--
-- Name: COLUMN zero_problems_progress.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_progress.description IS '归零进展情况';


--
-- Name: COLUMN zero_problems_progress.create_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_problems_progress.create_at IS '创建时间';


--
-- Name: zero_summary; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE zero_summary (
    id bigint DEFAULT id_generator() NOT NULL,
    file text,
    created_by text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    app_instance_id bigint,
    deleted boolean DEFAULT false
);


--
-- Name: COLUMN zero_summary.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_summary.created_by IS '上传人';


--
-- Name: COLUMN zero_summary.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN zero_summary.created_at IS '上传时间';


--
-- Name: document_classify_setting code; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY document_classify_setting ALTER COLUMN code SET DEFAULT nextval('document_classify_setting_code_seq'::regclass);


--
-- Name: app app_app_instance_id_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY app
    ADD CONSTRAINT app_app_instance_id_pk PRIMARY KEY (app_instance_id);


--
-- Name: evaluation_rectify_plan assess_rectify_plan_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY evaluation_rectify_plan
    ADD CONSTRAINT assess_rectify_plan_pk PRIMARY KEY (id);


--
-- Name: evaluation_work_plan assess_work_plan_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY evaluation_work_plan
    ADD CONSTRAINT assess_work_plan_pk PRIMARY KEY (id);


--
-- Name: audit_department_evaluations audit_department_evaluations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_department_evaluations
    ADD CONSTRAINT audit_department_evaluations_pkey PRIMARY KEY (id);


--
-- Name: audit_external_nonconformities_correct audit_external_nonconformities_correct_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_external_nonconformities_correct
    ADD CONSTRAINT audit_external_nonconformities_correct_pkey PRIMARY KEY (id);


--
-- Name: audit_external_plan_rectifies audit_external_plan_rectifies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_external_plan_rectifies
    ADD CONSTRAINT audit_external_plan_rectifies_pkey PRIMARY KEY (id);


--
-- Name: audit_external_plans audit_external_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_external_plans
    ADD CONSTRAINT audit_external_plans_pkey PRIMARY KEY (id);


--
-- Name: audit_function_settings audit_function_settings_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_function_settings
    ADD CONSTRAINT audit_function_settings_pk PRIMARY KEY (id);


--
-- Name: audit_internal_evaluations audit_internal_evaluations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_internal_evaluations
    ADD CONSTRAINT audit_internal_evaluations_pkey PRIMARY KEY (id);


--
-- Name: audit_nonconformities_applies audit_nonconformities_applies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_nonconformities_applies
    ADD CONSTRAINT audit_nonconformities_applies_pkey PRIMARY KEY (id);


--
-- Name: audit_nonconformities audit_nonconformities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_nonconformities
    ADD CONSTRAINT audit_nonconformities_pkey PRIMARY KEY (id);


--
-- Name: audit_nonconformity_terms audit_nonconformity_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_nonconformity_terms
    ADD CONSTRAINT audit_nonconformity_terms_pkey PRIMARY KEY (id);


--
-- Name: audit_questions audit_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_questions
    ADD CONSTRAINT audit_questions_pkey PRIMARY KEY (id);


--
-- Name: document_approval document_approval_id_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY document_approval
    ADD CONSTRAINT document_approval_id_pk PRIMARY KEY (id);


--
-- Name: evaluation_function_settings evaluation_function_settings_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY evaluation_function_settings
    ADD CONSTRAINT evaluation_function_settings_pk PRIMARY KEY (id);


--
-- Name: evaluation_review_form evaluation_review_form_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY evaluation_review_form
    ADD CONSTRAINT evaluation_review_form_pk PRIMARY KEY (id);


--
-- Name: evaluation_situation_record evaluation_situation_record_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY evaluation_situation_record
    ADD CONSTRAINT evaluation_situation_record_pk PRIMARY KEY (id);


--
-- Name: general_relationships general_relationships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY general_relationships
    ADD CONSTRAINT general_relationships_pkey PRIMARY KEY (id);


--
-- Name: global_serial_numbers global_serial_numbers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY global_serial_numbers
    ADD CONSTRAINT global_serial_numbers_pkey PRIMARY KEY (id);


--
-- Name: audit_check_lists quality_checklist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_check_lists
    ADD CONSTRAINT quality_checklist_pkey PRIMARY KEY (id);


--
-- Name: audit_implement_plans quality_implement_plan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_implement_plans
    ADD CONSTRAINT quality_implement_plan_pkey PRIMARY KEY (id);


--
-- Name: zero_problems quality_problems_zero_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY zero_problems
    ADD CONSTRAINT quality_problems_zero_pk PRIMARY KEY (id);


--
-- Name: audit_report_applies quality_report_applies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_report_applies
    ADD CONSTRAINT quality_report_applies_pkey PRIMARY KEY (id);


--
-- Name: zero_problems_progress quality_solve_progress_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY zero_problems_progress
    ADD CONSTRAINT quality_solve_progress_pk PRIMARY KEY (id);


--
-- Name: sequence_rules sequence_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sequence_rules
    ADD CONSTRAINT sequence_rules_pkey PRIMARY KEY (id);


--
-- Name: sequences sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sequences
    ADD CONSTRAINT sequences_pkey PRIMARY KEY (id);


--
-- Name: supervise_agency_matter_applies supervise_agency_matter_applies_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY supervise_agency_matter_applies
    ADD CONSTRAINT supervise_agency_matter_applies_pk PRIMARY KEY (id);


--
-- Name: supervise_thematic_activities supervise_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY supervise_thematic_activities
    ADD CONSTRAINT supervise_pkey PRIMARY KEY (id);


--
-- Name: supervise_problems supervise_problems_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY supervise_problems
    ADD CONSTRAINT supervise_problems_pk PRIMARY KEY (id);


--
-- Name: supervise_quality_inspections supervise_quality_inspections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY supervise_quality_inspections
    ADD CONSTRAINT supervise_quality_inspections_pkey PRIMARY KEY (id);


--
-- Name: supervise_special_inspections supervise_special_inspections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY supervise_special_inspections
    ADD CONSTRAINT supervise_special_inspections_pkey PRIMARY KEY (id);


--
-- Name: supervise_job_contents supervise_thematic_activities_copy1_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY supervise_job_contents
    ADD CONSTRAINT supervise_thematic_activities_copy1_pkey PRIMARY KEY (id);


--
-- Name: zero_problems_completion zero_problem_completion_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY zero_problems_completion
    ADD CONSTRAINT zero_problem_completion_pk PRIMARY KEY (id);


--
-- Name: zero_summary zero_summary_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY zero_summary
    ADD CONSTRAINT zero_summary_pk PRIMARY KEY (id);


--
-- Name: aap_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aap_app_instance_id_index ON public.audit_annual_plans USING btree (app_instance_id);


--
-- Name: aap_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aap_created_at_index ON public.audit_annual_plans USING btree (created_at);


--
-- Name: aap_created_by_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aap_created_by_index ON public.audit_annual_plans USING btree (created_by);


--
-- Name: aap_file_sn_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aap_file_sn_index ON public.audit_annual_plans USING btree (file_sn);


--
-- Name: aap_sn_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aap_sn_index ON public.audit_annual_plans USING btree (sn);


--
-- Name: aap_year_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aap_year_index ON public.audit_annual_plans USING btree (year);


--
-- Name: aenc_correct_measure_sn_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aenc_correct_measure_sn_index ON public.audit_external_nonconformities_correct USING btree (correct_measure_sn);


--
-- Name: aenc_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aenc_created_at_index ON public.audit_external_nonconformities_correct USING btree (created_at);


--
-- Name: aenc_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aenc_status_index ON public.audit_external_nonconformities_correct USING btree (status);


--
-- Name: aenc_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aenc_type_index ON public.audit_external_nonconformities_correct USING btree (type);


--
-- Name: an_audit_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX an_audit_date_index ON public.audit_nonconformities USING btree (audit_date);


--
-- Name: an_audit_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX an_audit_status_index ON public.audit_nonconformities USING btree (audit_status);


--
-- Name: an_audited_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX an_audited_department_id_index ON public.audit_nonconformities USING btree (audited_department_id);


--
-- Name: an_auditor_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX an_auditor_id_index ON public.audit_nonconformities USING btree (auditor_id);


--
-- Name: an_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX an_created_at_index ON public.audit_nonconformities USING btree (created_at);


--
-- Name: an_sn_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX an_sn_index ON public.audit_nonconformities USING btree (sn);


--
-- Name: ana_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ana_created_at_index ON public.audit_nonconformities_applies USING btree (created_at);


--
-- Name: ana_nonconformity_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ana_nonconformity_id_index ON public.audit_nonconformities_applies USING btree (nonconformity_id);


--
-- Name: ant_term_accordance_sn_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ant_term_accordance_sn_uindex ON public.audit_nonconformity_terms USING btree (term_sn, accordance);


--
-- Name: app_access_key_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX app_access_key_uindex ON public.app USING btree (access_key);


--
-- Name: assess_rectify_plan_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX assess_rectify_plan_app_instance_id_index ON public.evaluation_rectify_plan USING btree (app_instance_id);


--
-- Name: assess_rectify_plan_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX assess_rectify_plan_id_uindex ON public.evaluation_rectify_plan USING btree (id);


--
-- Name: assess_rectify_plan_state_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX assess_rectify_plan_state_index ON public.evaluation_rectify_plan USING btree (state);


--
-- Name: assess_work_plan_annual_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX assess_work_plan_annual_index ON public.evaluation_work_plan USING btree (annual);


--
-- Name: assess_work_plan_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX assess_work_plan_app_instance_id_index ON public.evaluation_work_plan USING btree (app_instance_id);


--
-- Name: assess_work_plan_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX assess_work_plan_id_uindex ON public.evaluation_work_plan USING btree (id);


--
-- Name: assess_work_plan_state_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX assess_work_plan_state_index ON public.evaluation_work_plan USING btree (state);


--
-- Name: auality_report_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auality_report_app_instance_id_index ON public.audit_reports USING btree (app_instance_id);


--
-- Name: audit_check_app_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_check_app_instance_id ON public.audit_check_lists USING btree (app_instance_id);


--
-- Name: audit_check_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX audit_check_id_uindex ON public.audit_check_lists USING btree (id);


--
-- Name: audit_check_leader_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_check_leader_id_index ON public.audit_check_lists USING btree (audit_leader_id);


--
-- Name: audit_department_evaluations_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_department_evaluations_app_instance_id_index ON public.audit_department_evaluations USING btree (app_instance_id);


--
-- Name: audit_department_evaluations_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX audit_department_evaluations_id_uindex ON public.audit_department_evaluations USING btree (id);


--
-- Name: audit_department_evaluations_implement_plan_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_department_evaluations_implement_plan_id_index ON public.audit_department_evaluations USING btree (implement_plan_id);


--
-- Name: audit_external_plans_annual_plan_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_external_plans_annual_plan_id_index ON public.audit_external_plans USING btree (annual_plan_id);


--
-- Name: audit_external_plans_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_external_plans_app_instance_id_index ON public.audit_external_plans USING btree (app_instance_id);


--
-- Name: audit_external_plans_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX audit_external_plans_id_uindex ON public.audit_external_plans USING btree (id);


--
-- Name: audit_function_settings_code_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX audit_function_settings_code_uindex ON public.audit_function_settings USING btree (code, app_instance_id);


--
-- Name: audit_function_settings_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX audit_function_settings_id_uindex ON public.audit_function_settings USING btree (id);


--
-- Name: audit_function_settings_name_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX audit_function_settings_name_uindex ON public.audit_function_settings USING btree (name, app_instance_id);


--
-- Name: audit_function_settings_role_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_function_settings_role_id_index ON public.audit_function_settings USING btree (role_id);


--
-- Name: audit_internal_evaluationss_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX audit_internal_evaluationss_id_uindex ON public.audit_internal_evaluations USING btree (id);


--
-- Name: audit_internal_evaluationss_implement_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_internal_evaluationss_implement_plan_id ON public.audit_internal_evaluations USING btree (implement_plan_id);


--
-- Name: audit_plan_annual_plan_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_plan_annual_plan_id_index ON public.audit_implement_plans USING btree (annual_plan_id);


--
-- Name: audit_plan_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_plan_date_index ON public.audit_implement_plans USING btree (audit_date);


--
-- Name: audit_plan_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX audit_plan_id_uindex ON public.audit_implement_plans USING btree (id);


--
-- Name: audit_plan_leader_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_plan_leader_id_index ON public.audit_implement_plans USING btree (audit_leader_id);


--
-- Name: audit_plan_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_plan_type_index ON public.audit_implement_plans USING btree (audit_type);


--
-- Name: audited_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audited_department_id_index ON public.audit_questions USING btree (audited_department_id);


--
-- Name: document_classify_setting_name_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX document_classify_setting_name_uindex ON public.document_classify_setting USING btree (name);


--
-- Name: evaluation_function_settings_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evaluation_function_settings_app_instance_id_index ON public.evaluation_function_settings USING btree (app_instance_id);


--
-- Name: evaluation_function_settings_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evaluation_function_settings_id_index ON public.evaluation_function_settings USING btree (id);


--
-- Name: evaluation_rectify_plan_completion_time_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evaluation_rectify_plan_completion_time_index ON public.evaluation_rectify_plan USING btree (completion_time);


--
-- Name: evaluation_review_form_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evaluation_review_form_app_instance_id_index ON public.evaluation_review_form USING btree (app_instance_id);


--
-- Name: evaluation_review_form_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX evaluation_review_form_id_uindex ON public.evaluation_review_form USING btree (id);


--
-- Name: evaluation_review_form_state_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evaluation_review_form_state_index ON public.evaluation_review_form USING btree (state);


--
-- Name: evaluation_situation_record_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evaluation_situation_record_app_instance_id_index ON public.evaluation_situation_record USING btree (app_instance_id);


--
-- Name: evaluation_situation_record_evaluation_time_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evaluation_situation_record_evaluation_time_index ON public.evaluation_situation_record USING btree (evaluation_time);


--
-- Name: evaluation_situation_record_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX evaluation_situation_record_id_uindex ON public.evaluation_situation_record USING btree (id);


--
-- Name: evaluation_situation_record_state_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evaluation_situation_record_state_index ON public.evaluation_situation_record USING btree (state);


--
-- Name: general_relationships_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX general_relationships_id_uindex ON public.general_relationships USING btree (id);


--
-- Name: general_relationships_relation_type_source_type_source; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX general_relationships_relation_type_source_type_source ON public.general_relationships USING btree (relation_type, source_type, source_id, target_type, target_id);


--
-- Name: general_relationships_relation_type_source_type_source_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX general_relationships_relation_type_source_type_source_id_index ON public.general_relationships USING btree (relation_type, source_type, source_id);


--
-- Name: general_relationships_relation_type_target_type_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX general_relationships_relation_type_target_type_target ON public.general_relationships USING btree (relation_type, target_type, target_id, source_type, source_id);


--
-- Name: global_serial_numbers_sn_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX global_serial_numbers_sn_uindex ON public.global_serial_numbers USING btree (sn);


--
-- Name: implement_plan_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX implement_plan_id_index ON public.audit_questions USING btree (implement_plan_id);


--
-- Name: match_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_index ON public.audit_questions USING btree (match);


--
-- Name: plan_recifiles_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX plan_recifiles_app_instance_id_index ON public.audit_external_plan_rectifies USING btree (app_instance_id);


--
-- Name: plan_recifiles_external_plan_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX plan_recifiles_external_plan_id_index ON public.audit_external_plan_rectifies USING btree (external_plan_id);


--
-- Name: plan_recifiles_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX plan_recifiles_id_uindex ON public.audit_external_plan_rectifies USING btree (id);


--
-- Name: plan_recifiles_sn_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX plan_recifiles_sn_uindex ON public.audit_external_plan_rectifies USING btree (sn);


--
-- Name: quality_solve_progress_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX quality_solve_progress_id_uindex ON public.zero_problems_progress USING btree (id);


--
-- Name: report_applies_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX report_applies_id_uindex ON public.audit_report_applies USING btree (id);


--
-- Name: report_applies_report_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX report_applies_report_id_index ON public.audit_report_applies USING btree (report_id);


--
-- Name: responsible_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX responsible_department_id_index ON public.audit_questions USING btree (responsible_department_id);


--
-- Name: sequence_rule_name_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sequence_rule_name_uniq ON public.sequence_rules USING btree (name);


--
-- Name: sequence_uniq_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sequence_uniq_key ON public.sequences USING btree (scope);


--
-- Name: sqin_created_by_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sqin_created_by_index ON public.supervise_quality_inspection_notices USING btree (created_by);


--
-- Name: sqin_supervise_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sqin_supervise_time ON public.supervise_quality_inspection_notices USING btree (supervise_time);


--
-- Name: ssi_complete_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ssi_complete_date_index ON public.supervise_quality_inspections USING btree (complete_date);


--
-- Name: ssi_responsible_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ssi_responsible_department_id_index ON public.supervise_quality_inspections USING btree (responsible_department_id);


--
-- Name: supervise_agency_matter_applies_agency_matter_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supervise_agency_matter_applies_agency_matter_id_index ON public.supervise_agency_matter_applies USING btree (agency_matter_id);


--
-- Name: supervise_agency_matter_applies_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supervise_agency_matter_applies_id_uindex ON public.supervise_agency_matter_applies USING btree (id);


--
-- Name: supervise_agency_matters_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supervise_agency_matters_app_instance_id_index ON public.supervise_agency_matters USING btree (app_instance_id);


--
-- Name: supervise_agency_matters_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supervise_agency_matters_id_uindex ON public.supervise_agency_matters USING btree (id);


--
-- Name: supervise_agency_matters_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supervise_agency_matters_status_index ON public.supervise_agency_matters USING btree (status);


--
-- Name: supervise_job_contents_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supervise_job_contents_id_uindex ON public.supervise_job_contents USING btree (id);


--
-- Name: supervise_job_contents_thematic_activity_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supervise_job_contents_thematic_activity_id_index ON public.supervise_job_contents USING btree (thematic_activity_id);


--
-- Name: supervise_problems_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supervise_problems_app_instance_id_index ON public.supervise_problems USING btree (app_instance_id);


--
-- Name: supervise_problems_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supervise_problems_id_uindex ON public.supervise_problems USING btree (id);


--
-- Name: supervise_thematic_activities_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supervise_thematic_activities_app_instance_id_index ON public.supervise_thematic_activities USING btree (app_instance_id);


--
-- Name: supervise_thematic_activities_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supervise_thematic_activities_id_uindex ON public.supervise_thematic_activities USING btree (id);


--
-- Name: supervisor_qi_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supervisor_qi_app_instance_id_index ON public.supervise_quality_inspections USING btree (app_instance_id);


--
-- Name: supervisor_qi_complete_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supervisor_qi_complete_date_index ON public.supervise_quality_inspections USING btree (complete_date);


--
-- Name: supervisor_qi_responsible_department_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supervisor_qi_responsible_department_id_index ON public.supervise_quality_inspections USING btree (responsible_department_id);


--
-- Name: zero_problems_create_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zero_problems_create_at_index ON public.zero_problems USING btree (create_at);


--
-- Name: zero_problems_model_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zero_problems_model_index ON public.zero_problems USING btree (model);


--
-- Name: zero_problems_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zero_problems_name_index ON public.zero_problems USING btree (name);


--
-- Name: zero_problems_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zero_problems_number_index ON public.zero_problems USING btree (number);


--
-- Name: zero_problems_state_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zero_problems_state_index ON public.zero_problems USING btree (state);


--
-- Name: zero_summary_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zero_summary_app_instance_id_index ON public.zero_summary USING btree (app_instance_id);


--
-- Name: zero_summary_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zero_summary_created_at_index ON public.zero_summary USING btree (created_at);


--
-- Name: zol_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zol_app_instance_id_index ON public.zero_operation_log USING btree (app_instance_id);


--
-- Name: zol_create_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zol_create_at_index ON public.zero_operation_log USING btree (create_at);


--
-- Name: zol_quality_problem_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zol_quality_problem_id_index ON public.zero_operation_log USING btree (quality_problem_id);


--
-- Name: zp_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zp_app_instance_id_index ON public.zero_problems USING btree (app_instance_id);


--
-- Name: zpc_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zpc_app_instance_id_index ON public.zero_problems_completion USING btree (app_instance_id);


--
-- Name: zpc_create_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zpc_create_at_index ON public.zero_problems_completion USING btree (create_at);


--
-- Name: zpc_quality_problem_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zpc_quality_problem_id_index ON public.zero_problems_completion USING btree (quality_problem_id);


--
-- Name: zpc_state_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zpc_state_index ON public.zero_problems_completion USING btree (state);


--
-- Name: zpp_app_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zpp_app_instance_id_index ON public.zero_problems_progress USING btree (app_instance_id);


--
-- Name: zpp_create_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zpp_create_at_index ON public.zero_problems_progress USING btree (create_at);


--
-- Name: zpp_quality_problem_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX zpp_quality_problem_id_index ON public.zero_problems_progress USING btree (quality_problem_id);


--
-- PostgreSQL database dump complete
--

