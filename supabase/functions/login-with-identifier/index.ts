import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.117.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Metodo non consentito" }, 405);

  try {
    const { identifier, password } = await req.json();
    if (typeof identifier !== "string" || typeof password !== "string" || identifier.trim().length < 3 || password.length < 1) {
      return json({ error: "Credenziali non valide" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !serviceRole || !anonKey) return json({ error: "Configurazione server non disponibile" }, 500);

    const admin = createClient(supabaseUrl, serviceRole, { auth: { persistSession: false, autoRefreshToken: false } });
    const normalized = identifier.trim().toLowerCase();
    const { data: profile, error: profileError } = await admin.from("profiles").select("id").eq("username", normalized).maybeSingle();
    if (profileError || !profile?.id) return json({ error: "Credenziali non valide" }, 401);

    const { data: userData, error: userError } = await admin.auth.admin.getUserById(profile.id);
    const email = userData?.user?.email;
    if (userError || !email) return json({ error: "Credenziali non valide" }, 401);

    const authClient = createClient(supabaseUrl, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data, error } = await authClient.auth.signInWithPassword({ email, password });
    if (error || !data.session) return json({ error: "Credenziali non valide" }, 401);

    return json({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_in: data.session.expires_in,
    });
  } catch {
    return json({ error: "Credenziali non valide" }, 401);
  }
});
