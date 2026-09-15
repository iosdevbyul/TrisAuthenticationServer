-- Captured from the original Phase A migrations on the disposable test DB.
-- Schema and migration bookkeeping only; no account or credential data.
CREATE TABLE public._fluent_migrations (
    id uuid NOT NULL,
    name text NOT NULL,
    batch bigint NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);



CREATE TABLE public.audit_logs (
    id uuid NOT NULL,
    user_id uuid,
    event_type text NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    session_management_id uuid,
    email_hash character varying(64),
    ip_hash character varying(64),
    client_id_hash character varying(64),
    metadata jsonb NOT NULL,
    dedup_key character varying(64),
    minute_bucket bigint
);



CREATE TABLE public.email_change_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    pending_email text NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone
);



CREATE TABLE public.email_rate_limits (
    bucket_key text NOT NULL,
    attempts bigint NOT NULL,
    expires_at timestamp with time zone NOT NULL
);



CREATE TABLE public.email_verification_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone
);



CREATE TABLE public.login_rate_limits (
    bucket_key text NOT NULL,
    attempts bigint NOT NULL,
    expires_at timestamp with time zone NOT NULL
);



CREATE TABLE public.password_reset_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone
);



CREATE TABLE public.refresh_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone,
    management_id uuid,
    started_at timestamp with time zone,
    last_refreshed_at timestamp with time zone,
    device_name text
);



CREATE TABLE public.users (
    id uuid NOT NULL,
    email text NOT NULL,
    password_hash text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    is_email_verified boolean DEFAULT false NOT NULL
);



ALTER TABLE ONLY public._fluent_migrations
    ADD CONSTRAINT _fluent_migrations_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_dedup_key_minute_bucket_key UNIQUE (dedup_key, minute_bucket);



ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.email_change_tokens
    ADD CONSTRAINT email_change_tokens_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.email_rate_limits
    ADD CONSTRAINT email_rate_limits_pkey PRIMARY KEY (bucket_key);



ALTER TABLE ONLY public.email_verification_tokens
    ADD CONSTRAINT email_verification_tokens_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.login_rate_limits
    ADD CONSTRAINT login_rate_limits_pkey PRIMARY KEY (bucket_key);



ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public._fluent_migrations
    ADD CONSTRAINT "uq:_fluent_migrations.name" UNIQUE (name);



ALTER TABLE ONLY public.email_change_tokens
    ADD CONSTRAINT "uq:email_change_tokens.token_hash" UNIQUE (token_hash);



ALTER TABLE ONLY public.email_change_tokens
    ADD CONSTRAINT "uq:email_change_tokens.user_id" UNIQUE (user_id);



ALTER TABLE ONLY public.email_verification_tokens
    ADD CONSTRAINT "uq:email_verification_tokens.token_hash" UNIQUE (token_hash);



ALTER TABLE ONLY public.email_verification_tokens
    ADD CONSTRAINT "uq:email_verification_tokens.user_id" UNIQUE (user_id);



ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT "uq:password_reset_tokens.token_hash" UNIQUE (token_hash);



ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT "uq:refresh_tokens.token_hash" UNIQUE (token_hash);



ALTER TABLE ONLY public.users
    ADD CONSTRAINT "uq:users.email" UNIQUE (email);



ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);



CREATE INDEX audit_logs_event_occurred_idx ON public.audit_logs USING btree (event_type, occurred_at);



CREATE INDEX audit_logs_occurred_idx ON public.audit_logs USING btree (occurred_at);



CREATE INDEX audit_logs_user_occurred_idx ON public.audit_logs USING btree (user_id, occurred_at);



CREATE INDEX email_change_tokens_maintenance_expiry_idx ON public.email_change_tokens USING btree (expires_at, id);



CREATE INDEX email_rate_limits_expiry_idx ON public.email_rate_limits USING btree (expires_at);



CREATE INDEX email_verification_tokens_maintenance_expiry_idx ON public.email_verification_tokens USING btree (expires_at, id);



