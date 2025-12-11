drop extension if exists "pg_net";


  create table "public"."chat_conversations" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "title" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now(),
    "is_archived" boolean default false,
    "metadata" jsonb
      );


alter table "public"."chat_conversations" enable row level security;


  create table "public"."chat_messages" (
    "id" uuid not null default gen_random_uuid(),
    "conversation_id" uuid not null,
    "user_id" uuid not null,
    "message_text" text not null,
    "is_from_user" boolean not null,
    "created_at" timestamp with time zone not null default now(),
    "openai_response_id" text,
    "openai_model" text,
    "has_image" boolean default false,
    "image_url" text,
    "image_metadata" jsonb,
    "tokens_used" integer,
    "response_time_ms" integer,
    "metadata" jsonb
      );


alter table "public"."chat_messages" enable row level security;


  create table "public"."waitlist" (
    "id" uuid not null default gen_random_uuid(),
    "email" text not null,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."waitlist" enable row level security;

CREATE UNIQUE INDEX chat_conversations_pkey ON public.chat_conversations USING btree (id);

CREATE UNIQUE INDEX chat_messages_pkey ON public.chat_messages USING btree (id);

CREATE INDEX idx_conversations_created_at ON public.chat_conversations USING btree (created_at DESC);

CREATE INDEX idx_conversations_user_id ON public.chat_conversations USING btree (user_id);

CREATE INDEX idx_conversations_user_updated ON public.chat_conversations USING btree (user_id, updated_at DESC);

CREATE INDEX idx_messages_conversation_id ON public.chat_messages USING btree (conversation_id, created_at);

CREATE INDEX idx_messages_created_at ON public.chat_messages USING btree (created_at DESC);

CREATE INDEX idx_messages_openai_response ON public.chat_messages USING btree (openai_response_id) WHERE (openai_response_id IS NOT NULL);

CREATE INDEX idx_messages_user_id ON public.chat_messages USING btree (user_id);

CREATE INDEX idx_waitlist_created_at ON public.waitlist USING btree (created_at DESC);

CREATE INDEX idx_waitlist_email ON public.waitlist USING btree (email);

CREATE UNIQUE INDEX waitlist_email_key ON public.waitlist USING btree (email);

CREATE UNIQUE INDEX waitlist_pkey ON public.waitlist USING btree (id);

alter table "public"."chat_conversations" add constraint "chat_conversations_pkey" PRIMARY KEY using index "chat_conversations_pkey";

alter table "public"."chat_messages" add constraint "chat_messages_pkey" PRIMARY KEY using index "chat_messages_pkey";

alter table "public"."waitlist" add constraint "waitlist_pkey" PRIMARY KEY using index "waitlist_pkey";

alter table "public"."chat_conversations" add constraint "chat_conversations_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."chat_conversations" validate constraint "chat_conversations_user_id_fkey";

alter table "public"."chat_messages" add constraint "chat_messages_conversation_id_fkey" FOREIGN KEY (conversation_id) REFERENCES public.chat_conversations(id) ON DELETE CASCADE not valid;

alter table "public"."chat_messages" validate constraint "chat_messages_conversation_id_fkey";

alter table "public"."chat_messages" add constraint "chat_messages_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."chat_messages" validate constraint "chat_messages_user_id_fkey";

alter table "public"."waitlist" add constraint "waitlist_email_key" UNIQUE using index "waitlist_email_key";

set check_function_bodies = off;

create or replace view "public"."chat_analytics_daily_volume" as  SELECT date_trunc('day'::text, created_at) AS date,
    count(*) AS total_messages,
    count(*) FILTER (WHERE (is_from_user = true)) AS user_messages,
    count(*) FILTER (WHERE (is_from_user = false)) AS ai_messages,
    count(DISTINCT user_id) AS unique_users
   FROM public.chat_messages
  GROUP BY (date_trunc('day'::text, created_at))
  ORDER BY (date_trunc('day'::text, created_at)) DESC;


create or replace view "public"."chat_analytics_dau" as  SELECT date_trunc('day'::text, created_at) AS date,
    count(DISTINCT user_id) AS active_users
   FROM public.chat_messages
  WHERE (created_at >= CURRENT_DATE)
  GROUP BY (date_trunc('day'::text, created_at));


create or replace view "public"."chat_analytics_mau" as  SELECT date_trunc('month'::text, created_at) AS month,
    count(DISTINCT user_id) AS active_users
   FROM public.chat_messages
  WHERE (created_at >= (now() - '30 days'::interval))
  GROUP BY (date_trunc('month'::text, created_at));


CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$
;

grant delete on table "public"."chat_conversations" to "anon";

grant insert on table "public"."chat_conversations" to "anon";

grant references on table "public"."chat_conversations" to "anon";

grant select on table "public"."chat_conversations" to "anon";

grant trigger on table "public"."chat_conversations" to "anon";

grant truncate on table "public"."chat_conversations" to "anon";

grant update on table "public"."chat_conversations" to "anon";

grant delete on table "public"."chat_conversations" to "authenticated";

grant insert on table "public"."chat_conversations" to "authenticated";

grant references on table "public"."chat_conversations" to "authenticated";

grant select on table "public"."chat_conversations" to "authenticated";

grant trigger on table "public"."chat_conversations" to "authenticated";

grant truncate on table "public"."chat_conversations" to "authenticated";

grant update on table "public"."chat_conversations" to "authenticated";

grant delete on table "public"."chat_conversations" to "service_role";

grant insert on table "public"."chat_conversations" to "service_role";

grant references on table "public"."chat_conversations" to "service_role";

grant select on table "public"."chat_conversations" to "service_role";

grant trigger on table "public"."chat_conversations" to "service_role";

grant truncate on table "public"."chat_conversations" to "service_role";

grant update on table "public"."chat_conversations" to "service_role";

grant delete on table "public"."chat_messages" to "anon";

grant insert on table "public"."chat_messages" to "anon";

grant references on table "public"."chat_messages" to "anon";

grant select on table "public"."chat_messages" to "anon";

grant trigger on table "public"."chat_messages" to "anon";

grant truncate on table "public"."chat_messages" to "anon";

grant update on table "public"."chat_messages" to "anon";

grant delete on table "public"."chat_messages" to "authenticated";

grant insert on table "public"."chat_messages" to "authenticated";

grant references on table "public"."chat_messages" to "authenticated";

grant select on table "public"."chat_messages" to "authenticated";

grant trigger on table "public"."chat_messages" to "authenticated";

grant truncate on table "public"."chat_messages" to "authenticated";

grant update on table "public"."chat_messages" to "authenticated";

grant delete on table "public"."chat_messages" to "service_role";

grant insert on table "public"."chat_messages" to "service_role";

grant references on table "public"."chat_messages" to "service_role";

grant select on table "public"."chat_messages" to "service_role";

grant trigger on table "public"."chat_messages" to "service_role";

grant truncate on table "public"."chat_messages" to "service_role";

grant update on table "public"."chat_messages" to "service_role";

grant delete on table "public"."waitlist" to "anon";

grant insert on table "public"."waitlist" to "anon";

grant references on table "public"."waitlist" to "anon";

grant select on table "public"."waitlist" to "anon";

grant trigger on table "public"."waitlist" to "anon";

grant truncate on table "public"."waitlist" to "anon";

grant update on table "public"."waitlist" to "anon";

grant delete on table "public"."waitlist" to "authenticated";

grant insert on table "public"."waitlist" to "authenticated";

grant references on table "public"."waitlist" to "authenticated";

grant select on table "public"."waitlist" to "authenticated";

grant trigger on table "public"."waitlist" to "authenticated";

grant truncate on table "public"."waitlist" to "authenticated";

grant update on table "public"."waitlist" to "authenticated";

grant delete on table "public"."waitlist" to "service_role";

grant insert on table "public"."waitlist" to "service_role";

grant references on table "public"."waitlist" to "service_role";

grant select on table "public"."waitlist" to "service_role";

grant trigger on table "public"."waitlist" to "service_role";

grant truncate on table "public"."waitlist" to "service_role";

grant update on table "public"."waitlist" to "service_role";


  create policy "Users can create own conversations"
  on "public"."chat_conversations"
  as permissive
  for insert
  to public
with check ((auth.uid() = user_id));



  create policy "Users can delete own conversations"
  on "public"."chat_conversations"
  as permissive
  for delete
  to public
using ((auth.uid() = user_id));



  create policy "Users can update own conversations"
  on "public"."chat_conversations"
  as permissive
  for update
  to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Users can view own conversations"
  on "public"."chat_conversations"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "Users can create own messages"
  on "public"."chat_messages"
  as permissive
  for insert
  to public
with check ((auth.uid() = user_id));



  create policy "Users can delete own messages"
  on "public"."chat_messages"
  as permissive
  for delete
  to public
using ((auth.uid() = user_id));



  create policy "Users can update own messages"
  on "public"."chat_messages"
  as permissive
  for update
  to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Users can view own messages"
  on "public"."chat_messages"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "Anyone can join waitlist"
  on "public"."waitlist"
  as permissive
  for insert
  to anon
with check (true);


CREATE TRIGGER update_chat_conversations_updated_at BEFORE UPDATE ON public.chat_conversations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


