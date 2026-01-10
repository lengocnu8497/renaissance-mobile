
  create table "public"."transactions" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "transaction_type" text not null,
    "amount_cents" integer not null,
    "currency" text not null default 'usd'::text,
    "status" text not null,
    "stripe_payment_intent_id" text,
    "stripe_subscription_id" text,
    "stripe_invoice_id" text,
    "metadata" jsonb,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );


alter table "public"."transactions" enable row level security;

CREATE INDEX idx_transactions_created_at ON public.transactions USING btree (created_at DESC);

CREATE INDEX idx_transactions_status ON public.transactions USING btree (status);

CREATE INDEX idx_transactions_stripe_payment_intent ON public.transactions USING btree (stripe_payment_intent_id);

CREATE INDEX idx_transactions_stripe_subscription ON public.transactions USING btree (stripe_subscription_id);

CREATE INDEX idx_transactions_type ON public.transactions USING btree (transaction_type);

CREATE INDEX idx_transactions_user_id ON public.transactions USING btree (user_id);

CREATE UNIQUE INDEX transactions_pkey ON public.transactions USING btree (id);

alter table "public"."transactions" add constraint "transactions_pkey" PRIMARY KEY using index "transactions_pkey";

alter table "public"."transactions" add constraint "transactions_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'succeeded'::text, 'failed'::text, 'canceled'::text, 'refunded'::text]))) not valid;

alter table "public"."transactions" validate constraint "transactions_status_check";

alter table "public"."transactions" add constraint "transactions_transaction_type_check" CHECK ((transaction_type = ANY (ARRAY['subscription'::text, 'booking'::text, 'refund'::text]))) not valid;

alter table "public"."transactions" validate constraint "transactions_transaction_type_check";

alter table "public"."transactions" add constraint "transactions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."transactions" validate constraint "transactions_user_id_fkey";

set check_function_bodies = off;

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

grant delete on table "public"."transactions" to "anon";

grant insert on table "public"."transactions" to "anon";

grant references on table "public"."transactions" to "anon";

grant select on table "public"."transactions" to "anon";

grant trigger on table "public"."transactions" to "anon";

grant truncate on table "public"."transactions" to "anon";

grant update on table "public"."transactions" to "anon";

grant delete on table "public"."transactions" to "authenticated";

grant insert on table "public"."transactions" to "authenticated";

grant references on table "public"."transactions" to "authenticated";

grant select on table "public"."transactions" to "authenticated";

grant trigger on table "public"."transactions" to "authenticated";

grant truncate on table "public"."transactions" to "authenticated";

grant update on table "public"."transactions" to "authenticated";

grant delete on table "public"."transactions" to "service_role";

grant insert on table "public"."transactions" to "service_role";

grant references on table "public"."transactions" to "service_role";

grant select on table "public"."transactions" to "service_role";

grant trigger on table "public"."transactions" to "service_role";

grant truncate on table "public"."transactions" to "service_role";

grant update on table "public"."transactions" to "service_role";


  create policy "Only Edge Functions can delete transactions"
  on "public"."transactions"
  as permissive
  for delete
  to public
using (false);



  create policy "Only Edge Functions can insert transactions"
  on "public"."transactions"
  as permissive
  for insert
  to public
with check (false);



  create policy "Only Edge Functions can update transactions"
  on "public"."transactions"
  as permissive
  for update
  to public
using (false);



  create policy "Users can view own transactions"
  on "public"."transactions"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));


CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


