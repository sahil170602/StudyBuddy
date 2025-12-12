// supabase/functions/ai_chat/index.ts
import { serve } from "https://deno.land/std@0.201.0/http/server.ts";

const GEMINI_KEY = Deno.env.get("GEMINI_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE") || ""; // optional for logging

if (!GEMINI_KEY) {
  console.error("GEMINI_API_KEY not set");
}

async function callGemini(prompt: string, maxTokens = 512) {
  if (!GEMINI_KEY) throw new Error("GEMINI_API_KEY not set");
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=${GEMINI_KEY}`;

  const body = {
    // Use simple prompt wrapper; tune temperature / safety as desired
    prompt: {
      text: prompt
    },
    temperature: 0.2,
    candidateCount: 1,
    // set other options if needed
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`Gemini API error ${resp.status}: ${txt}`);
  }

  return await resp.json();
}

async function maybeLogUsage(userId: string | null, funcName: string, tokens = 0, cost = 0.0) {
  // optional logging: insert row into ai_usage via Supabase REST (service-role key required)
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE || !userId) return;
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/ai_usage`, {
      method: "POST",
      headers: {
        "apikey": SUPABASE_SERVICE_ROLE,
        "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE}`,
        "Content-Type": "application/json",
        "Prefer": "return=representation"
      },
      body: JSON.stringify({
        user_id: userId,
        function_name: funcName,
        tokens_used: tokens,
        cost_estimated: cost
      })
    });
  } catch (e) {
    console.warn("ai_usage log failed", e);
  }
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ ok: false, error: "POST only" }), { status: 405 });
    }

    const payload = await req.json().catch(() => ({}));
    const message = (payload.message || "").toString();
    const userProfile = payload.userProfile || {};
    const userId = (() => {
      // attempt to extract user id from Authorization JWT if present
      try {
        const auth = req.headers.get("authorization");
        if (auth && auth.startsWith("Bearer ")) {
          // We don't fully validate JWT here; Supabase will sign tokens.
          // If you need to validate, use Supabase admin endpoints.
          const token = auth.substring(7);
          // do a simple decode of the payload (not secure validation) to get sub
          const parts = token.split(".");
          if (parts.length === 3) {
            const payloadJson = JSON.parse(atob(parts[1]));
            return payloadJson?.sub ?? null;
          }
        }
      } catch (_) {}
      return null;
    })();

    if (!message) {
      return new Response(JSON.stringify({ ok: false, error: "message required" }), { status: 400 });
    }

    // Prompt template
    const prompt = `You are StudyBuddy — a friendly AI tutor for students.
User profile: ${JSON.stringify(userProfile)}
User message: ${message}

Respond as a helpful tutoring assistant. If the user asks to generate a quiz or a schedule, return a JSON block (only JSON) with clear keys. Otherwise return a concise explanatory answer.

Always be helpful and polite.`;

    const raw = await callGemini(prompt, 512);

    // Extract text safely from common Gemini response shapes
    let reply = "";
    try {
      const cand = raw?.candidates?.[0];
      reply =
        cand?.content?.parts?.[0]?.text ??
        cand?.output?.[0]?.content?.[0]?.text ??
        (typeof cand === "string" ? cand : JSON.stringify(cand));
    } catch (e) {
      reply = JSON.stringify(raw).slice(0, 4000);
    }

    // Optional: estimate tokens/cost (simple heuristic)
    const tokenEstimate = Math.max(1, Math.floor(reply.length / 4));
    const costEstimate = tokenEstimate * 0.000001; // put your per-token cost here

    await maybeLogUsage(userId, "ai_chat", tokenEstimate, costEstimate);

    return new Response(JSON.stringify({ ok: true, reply, raw }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("ai_chat error:", err);
    return new Response(JSON.stringify({ ok: false, error: err?.message ?? String(err) }), { status: 500 });
  }
});
