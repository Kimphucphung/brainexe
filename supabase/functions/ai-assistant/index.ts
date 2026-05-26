import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
  if (!geminiApiKey) {
    return json({ error: "server AI is not configured" }, 500);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const authHeader = req.headers.get("Authorization") || "";
  if (!supabaseUrl || !supabaseAnonKey || !authHeader) {
    return json({ error: "authentication required" }, 401);
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) {
    return json({ error: "authentication required" }, 401);
  }

  let payload: { mode?: string; prompt?: string; lang?: string } = {};
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid json" }, 400);
  }

  const mode = String(payload.mode || "chat").slice(0, 40);
  const lang = payload.lang === "vi" ? "vi" : "en";
  const prompt = String(payload.prompt || "").trim().slice(0, 7000);
  if (!prompt) {
    return json({ error: "prompt is required" }, 400);
  }

  const guardrail = [
    "You are the AI assistant for brain.exe, an ADHD-friendly productivity app.",
    "Be practical, gentle, concise, and never preachy.",
    `Reply language: ${lang === "vi" ? "Vietnamese" : "English"}.`,
    `Mode: ${mode}.`,
    "",
    prompt,
  ].join("\n");

  const model = Deno.env.get("GEMINI_MODEL") || "gemini-2.5-flash";
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiApiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: guardrail }] }],
        generationConfig: {
          temperature: mode === "micro_tasks" ? 0.35 : 0.7,
          maxOutputTokens: mode === "report" ? 700 : 450,
        },
      }),
    },
  );

  const data = await response.json();
  if (!response.ok || data.error) {
    return json({ error: data.error?.message || "AI provider error" }, response.status || 502);
  }

  const text = data.candidates?.[0]?.content?.parts?.[0]?.text || "";
  return json({ text, mode });
});
