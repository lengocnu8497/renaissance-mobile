// supabase/functions/generate-onboarding-teaser/index.ts
//
// Generates a short personalized onboarding teaser for Researching, Planning,
// or Recovering users using Gemini 2.5 Flash.
// Called at the end of the branched onboarding intake, before the paywall.
// Input:  branch context + user-selected data points
// Output: { headline, body, bullets[] }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const GOOGLE_AI_STUDIO_API_KEY = Deno.env.get("GOOGLE_AI_STUDIO_API_KEY")!;
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface OnboardingTeaserRequest {
  branch: "researching" | "planning" | "recovering";
  // Shared
  procedureName?: string | null;
  bodyAreas?: string[];
  healthFlags?: string[];
  // Researching
  researchStage?: string | null;
  researchNeeds?: string[];
  // Planning
  consultationStatus?: string | null;
  planningTimeline?: string | null;
  // Recovering
  procedureDate?: string | null;   // ISO8601
  emotionalState?: string | null;
}

interface OnboardingTeaserResponse {
  headline: string;
  body: string;
  bullets: string[];
}

const responseSchema = {
  type: "OBJECT",
  properties: {
    headline: {
      type: "STRING",
      description: "One punchy sentence personalised to the user's data. Under 12 words.",
    },
    body: {
      type: "STRING",
      description: "2–3 sentences that reference at least two specific data points the user provided.",
    },
    bullets: {
      type: "ARRAY",
      description: "3–4 specific, actionable items personalised to the user's branch and data.",
      items: { type: "STRING" },
    },
  },
  required: ["headline", "body", "bullets"],
};

function buildPrompt(req: OnboardingTeaserRequest): { system: string; user: string } {
  const system = `You are Rena, a knowledgeable and warm AI guide for people navigating aesthetic procedures.
You write like a trusted friend who knows the space deeply — never clinical, never judgmental.
Your job is to write a short personalised teaser that makes the user feel seen and gives them a genuine free taste of value.
RULES:
- Mention at least two specific data points the user provided (procedure, timing, health flags, emotional state, etc.)
- Never use filler phrases like "Based on what you've told me" — just reference the data naturally
- Bullets must be specific, not generic ("questions to ask your surgeon about keloid risk" > "prepare for your consultation")
- Tone: knowledgeable friend, not medical professional
- Never grade, warn, or alarm the user
- Return valid JSON only`;

  let userPrompt = "";

  if (req.branch === "researching") {
    const procedure = req.procedureName ?? "the procedure you're researching";
    const stage = req.researchStage ?? "early research";
    const needs = req.researchNeeds?.join(", ") ?? "";
    const areas = req.bodyAreas?.join(", ") ?? "";
    userPrompt = `Branch: researching
Procedure interest: ${procedure}${areas ? ` (${areas})` : ""}
Research stage: ${stage}
What they want answered: ${needs || "not specified"}
Health considerations: ${req.healthFlags?.join(", ") || "none"}

Write a teaser that feels like a head-start — 3 things they should know first, framed for someone in the "${stage}" stage. Make bullets concrete to ${procedure}.`;
  } else if (req.branch === "planning") {
    const procedure = req.procedureName ?? "the procedure";
    const consultation = req.consultationStatus ?? "not yet booked";
    const timeline = req.planningTimeline ?? "undecided";
    const healthFlags = req.healthFlags?.join(", ") ?? "";
    userPrompt = `Branch: planning
Procedure: ${procedure}
Consultation status: ${consultation}
Timeline: ${timeline}
Health considerations: ${healthFlags || "none"}

Write a teaser that helps them prepare for ${procedure} given a "${consultation}" consultation status and a "${timeline}" timeline. If health flags are present, reference them in at least one bullet.`;
  } else {
    // recovering
    const procedure = req.procedureName ?? "the procedure";
    const emotion = req.emotionalState ?? "not specified";
    const healthFlags = req.healthFlags?.join(", ") ?? "";
    const date = req.procedureDate
      ? `(procedure date: ${req.procedureDate})`
      : "";
    userPrompt = `Branch: recovering
Procedure: ${procedure} ${date}
Emotional state: ${emotion}
Health considerations: ${healthFlags || "none"}

Write a teaser that addresses how they're feeling (${emotion}) and gives them 3–4 things that are most useful right now in recovery from ${procedure}. Reference the emotional state and at least one health flag if present.`;
  }

  return { system, user: userPrompt };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: OnboardingTeaserRequest = await req.json();
    const { system, user: userPrompt } = buildPrompt(body);

    const geminiBody = JSON.stringify({
      system_instruction: { parts: [{ text: system }] },
      contents: [{ parts: [{ text: userPrompt }] }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema,
        temperature: 0.7,
        maxOutputTokens: 2048,
      },
    });

    let geminiResponse!: Response;
    for (let attempt = 0; attempt < 3; attempt++) {
      geminiResponse = await fetch(`${GEMINI_URL}?key=${GOOGLE_AI_STUDIO_API_KEY}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: geminiBody,
      });
      if (geminiResponse.status !== 503) break;
      if (attempt < 2) await new Promise(r => setTimeout(r, 800 * (attempt + 1)));
    }

    if (!geminiResponse.ok) {
      const errText = await geminiResponse.text();
      console.error("Gemini error:", errText);
      return new Response(JSON.stringify({ error: "AI generation failed" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const geminiJson = await geminiResponse.json();
    const rawText = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    if (!rawText) {
      console.error("Gemini returned empty content. Full response:", JSON.stringify(geminiJson));
      return new Response(JSON.stringify({ error: "AI generation failed" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    // Strip markdown code fences Gemini sometimes adds (```json ... ```)
    const cleaned = rawText.replace(/^```(?:json)?\s*/i, "").replace(/\s*```\s*$/i, "").trim();
    const parsed: OnboardingTeaserResponse = JSON.parse(cleaned);

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("generate-onboarding-teaser error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
