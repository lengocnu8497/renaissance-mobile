// supabase/functions/analyze-photo/index.ts
// Gemini 2.5 Flash vision analysis for post-procedure recovery tracking.
// Called by the iOS app with a signed photo URL + procedure context.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GOOGLE_AI_STUDIO_API_KEY = Deno.env.get("GOOGLE_AI_STUDIO_API_KEY")!;
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

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
    // Verify JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: AnalysisRequest = await req.json();
    const { photoUrl, procedureName, dayNumber } = body;

    if (!photoUrl || !procedureName) {
      return new Response(JSON.stringify({ error: "Missing photoUrl or procedureName" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch the image and base64-encode it for Gemini inline data
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
