// supabase/functions/generate-recovery-plan-copy/index.ts
//
// Generates premium recovery roadmap copy for the current phase using Gemini 2.5 Flash.
// Input:  prompt package + structured recovery context
// Output: { summary, focusAreas[] }
// Quota cost: 1 credit

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const GOOGLE_AI_STUDIO_API_KEY = Deno.env.get("GOOGLE_AI_STUDIO_API_KEY")!;
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

const COPY_CREDIT_COST = 1;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RecoveryPlanJournalSignals {
  entryCount: number;
  latestPainLevel?: number | null;
  latestSwellingLevel?: number | null;
  latestBruisingLevel?: number | null;
  latestRednessLevel?: number | null;
  weeklySummaryHeadline?: string | null;
  activeAlerts?: string[];
}

interface RecoveryPlanInput {
  procedureName: string;
  procedureDate: string;
  daysSinceProcedure: number;
  currentWeek: number;
  currentPhaseTitle: string;
  procedureFamily: string;
  gender?: string | null;
  ageRange?: string | null;
  raceEthnicity?: string | null;
  aestheticGoals: string[];
  bodyAreas: string[];
  proceduresOfInterest: string[];
  previousProcedures: string[];
  healthFlags: string[];
  latestJournalSignals?: RecoveryPlanJournalSignals | null;
}

interface RecoveryPlanTimelinePhase {
  id: string;
  title: string;
  weekStart: number;
  weekEnd: number;
  status: "completed" | "current" | "upcoming";
  summary: string;
}

interface RecoveryPlanCopyRequest {
  systemInstructions: string;
  userPrompt: string;
  schemaVersion: string;
  input: RecoveryPlanInput;
  timelinePhase: RecoveryPlanTimelinePhase;
  journalSignals?: RecoveryPlanJournalSignals | null;
}

interface RecoveryPlanCopyResponse {
  summary: string;
  focusAreas: string[];
}

const responseSchema = {
  type: "OBJECT",
  properties: {
    summary: {
      type: "STRING",
      description: "One short paragraph for the current recovery phase teaser card."
    },
    focusAreas: {
      type: "ARRAY",
      description: "2 to 4 concise bullets for the current phase teaser card.",
      items: {
        type: "STRING"
      }
    }
  },
  required: ["summary", "focusAreas"]
};

function subtractOneMonth(date: Date): Date {
  const d = new Date(date);
  const originalDay = d.getDate();
  d.setMonth(d.getMonth() - 1);
  if (d.getDate() !== originalDay) d.setDate(0);
  return d;
}

function sanitizeResponse(raw: RecoveryPlanCopyResponse): RecoveryPlanCopyResponse {
  const summary = raw.summary?.trim?.() ?? "";
  const focusAreas = Array.isArray(raw.focusAreas)
    ? raw.focusAreas
        .map((item) => typeof item === "string" ? item.trim() : "")
        .filter((item) => item.length > 0)
    : [];

  return { summary, focusAreas };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
      global: { headers: { Authorization: authHeader } }
    });
    const adminClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await userClient.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: userProfile, error: profileError } = await userClient
      .from("user_profiles")
      .select("subscription_tier, subscription_current_period_end, subscription_status")
      .eq("id", user.id)
      .single();

    if (profileError || !userProfile) {
      return new Response(JSON.stringify({ error: "Failed to fetch user profile" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { subscription_tier, subscription_current_period_end, subscription_status } = userProfile;
    const isActive = subscription_status === "active";
    const isCanceledButValid = subscription_status === "canceled"
      && subscription_current_period_end
      && new Date(subscription_current_period_end) > new Date();

    if (!subscription_tier || (!isActive && !isCanceledButValid)) {
      return new Response(JSON.stringify({
        error: "No active subscription",
        code: "NO_SUBSCRIPTION",
        message: "Please upgrade to use AI recovery roadmap copy."
      }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const periodEnd = new Date(subscription_current_period_end);
    const periodStart = subtractOneMonth(periodEnd);

    const { data: usageRecord, error: usageError } = await adminClient
      .rpc("get_or_create_usage_record", {
        p_user_id: user.id,
        p_period_start: periodStart.toISOString(),
        p_period_end: periodEnd.toISOString(),
        p_tier: subscription_tier
      });

    if (usageError || !usageRecord) {
      return new Response(JSON.stringify({ error: "Failed to fetch usage data" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if ((usageRecord.credits_used + COPY_CREDIT_COST) > usageRecord.credits_limit) {
      return new Response(JSON.stringify({
        error: "Quota exceeded",
        code: "QUOTA_EXCEEDED",
        limitType: "credits"
      }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: RecoveryPlanCopyRequest = await req.json();
    const {
      systemInstructions,
      userPrompt,
      schemaVersion,
      input,
      timelinePhase
    } = body;

    if (!systemInstructions || !userPrompt || !schemaVersion || !input || !timelinePhase) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (timelinePhase.status !== "current") {
      return new Response(JSON.stringify({ error: "Only current phases support AI copy generation" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const prompt = `${systemInstructions}\n\n${userPrompt}\n\nSchema version: ${schemaVersion}`;

    const geminiPayload = {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        response_mime_type: "application/json",
        response_schema: responseSchema,
        temperature: 0.6,
        max_output_tokens: 1024,
      },
    };

    const geminiResponse = await fetch(`${GEMINI_URL}?key=${GOOGLE_AI_STUDIO_API_KEY}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(geminiPayload),
    });

    if (!geminiResponse.ok) {
      const errText = await geminiResponse.text();
      throw new Error(`Gemini error ${geminiResponse.status}: ${errText}`);
    }

    const geminiData = await geminiResponse.json();
    const candidate = geminiData.candidates?.[0];
    if (candidate?.finishReason === "MAX_TOKENS") {
      throw new Error("Gemini response truncated by token limit");
    }

    const rawText = candidate?.content?.parts?.[0]?.text;
    if (!rawText) throw new Error("No content in Gemini response");

    const aiResult: RecoveryPlanCopyResponse = JSON.parse(rawText);
    const result = sanitizeResponse(aiResult);

    if (!result.summary || !Array.isArray(result.focusAreas) || result.focusAreas.length < 2) {
      throw new Error("Invalid AI recovery plan copy response");
    }

    try {
      await adminClient.rpc("increment_usage", {
        p_usage_id: usageRecord.id,
        p_user_id: user.id,
        p_messages: 0,
        p_images: 0,
        p_credits: COPY_CREDIT_COST
      });
    } catch (e) {
      console.error("Failed to increment usage:", e);
    }

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("generate-recovery-plan-copy error:", err);
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : "Internal error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

