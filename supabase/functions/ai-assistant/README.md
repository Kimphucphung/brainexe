# ai-assistant

Supabase Edge Function that keeps the Gemini API key on the server so users do not need to paste their own key.

Deploy once:

```powershell
supabase login
supabase link --project-ref zjjfxsyyzypvyactnyry
supabase secrets set GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
supabase functions deploy ai-assistant
```

Optional model override:

```powershell
supabase secrets set GEMINI_MODEL="gemini-2.5-flash"
```

The function requires a logged-in Supabase user. If it is not deployed yet, the frontend falls back to the optional personal API key flow.
