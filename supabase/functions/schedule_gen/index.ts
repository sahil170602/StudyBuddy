// supabase/functions/schedule_gen/index.ts
import { serve } from "https://deno.land/std@0.201.0/http/server.ts";

const GEMINI_KEY = Deno.env.get("GEMINI_API_KEY") || "";

async function callGemini(prompt: string) {
  if (!GEMINI_KEY) throw new Error("GEMINI_API_KEY not set");
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=${GEMINI_KEY}`;
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ prompt: { text: prompt }, temperature: 0.2, candidateCount: 1 })
  });
  if (!resp.ok) throw new Error(`Gemini status ${resp.status}`);
  return await resp.json();
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response(JSON.stringify({ ok: false, error: "POST required" }), { status: 405 });

    const { date, wakeTime = "06:30", classStart = 8, prefs = {} } = await req.json();

    const prompt = `Create a detailed 24-hour student schedule for date ${date || "today"}.
Wake time: ${wakeTime}, class starts at ${classStart}:00.
Include study blocks, meals, naps, free time, and sleep. Respect preferences: ${JSON.stringify(prefs)}.
Output MUST be a JSON array of items:
[ { "start":"HH:MM", "end":"HH:MM", "title":"...", "note":"..." }, ... ]`;

    const raw = await callGemini(prompt);
    const cand = raw?.candidates?.[0];
    const text = cand?.content?.parts?.[0]?.text ?? JSON.stringify(raw);

    let parsed = null;
    try {
      parsed = JSON.parse(text);
    } catch (_) {
      const m = text.match(/\[[\s\S]*\]/);
      if (m) parsed = JSON.parse(m[0]);
    }

    if (!parsed) {
      return new Response(JSON.stringify({ ok: false, error: "Could not parse schedule JSON", rawText: text }), { status: 500 });
    }

    return new Response(JSON.stringify({ ok: true, schedule: parsed }), { headers: { "Content-Type": "application/json" } });
  } catch (err: any) {
    console.error("schedule_gen error:", err);
    return new Response(JSON.stringify({ ok: false, error: err?.message ?? String(err) }), { status: 500 });
  }
});
