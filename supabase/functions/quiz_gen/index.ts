// supabase/functions/quiz_gen/index.ts
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
    const { syllabus, count = 10, difficulty = "medium", classLevel } = await req.json();

    if (!syllabus || syllabus.trim().length === 0) {
      return new Response(JSON.stringify({ ok: false, error: "syllabus required" }), { status: 400 });
    }

    // Strict JSON output instruction — ask model to return only the JSON array
    const prompt = `Generate ${count} multiple-choice questions from the syllabus below.
Output MUST be a JSON array. Each item MUST be:
{ "question": "...", "options": ["A","B","C","D"], "correctIndex": 0, "explanation":"..." }
Syllabus:
${syllabus}
Difficulty: ${difficulty}
Class level: ${classLevel || "unspecified"}

Return only the JSON array, no extra commentary.`;

    const raw = await callGemini(prompt);
    let text = "";
    const cand = raw?.candidates?.[0];
    text = cand?.content?.parts?.[0]?.text ?? JSON.stringify(raw);

    // Try extracting JSON array robustly
    let parsed = null;
    try {
      parsed = JSON.parse(text);
    } catch (_) {
      const m = text.match(/\[[\s\S]*\]/);
      if (m) parsed = JSON.parse(m[0]);
    }

    if (!parsed) {
      return new Response(JSON.stringify({ ok: false, error: "Could not parse quiz JSON", rawText: text }), { status: 500 });
    }

    return new Response(JSON.stringify({ ok: true, quiz: parsed }), { headers: { "Content-Type": "application/json" } });
  } catch (err: any) {
    console.error("quiz_gen error:", err);
    return new Response(JSON.stringify({ ok: false, error: err?.message ?? String(err) }), { status: 500 });
  }
});
