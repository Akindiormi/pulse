import { createClient } from 'npm:@supabase/supabase-js@2';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function adminClient() {
  const url = Deno.env.get('SUPABASE_URL') ?? '';
  const secret = Deno.env.get('PULSE_SUPABASE_SECRET_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!url || !secret) throw new Error('Supabase server configuration is missing.');
  return createClient(url, secret, { auth: { autoRefreshToken: false, persistSession: false } });
}

export async function requireUser(req: Request) {
  const authorization = req.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) throw new Response(JSON.stringify({ code: 'unauthenticated', message: 'Authentication is required.' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  const token = authorization.slice('Bearer '.length);
  const client = adminClient();
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) throw new Response(JSON.stringify({ code: 'unauthenticated', message: 'Authentication is required.' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  return { client, user: data.user };
}

export function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}
