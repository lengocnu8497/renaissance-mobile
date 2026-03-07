// supabase/functions/analyze-photo/index.ts
// Gemini 2.5 Flash vision analysis for post-procedure recovery tracking.
// Called by the iOS app with a signed photo URL + procedure context.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2'

const GOOGLE_AI_STUDIO_API_KEY = Deno.env.get("GOOGLE_AI_STUDIO_API_KEY")!;
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

// Cost per analysis: 1 image slot + 4 credits (mirrors chat image analysis cost)
const ANALYSIS_IMAGE_COST  = 1
const ANALYSIS_CREDIT_COST = 4

/**
 * Safely subtracts one calendar month, clamping to the last day of the target
 * month when the source day doesn't exist there (e.g. Mar 31 → Feb 28).
 */
function subtractOneMonth(date: Date): Date {
  const d = new Date(date)
  const originalDay = d.getDate()
  d.setMonth(d.getMonth() - 1)
  if (d.getDate() !== originalDay) {
    d.setDate(0)
  }
  return d
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface AnalysisRequest {
  photoUrl: string;       // signed Supabase Storage URL
  procedureName: string;
  dayNumber: number;      // 0 = day of procedure
}

interface ZoneResult {
  zone: string;
  score: number;          // 0–10
  notes: string | null;
}

interface AnalysisResult {
  swellingIndex: number;
  bruisingIndex: number;
  rednessIndex: number;
  overallScore: number;
  summary: string;
  zones: ZoneResult[];
}

const responseSchema = {
  type: "OBJECT",
  properties: {
    swellingIndex:  { type: "NUMBER", description: "Visible swelling severity 0–10" },
    bruisingIndex:  { type: "NUMBER", description: "Visible bruising severity 0–10" },
    rednessIndex:   { type: "NUMBER", description: "Visible redness/erythema severity 0–10" },
    overallScore:   { type: "NUMBER", description: "Composite recovery score 0–10 (10 = fully recovered)" },
    summary:        { type: "STRING", description: "1–2 sentence plain-language recovery summary" },
    zones: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          zone:   { type: "STRING" },
          score:  { type: "NUMBER", description: "Recovery score for this zone 0–10" },
          notes:  { type: "STRING", nullable: true },
        },
        required: ["zone", "score"],
      },
    },
  },
  required: ["swellingIndex", "bruisingIndex", "rednessIndex", "overallScore", "summary", "zones"],
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // -------------------------------------------------------------------------
    // AUTHENTICATION: Verify JWT and resolve user identity
    // -------------------------------------------------------------------------
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // User-scoped client — used only for reading user data under RLS
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    // Service-role client — used only for quota operations (bypasses RLS)
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const adminClient = createClient(
      supabaseUrl,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await userClient.auth.getUser(token)

    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized - Invalid or expired token" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // -------------------------------------------------------------------------
    // AUTHORIZATION: Verify active paid subscription
    // -------------------------------------------------------------------------
    const { data: userProfile, error: profileError } = await userClient
      .from('user_profiles')
      .select('subscription_tier, subscription_current_period_end, subscription_status')
      .eq('id', user.id)
      .single()

    if (profileError || !userProfile) {
      return new Response(JSON.stringify({ error: "Failed to fetch user profile" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { subscription_tier, subscription_current_period_end, subscription_status } = userProfile

    const isActive = subscription_status === 'active'
    const isCanceledButStillInPeriod = subscription_status === 'canceled'
      && subscription_current_period_end
      && new Date(subscription_current_period_end) > new Date()

    if (!subscription_tier || (!isActive && !isCanceledButStillInPeriod)) {
      return new Response(JSON.stringify({
        error: 'No active subscription',
        code: 'NO_SUBSCRIPTION',
        message: 'Please upgrade to a Silver or Gold plan to use AI photo analysis.'
      }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // -------------------------------------------------------------------------
    // QUOTA ENFORCEMENT: Check usage limits before calling Gemini
    // -------------------------------------------------------------------------
    const periodEnd   = new Date(subscription_current_period_end)
    const periodStart = subtractOneMonth(periodEnd)

    const { data: usageRecord, error: usageError } = await adminClient
      .rpc('get_or_create_usage_record', {
        p_user_id:      user.id,
        p_period_start: periodStart.toISOString(),
        p_period_end:   periodEnd.toISOString(),
        p_tier:         subscription_tier
      })

    if (usageError || !usageRecord) {
      console.error('Failed to fetch usage record:', usageError)
      return new Response(JSON.stringify({ error: "Failed to fetch usage data" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const wouldExceedImages  = (usageRecord.images_used  + ANALYSIS_IMAGE_COST)  > usageRecord.images_limit
    const wouldExceedCredits = (usageRecord.credits_used + ANALYSIS_CREDIT_COST) > usageRecord.credits_limit

    if (wouldExceedImages || wouldExceedCredits) {
      const limitType = wouldExceedImages ? 'images' : 'credits'
      return new Response(JSON.stringify({
        error: 'Quota exceeded',
        code: 'QUOTA_EXCEEDED',
        limitType,
        usage: {
          images:  { used: usageRecord.images_used,  limit: usageRecord.images_limit },
          credits: { used: usageRecord.credits_used, limit: usageRecord.credits_limit }
        },
        periodEnd: subscription_current_period_end
      }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // -------------------------------------------------------------------------
    // INPUT VALIDATION
    // -------------------------------------------------------------------------
    const body: AnalysisRequest = await req.json();
    const { photoUrl, procedureName, dayNumber } = body;

    if (!photoUrl || !procedureName) {
      return new Response(JSON.stringify({ error: "Missing photoUrl or procedureName" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Validate dayNumber is a finite non-negative number to prevent prompt injection
    // via "day NaN/Infinity/undefined after the procedure"
    if (typeof dayNumber !== 'number' || !Number.isFinite(dayNumber) || dayNumber < 0) {
      return new Response(JSON.stringify({ error: "dayNumber must be a non-negative integer" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // SSRF guard: photoUrl must point to this project's Supabase Storage,
    // preventing the function from fetching internal metadata or private services.
    // Re-uses the URL already read for adminClient above.
    if (!photoUrl.startsWith(`${supabaseUrl}/storage/`)) {
      return new Response(JSON.stringify({ error: "photoUrl must be a Supabase Storage URL" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // -------------------------------------------------------------------------
    // ANALYSIS: Fetch image and call Gemini
    // -------------------------------------------------------------------------
    const imgResponse = await fetch(photoUrl);
    if (!imgResponse.ok) {
      throw new Error(`Failed to fetch photo: ${imgResponse.status}`);
    }
    const imgBuffer = await imgResponse.arrayBuffer();
    const bytes = new Uint8Array(imgBuffer);
    let binary = "";
    const chunkSize = 8192;
    for (let i = 0; i < bytes.length; i += chunkSize) {
      binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
    }
    const base64Image = btoa(binary);
    const mimeType = imgResponse.headers.get("content-type") ?? "image/jpeg";

    const dayLabel = dayNumber === 0 ? "the day of the procedure" : `day ${dayNumber} after the procedure`;

    const prompt = `You are a clinical recovery assessment assistant. Analyze this photo taken on ${dayLabel} following a ${procedureName} procedure.

Evaluate:
1. Swelling (edema) — visible puffiness or volume changes
2. Bruising (ecchymosis) — discoloration, purple/yellow/green patches
3. Redness (erythema) — skin redness, irritation
4. Overall recovery progress

For each metric, provide a score from 0 (none/fully recovered) to 10 (severe/very early recovery).
Identify the facial/body zones affected (e.g., "upper lip", "lower eyelid", "jawline").
Write a brief, compassionate 1–2 sentence summary suitable for the patient.

Respond ONLY with valid JSON matching the provided schema.`;

    const geminiPayload = {
      contents: [
        {
          parts: [
            { text: prompt },
            { inline_data: { mime_type: mimeType, data: base64Image } },
          ],
        },
      ],
      generationConfig: {
        response_mime_type: "application/json",
        response_schema: responseSchema,
        temperature: 0.2,
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
      throw new Error(`Gemini API error ${geminiResponse.status}: ${errText}`);
    }

    const geminiData = await geminiResponse.json();
    const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!rawText) throw new Error("No content in Gemini response");

    const result: AnalysisResult = JSON.parse(rawText);

    // -------------------------------------------------------------------------
    // INCREMENT USAGE after successful analysis
    // -------------------------------------------------------------------------
    try {
      const { error: incrementError } = await adminClient
        .rpc('increment_usage', {
          p_usage_id: usageRecord.id,
          p_user_id:  user.id,
          p_messages: 0,
          p_images:   ANALYSIS_IMAGE_COST,
          p_credits:  ANALYSIS_CREDIT_COST
        })

      if (incrementError) {
        console.error('Failed to increment usage:', incrementError)
      }
    } catch (usageUpdateError) {
      console.error('Exception incrementing usage:', usageUpdateError)
    }

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("analyze-photo error:", err);
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : "Internal error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
