// supabase/functions/generate-weekly-summary/index.ts
//
// Generates a concise per-week healing summary using Gemini 2.5 Flash.
// Input:  procedureId, procedureName, weekNumber, entries (for the week's date range)
// Output: weekNumber, headline, observation, improvement?, concern?
// Quota cost: 1 credit

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const GOOGLE_AI_STUDIO_API_KEY = Deno.env.get("GOOGLE_AI_STUDIO_API_KEY")!;
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

const SUMMARY_CREDIT_COST = 1;

function subtractOneMonth(date: Date): Date {
  const d = new Date(date);
  const originalDay = d.getDate();
  d.setMonth(d.getMonth() - 1);
  if (d.getDate() !== originalDay) d.setDate(0);
  return d;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// MARK: - Types

interface EntryPayload {
  date: string;
  dayNumber: number;
  notes?: string | null;
  bruisingLevel?: number | null;
  swellingLevel?: number | null;
  rednessLevel?: number | null;
}

interface SummaryRequest {
  procedureId: string;
  procedureName: string;
  weekNumber: number;
  entries: EntryPayload[];
}

interface SummaryResult {
  weekNumber: number;
  headline: string;
  observation: string;
  improvement: string | null;
  concern: string | null;
}

// MARK: - Gemini Schema

const responseSchema = {
  type: "OBJECT",
  properties: {
    weekNumber: {
      type: "INTEGER",
      description: "The week number being summarized"
    },
    headline: {
      type: "STRING",
      description: "3-6 word headline capturing the week's healing status. E.g. 'Swelling significantly reduced' or 'Steady healing progress'"
    },
    observation: {
      type: "STRING",
      description: "1-2 sentence narrative for this specific week. Reference actual notes or metric changes from entries."
    },
    improvement: {
      type: "STRING",
      nullable: true,
      description: "The single most notable positive change this week. Null if there is no clear improvement."
    },
    concern: {
      type: "STRING",
      nullable: true,
      description: "One brief note on anything worth watching. Null if nothing concerning."
    }
  },
  required: ["weekNumber", "headline", "observation"]
};

// MARK: - Prompt Builder

function buildPrompt(procedureName: string, weekNumber: number, entries: EntryPayload[]): string {
  if (entries.length === 0) {
    return `You are a compassionate recovery support assistant. A patient recovering from ${procedureName} did not log any journal entries during Week ${weekNumber}.

Write a brief, encouraging Week ${weekNumber} summary. Set weekNumber to ${weekNumber}. Use a gentle headline like "Check in next week" and a supportive observation reminding them that logging helps track their progress.`;
  }

  const timeline = entries
    .map((e) => {
      const dayLabel = e.dayNumber === 0 ? "Day of Procedure" : `Day ${e.dayNumber}`;
      const metricsLine = (e.bruisingLevel != null)
        ? `  Metrics — Swelling: ${e.swellingLevel}/10 | Bruising: ${e.bruisingLevel}/10 | Redness: ${e.rednessLevel}/10`
        : `  (no photo metrics recorded)`;
      const notesLine = e.notes?.trim()
        ? `  Notes: "${e.notes.trim()}"`
        : `  (no notes written)`;
      return `${e.date} (${dayLabel}):\n${notesLine}\n${metricsLine}`;
    })
    .join("\n\n");

  return `You are a compassionate recovery support assistant. A patient recovering from ${procedureName} has completed Week ${weekNumber} of their healing journey.

Here are their entries from this week:

${timeline}

Write a brief Week ${weekNumber} summary:

1. HEADLINE: 3-6 words capturing the week's healing status (e.g. "Swelling reduced, feeling hopeful"). Be specific, not generic.

2. OBSERVATION: 1-2 sentences about this specific week. Reference actual details from their notes or metrics. Do not use the word "journey".

3. IMPROVEMENT: The single most notable positive change this week, if clearly supported by the entries. Null if nothing clear.

4. CONCERN: One brief, gentle note on anything worth watching. Null if nothing concerning.

Set weekNumber to ${weekNumber}.
Tone: Warm, specific, never generic. Keep it concise.`;
}

// MARK: - Handler

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── Authentication ────────────────────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
      global: { headers: { Authorization: authHeader } }
    });
    const adminClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await userClient.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Subscription check ────────────────────────────────────────────────────
    const { data: userProfile, error: profileError } = await userClient
      .from('user_profiles')
      .select('subscription_tier, subscription_current_period_end, subscription_status')
      .eq('id', user.id)
      .single();

    if (profileError || !userProfile) {
      return new Response(JSON.stringify({ error: "Failed to fetch user profile" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { subscription_tier, subscription_current_period_end, subscription_status } = userProfile;
    const isActive = subscription_status === 'active';
    const isCanceledButValid = subscription_status === 'canceled'
      && subscription_current_period_end
      && new Date(subscription_current_period_end) > new Date();

    if (!subscription_tier || (!isActive && !isCanceledButValid)) {
      return new Response(JSON.stringify({
        error: 'No active subscription',
        code: 'NO_SUBSCRIPTION',
      }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── Quota check ───────────────────────────────────────────────────────────
    const periodEnd   = new Date(subscription_current_period_end);
    const periodStart = subtractOneMonth(periodEnd);

    const { data: usageRecord, error: usageError } = await adminClient
      .rpc('get_or_create_usage_record', {
        p_user_id:      user.id,
        p_period_start: periodStart.toISOString(),
        p_period_end:   periodEnd.toISOString(),
        p_tier:         subscription_tier
      });

    if (usageError || !usageRecord) {
      return new Response(JSON.stringify({ error: "Failed to fetch usage data" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if ((usageRecord.credits_used + SUMMARY_CREDIT_COST) > usageRecord.credits_limit) {
      return new Response(JSON.stringify({
        error: 'Quota exceeded',
        code: 'QUOTA_EXCEEDED',
      }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── Input validation ──────────────────────────────────────────────────────
    const body: SummaryRequest = await req.json();
    const { procedureId, procedureName, weekNumber, entries } = body;

    if (!procedureId || !procedureName || typeof weekNumber !== 'number') {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Gemini call ───────────────────────────────────────────────────────────
    const prompt = buildPrompt(procedureName, weekNumber, entries ?? []);

    const geminiPayload = {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        response_mime_type: "application/json",
        response_schema: responseSchema,
        temperature: 0.4,
        max_output_tokens: 2048,
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

    const result: SummaryResult = JSON.parse(rawText);

    // ── Increment usage ───────────────────────────────────────────────────────
    try {
      await adminClient.rpc('increment_usage', {
        p_usage_id: usageRecord.id,
        p_user_id:  user.id,
        p_messages: 0,
        p_images:   0,
        p_credits:  SUMMARY_CREDIT_COST
      });
    } catch (e) {
      console.error("Failed to increment usage:", e);
    }

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("generate-weekly-summary error:", err);
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : "Internal error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
