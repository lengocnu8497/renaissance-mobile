// supabase/functions/generate-weekly-summary/index.ts
//
// Generates and persists a synced weekly recovery report using Gemini 2.5 Flash.
// Input:  procedureId, procedureName, weekNumber, scheduledDate, completedEntryId?, entries
// Output: synced weekly report payload for the app
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
  painLevel?: number | null;
  bruisingLevel?: number | null;
  swellingLevel?: number | null;
  rednessLevel?: number | null;
  hasPhoto?: boolean | null;
}

interface SummaryRequest {
  procedureId: string;
  procedureName: string;
  weekNumber: number;
  scheduledDate: string;
  completedEntryId?: string | null;
  entries: EntryPayload[];
}

interface RecoveryAlert {
  severity: "info" | "warning" | "urgent";
  title: string;
  explanation: string;
  recommendedNextStep: string | null;
  metric?: string | null;
}

interface WeeklyMetricPoint {
  date: string;
  dayNumber: number;
  painLevel?: number | null;
  swellingLevel?: number | null;
  bruisingLevel?: number | null;
  rednessLevel?: number | null;
  hasPhoto: boolean;
}

interface SummaryResult {
  weekNumber: number;
  headline: string;
  observation: string;
  improvement: string | null;
  concern: string | null;
  painTrend: string | null;
  swellingStatus: string | null;
  bruisingStatus: string | null;
  rednessStatus: string | null;
  recoveryScore: number | null;
  consistencyRate: number | null;
  alerts: RecoveryAlert[];
  metricPoints: WeeklyMetricPoint[];
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
    },
    painTrend: { type: "STRING", nullable: true },
    swellingStatus: { type: "STRING", nullable: true },
    bruisingStatus: { type: "STRING", nullable: true },
    rednessStatus: { type: "STRING", nullable: true },
    recoveryScore: { type: "INTEGER", nullable: true },
    consistencyRate: { type: "INTEGER", nullable: true },
    alerts: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          severity: { type: "STRING", enum: ["info", "warning", "urgent"] },
          title: { type: "STRING" },
          explanation: { type: "STRING" },
          recommendedNextStep: { type: "STRING", nullable: true },
          metric: { type: "STRING", nullable: true }
        },
        required: ["severity", "title", "explanation"]
      }
    },
    metricPoints: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          date: { type: "STRING" },
          dayNumber: { type: "INTEGER" },
          painLevel: { type: "NUMBER", nullable: true },
          swellingLevel: { type: "NUMBER", nullable: true },
          bruisingLevel: { type: "NUMBER", nullable: true },
          rednessLevel: { type: "NUMBER", nullable: true },
          hasPhoto: { type: "BOOLEAN" }
        },
        required: ["date", "dayNumber", "hasPhoto"]
      }
    }
  },
  required: ["weekNumber", "headline", "observation", "alerts", "metricPoints"]
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
      const metricsLine = (e.bruisingLevel != null || e.swellingLevel != null || e.rednessLevel != null || e.painLevel != null)
        ? `  Metrics — Pain: ${e.painLevel ?? "n/a"}/10 | Swelling: ${e.swellingLevel ?? "n/a"}/10 | Bruising: ${e.bruisingLevel ?? "n/a"}/10 | Redness: ${e.rednessLevel ?? "n/a"}/10`
        : `  (no photo metrics recorded)`;
      const notesLine = e.notes?.trim()
        ? `  Notes: "${e.notes.trim()}"`
        : `  (no notes written)`;
      const photoLine = e.hasPhoto ? "  Photo: yes" : "  Photo: no";
      return `${e.date} (${dayLabel}):\n${notesLine}\n${metricsLine}\n${photoLine}`;
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

5. ALERTS: Return only clinically relevant weekly alerts. Each alert should include severity, title, explanation, and recommendedNextStep. If nothing needs attention, return an empty array.

6. METRIC_POINTS: Echo back a compact version of the week entries in order. Include date, dayNumber, painLevel, swellingLevel, bruisingLevel, rednessLevel, and hasPhoto.

