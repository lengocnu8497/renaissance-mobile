// supabase/functions/generate-recovery-insights/index.ts
//
// Analyzes patterns across multiple journal entries using Gemini 2.5 Flash (text-only).
// Uses semantics from user notes + photo metric trends to produce cross-entry insights.
// Follows the same auth / subscription / quota pattern as analyze-photo.
//
// Quota cost: 2 credits (no image slot — text-only inference).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const GOOGLE_AI_STUDIO_API_KEY = Deno.env.get("GOOGLE_AI_STUDIO_API_KEY")!;
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

const INSIGHTS_CREDIT_COST = 2;

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

// MARK: - Request / Response Types

interface EntryPayload {
  date: string;
  dayNumber: number;
  notes?: string | null;
  swellingIndex?: number | null;
  bruisingIndex?: number | null;
  rednessIndex?: number | null;
  overallScore?: number | null;
}

interface InsightsRequest {
  procedureId: string;
  procedureName: string;
  entries: EntryPayload[];
}

interface InsightFlag {
  severity: "info" | "warning" | "urgent";
  message: string;
  metric?: string | null;
}

interface InsightsResult {
  summary: string;
  trend: "improving" | "stable" | "concerning";
  flags: InsightFlag[];
  encouragements: string[];
  nextSteps: string | null;
}

// MARK: - Gemini Schema

const responseSchema = {
  type: "OBJECT",
  properties: {
    summary: {
      type: "STRING",
      description: "2–3 sentence overall assessment of the recovery journey, referencing specific notes or metric changes"
    },
    trend: {
      type: "STRING",
      enum: ["improving", "stable", "concerning"],
      description: "Overall recovery trajectory"
    },
    flags: {
      type: "ARRAY",
      description: "Specific things the patient might have missed — patterns, stalled metrics, or things worth provider attention",
      items: {
        type: "OBJECT",
        properties: {
          severity: { type: "STRING", enum: ["info", "warning", "urgent"] },
          message: { type: "STRING" },
          metric: { type: "STRING", nullable: true }
        },
        required: ["severity", "message"]
      }
    },
    encouragements: {
      type: "ARRAY",
      description: "Genuine improvements the patient might not have noticed — especially fears that turned out to be unfounded",
      items: { type: "STRING" }
    },
    nextSteps: {
      type: "STRING",
      nullable: true,
      description: "One specific, actionable suggestion for their next entry or day"
    }
  },
  required: ["summary", "trend", "flags", "encouragements"]
};

// MARK: - Prompt Builder

function buildPrompt(procedureName: string, entries: EntryPayload[]): string {
  const timeline = entries
    .map((e, i) => {
      const dayLabel = e.dayNumber === 0 ? "Day of Procedure" : `Day ${e.dayNumber}`;
      const metricsLine = (e.swellingIndex != null)
        ? `  Metrics — Swelling: ${e.swellingIndex}/10 | Bruising: ${e.bruisingIndex}/10 | Redness: ${e.rednessIndex}/10 | Recovery score: ${e.overallScore}/10`
        : `  (no photo metrics for this entry)`;
      const notesLine = e.notes?.trim()
        ? `  Notes: "${e.notes.trim()}"`
        : `  (no notes written)`;

      return `Entry ${i + 1} — ${e.date} (${dayLabel}):\n${notesLine}\n${metricsLine}`;
    })
    .join("\n\n");

  return `You are a compassionate recovery support assistant. A patient recovering from a ${procedureName} procedure has shared ${entries.length} journal entries with you.

Recovery timeline (oldest to newest):

${timeline}

Based on this complete timeline, provide the following:

1. SUMMARY: 2–3 sentences summarizing their overall recovery journey. Reference specific things they mentioned in their notes or actual metric changes. Be precise, not generic.

2. TREND: Classify as "improving", "stable", or "concerning" based on the overall trajectory of both notes sentiment and metrics.

3. FLAGS: Identify things the patient might have missed. Look for:
   - Repeated concerns across multiple entries (e.g., if they mention pain at night in 3 entries, call that out)
   - Metrics that have not improved after multiple entries when they should be
   - Anything in their notes that could warrant a provider check-in (new lumps, unexpected changes, persistent symptoms)
   - If genuinely nothing is concerning, return an empty array — do not invent flags
   Only use "urgent" severity if the patient should contact their provider soon.

4. ENCOURAGEMENTS: Point out real improvements the patient might not have noticed:
   - Especially things they were worried or anxious about that turned out to resolve
   - Specific metric improvements with numbers (e.g., "your swelling dropped from 8.2 to 3.1")
   - If they are not improving, return an empty array — do not be falsely positive

5. NEXT_STEPS: One specific, actionable suggestion for their next entry or the coming days.

Tone: Warm, honest, and supportive. Quote their exact words from notes briefly when relevant. Never use clinical jargon. Do not be generic or templated.`;
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
        message: 'Please upgrade to use AI recovery insights.'
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

    if ((usageRecord.credits_used + INSIGHTS_CREDIT_COST) > usageRecord.credits_limit) {
      return new Response(JSON.stringify({
        error: 'Quota exceeded',
        code: 'QUOTA_EXCEEDED',
        limitType: 'credits',
        usage: {
          credits: { used: usageRecord.credits_used, limit: usageRecord.credits_limit }
        }
      }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── Input validation ──────────────────────────────────────────────────────
    const body: InsightsRequest = await req.json();
    const { procedureId, procedureName, entries } = body;

    if (!procedureId || !procedureName || !Array.isArray(entries)) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (entries.length < 2) {
      return new Response(JSON.stringify({ error: "At least 2 entries required for insights" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Gemini call ───────────────────────────────────────────────────────────
    const prompt = buildPrompt(procedureName, entries);

    const geminiPayload = {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        response_mime_type: "application/json",
        response_schema: responseSchema,
        temperature: 0.4,
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
    const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!rawText) throw new Error("No content in Gemini response");

    const result: InsightsResult = JSON.parse(rawText);

    // ── Increment usage ───────────────────────────────────────────────────────
    try {
      await adminClient.rpc('increment_usage', {
        p_usage_id: usageRecord.id,
        p_user_id:  user.id,
        p_messages: 0,
        p_images:   0,
        p_credits:  INSIGHTS_CREDIT_COST
      });
    } catch (e) {
      console.error("Failed to increment usage:", e);
    }

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("generate-recovery-insights error:", err);
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : "Internal error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