CREATE INDEX login_rate_limits_expiry_idx ON public.login_rate_limits USING btree (expires_at);



CREATE INDEX password_reset_tokens_maintenance_expiry_idx ON public.password_reset_tokens USING btree (expires_at, id);



CREATE INDEX refresh_tokens_maintenance_expiry_idx ON public.refresh_tokens USING btree (expires_at, id);



CREATE INDEX refresh_tokens_user_expiry_idx ON public.refresh_tokens USING btree (user_id, expires_at, id);



ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;



ALTER TABLE ONLY public.email_change_tokens
    ADD CONSTRAINT email_change_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.email_verification_tokens
    ADD CONSTRAINT email_verification_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

INSERT INTO public._fluent_migrations VALUES ('ccaa8770-ff5e-4dde-8d2e-558a5f076544', 'WakTrainerServer.CreateUserMigration', 1, '2026-09-15 04:36:25.498189+00', '2026-09-15 04:36:25.498189+00');
INSERT INTO public._fluent_migrations VALUES ('87eb07a3-66ba-422c-bd81-9f2a577ec522', 'WakTrainerServer.CreateRefreshTokenMigration', 1, '2026-09-15 04:36:25.514767+00', '2026-09-15 04:36:25.514767+00');
INSERT INTO public._fluent_migrations VALUES ('762b4c72-b6bf-4b3d-8448-901ecf1c680a', 'WakTrainerServer.CreateLoginRateLimitMigration', 1, '2026-09-15 04:36:25.530156+00', '2026-09-15 04:36:25.530156+00');
INSERT INTO public._fluent_migrations VALUES ('0aed61b5-4982-4ad6-8b8a-37b90ee58302', 'WakTrainerServer.CreatePasswordResetTokenMigration', 1, '2026-09-15 04:36:25.542916+00', '2026-09-15 04:36:25.542916+00');
INSERT INTO public._fluent_migrations VALUES ('d0493a1a-af79-41b7-9fca-b17a2b3dd7b6', 'WakTrainerServer.CreateEmailRateLimitMigration', 1, '2026-09-15 04:36:25.554684+00', '2026-09-15 04:36:25.554684+00');
INSERT INTO public._fluent_migrations VALUES ('478b382b-0a91-497d-9117-801868406862', 'WakTrainerServer.AddEmailVerificationMigration', 1, '2026-09-15 04:36:25.57269+00', '2026-09-15 04:36:25.57269+00');
INSERT INTO public._fluent_migrations VALUES ('5e64c98a-0be7-4d0f-afd2-8e2521925856', 'WakTrainerServer.AddEmailChangeMigration', 1, '2026-09-15 04:36:25.588035+00', '2026-09-15 04:36:25.588035+00');
INSERT INTO public._fluent_migrations VALUES ('29c9addf-5bfd-494c-8977-fb4ed5d8f419', 'WakTrainerServer.AddSessionMetadataMigration', 1, '2026-09-15 04:36:25.595853+00', '2026-09-15 04:36:25.595853+00');
INSERT INTO public._fluent_migrations VALUES ('b94dd90f-59ec-45a6-b7e1-513330f16f63', 'WakTrainerServer.IndexSessionUserExpiryMigration', 1, '2026-09-15 04:36:25.60472+00', '2026-09-15 04:36:25.60472+00');
INSERT INTO public._fluent_migrations VALUES ('3a291f53-aa3b-4cde-8a89-3af72951057e', 'WakTrainerServer.CreateAuditLogMigration', 1, '2026-09-15 04:36:25.630717+00', '2026-09-15 04:36:25.630717+00');
INSERT INTO public._fluent_migrations VALUES ('a2f8f597-14f4-409b-a411-c993a4bacc09', 'WakTrainerServer.IndexMaintenanceExpiryMigration', 1, '2026-09-15 04:36:25.655675+00', '2026-09-15 04:36:25.655675+00');
