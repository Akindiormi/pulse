import { adminClient, corsHeaders, json, requireUser } from '../_shared/auth.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const { client, user } = await requireUser(req);
    const body = await req.json().catch(() => ({}));
    if (body == null || typeof body !== 'object' || Array.isArray(body) || Object.keys(body).length !== 0) {
      return json({ code: 'invalid-argument', message: 'This operation does not accept client-controlled arguments.' }, 422);
    }
    const { data, error } = await client.rpc('get_or_assign_daily_challenge', { p_uid: user.id });
    if (error) {
      console.error(error);
      return json({ code: 'failed-precondition', message: 'The daily challenge could not be assigned.' }, 422);
    }
    const row = Array.isArray(data) ? data[0] : data;
    if (!row) return json({ code: 'internal', message: 'The backend returned an invalid daily challenge.' }, 500);
    return json({ date: row.date, challengeId: row.challenge_id, completed: row.completed === true, assignedAt: row.assigned_at });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error(error);
    return json({ code: 'internal', message: 'Something went wrong on the server.' }, 500);
  }
});
