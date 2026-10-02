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
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) return json({ error: "Non autenticato" }, 401);

    const token = authHeader.slice("Bearer ".length);
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRole) {
      return json({ error: "Configurazione server non disponibile" }, 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser(token);
    const user = userData.user;
    if (userError || !user) return json({ error: "Sessione non valida" }, 401);

    const body = await req.json();
    const action = body?.action;
    const code = String(body?.code ?? "").trim().toUpperCase();
    if (!["preview", "join"].includes(action) || !/^[A-Z0-9]{8}$/.test(code)) {
      return json({ error: "Richiesta non valida" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRole, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: match, error: matchError } = await admin
      .from("matches")
      .select("*")
      .eq("invite_code", code)
      .eq("status", "open")
      .maybeSingle();

    if (matchError) return json({ error: "Errore durante la verifica dell'invito" }, 500);
    if (!match) return json({ error: "Invito non valido o partita non disponibile" }, 404);

    if (action === "preview") {
      const [{ count: confirmed }, { count: waitlist }] = await Promise.all([
        admin.from("match_players").select("*", { count: "exact", head: true }).eq("match_id", match.id).eq("status", "confirmed"),
        admin.from("match_players").select("*", { count: "exact", head: true }).eq("match_id", match.id).eq("status", "waitlist"),
      ]);

      return json({
        match: {
          id: match.id,
          creator_id: match.creator_id,
          title: match.title,
          starts_at: match.starts_at,
          venue_name: match.venue_name,
          venue_address: match.venue_address,
          max_players: match.max_players,
          bench_slots: match.bench_slots,
          team_mode: match.team_mode,
          rating_mode: match.rating_mode,
          team_a_name: match.team_a_name,
          team_b_name: match.team_b_name,
          status: match.status,
          score_a: match.score_a,
          score_b: match.score_b,
          ratings_open: match.ratings_open,
          invite_code: match.invite_code,
          confirmed_count: confirmed ?? 0,
          waitlist_count: waitlist ?? 0,
        },
      });
    }

    const { data: existing, error: existingError } = await admin
      .from("match_players")
      .select("match_id")
      .eq("match_id", match.id)
      .eq("user_id", user.id)
      .maybeSingle();

    if (existingError) return json({ error: "Errore durante l'ingresso" }, 500);
    if (existing) return json({ match_id: match.id });

    const { error: joinError } = await admin.from("match_players").insert({
      match_id: match.id,
      user_id: user.id,
      team: "unassigned",
    });

    if (joinError) {
      const message = joinError.message.includes("Lobby completa")
        ? "Lobby completa"
        : joinError.message.includes("Partita non disponibile")
        ? "Partita non disponibile"
        : "Non è stato possibile entrare nella partita";
      return json({ error: message }, 409);
    }

    return json({ match_id: match.id });
  } catch {
    return json({ error: "Richiesta non valida" }, 400);
  }
});