Set weekNumber to ${weekNumber}.
Tone: Warm, specific, never generic. Keep it concise.`;
}

function trendLabel(values: number[]): string | null {
  if (values.length < 2) return null;
  const first = values[0];
  const last = values[values.length - 1];
  const delta = last - first;
  if (delta <= -1) return "Improving";
  if (delta >= 1) return "Needs attention";
  return "Stable";
}

function statusLabel(values: number[]): string | null {
  if (values.length === 0) return null;
  const avg = values.reduce((sum, value) => sum + value, 0) / values.length;
  if (avg < 2.5) return "Normal";
  if (avg < 4.5) return "Mild";
  if (avg < 6.5) return "Moderate";
  return "Elevated";
}

function increasingThreeLogs(values: number[]): boolean {
  if (values.length < 3) return false;
  const recent = values.slice(-3);
  return recent[0] < recent[1] && recent[1] < recent[2];
}

function buildHeuristicAlerts(entries: EntryPayload[]): RecoveryAlert[] {
  const alerts: RecoveryAlert[] = [];
  const pain = entries.map((entry) => entry.painLevel).filter((value): value is number => value != null);
  const swelling = entries.map((entry) => entry.swellingLevel).filter((value): value is number => value != null);
  const bruising = entries.map((entry) => entry.bruisingLevel).filter((value): value is number => value != null);

  if (increasingThreeLogs(pain)) {
    alerts.push({
      severity: "warning",
      title: "Pain is trending up",
      explanation: "Pain increased across your last 3 logs this week.",
      recommendedNextStep: "Keep logging tomorrow, and contact your provider if the increase continues or feels sharp.",
      metric: "Pain",
    });
  }

  if (increasingThreeLogs(swelling)) {
    alerts.push({
      severity: "warning",
      title: "Swelling is rising",
      explanation: "Swelling increased across your last 3 logs this week.",
      recommendedNextStep: "Watch tomorrow's swelling closely and contact your provider if it worsens again or feels sudden.",
      metric: "Swelling",
    });
  }

  if (bruising.length > 0 && bruising[bruising.length - 1] >= 7) {
    alerts.push({
      severity: "info",
      title: "Bruising remains elevated",
      explanation: "Bruising is still relatively high in your latest weekly entry.",
      recommendedNextStep: "Keep documenting it so the app can tell whether it is fading or lingering.",
      metric: "Bruising",
    });
  }

  return alerts;
}

function computeConsistencyRate(entries: EntryPayload[]): number | null {
  if (entries.length === 0) return null;
  const uniqueDays = new Set(entries.map((entry) => entry.dayNumber)).size;
  return Math.min(100, Math.round((uniqueDays / 7) * 100));
}

function computeRecoveryScore(entries: EntryPayload[], consistencyRate: number | null): number | null {
  const symptoms = entries.flatMap((entry) => [
    entry.painLevel,
    entry.swellingLevel,
    entry.bruisingLevel,
    entry.rednessLevel,
  ]).filter((value): value is number => value != null);

  if (symptoms.length === 0 && consistencyRate == null) return null;

  const burden = symptoms.length === 0
    ? 4
    : symptoms.reduce((sum, value) => sum + value, 0) / symptoms.length;
  const symptomScore = Math.max(0, Math.min(100, Math.round((10 - burden) * 10)));
  const consistencyScore = consistencyRate ?? 0;
  return Math.max(0, Math.min(100, Math.round((symptomScore * 0.75) + (consistencyScore * 0.25))));
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
    const { procedureId, procedureName, weekNumber, scheduledDate, completedEntryId, entries } = body;

    if (!procedureId || !procedureName || typeof weekNumber !== 'number' || !scheduledDate) {
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

    const aiResult: SummaryResult = JSON.parse(rawText);
    const painTrend = trendLabel(entries.map((entry) => entry.painLevel).filter((value): value is number => value != null));
    const swellingStatus = statusLabel(entries.map((entry) => entry.swellingLevel).filter((value): value is number => value != null));
    const bruisingStatus = statusLabel(entries.map((entry) => entry.bruisingLevel).filter((value): value is number => value != null));
    const rednessStatus = statusLabel(entries.map((entry) => entry.rednessLevel).filter((value): value is number => value != null));
    const consistencyRate = computeConsistencyRate(entries ?? []);
    const recoveryScore = computeRecoveryScore(entries ?? [], consistencyRate);
    const heuristicAlerts = buildHeuristicAlerts(entries ?? []);
    const mergedAlerts = [...heuristicAlerts, ...(aiResult.alerts ?? [])]
      .filter((alert, index, arr) =>
        arr.findIndex((candidate) => candidate.title === alert.title && candidate.metric === alert.metric) === index
      );
    const metricPoints = (entries ?? []).map((entry) => ({
      date: entry.date,
      dayNumber: entry.dayNumber,
      painLevel: entry.painLevel ?? null,
      swellingLevel: entry.swellingLevel ?? null,
      bruisingLevel: entry.bruisingLevel ?? null,
      rednessLevel: entry.rednessLevel ?? null,
      hasPhoto: !!entry.hasPhoto,
    }));

    const result = {
      ...aiResult,
      painTrend,
      swellingStatus,
      bruisingStatus,
      rednessStatus,
      recoveryScore,
      consistencyRate,
      alerts: mergedAlerts,
      metricPoints,
    };

    const reportRow = {
      user_id: user.id,
      procedure_id: procedureId,
      procedure_name: procedureName,
      week_number: weekNumber,
      scheduled_date: scheduledDate,
      completed_entry_id: completedEntryId ?? null,
      is_completed: !!completedEntryId,
      headline: result.headline,
      observation: result.observation,
      improvement: result.improvement,
      concern: result.concern,
      pain_trend: result.painTrend,
      swelling_status: result.swellingStatus,
      bruising_status: result.bruisingStatus,
      redness_status: result.rednessStatus,
      recovery_score: result.recoveryScore,
      consistency_rate: result.consistencyRate,
      alerts: result.alerts,
      metric_points: result.metricPoints,
      generated_at: new Date().toISOString(),
    };

    await userClient
      .from("weekly_recovery_reports")
      .upsert(reportRow, { onConflict: "user_id,procedure_id,week_number" });

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

    return new Response(JSON.stringify({
      ...result,
      scheduledDate,
      completedEntryId: completedEntryId ?? null,
      isCompleted: !!completedEntryId,
      satisfactionRating: null,
      generatedAt: reportRow.generated_at,
    }), {
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
