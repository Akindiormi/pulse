import { corsHeaders, json, requireUser } from '../_shared/auth.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const { client, user } = await requireUser(req);
    const body = await req.json().catch(() => ({}));
    if (body == null || typeof body !== 'object' || Array.isArray(body)) return json({ code: 'invalid-argument', message: 'Request data must be an object.' }, 422);
    const keys = Object.keys(body);
    if (keys.some((key) => key !== 'idempotencyKey')) return json({ code: 'invalid-argument', message: 'Only idempotencyKey is accepted.' }, 422);
    if (body.idempotencyKey != null && (typeof body.idempotencyKey !== 'string' || body.idempotencyKey.length > 128)) return json({ code: 'invalid-argument', message: 'Invalid idempotencyKey.' }, 422);

    const { data, error } = await client.rpc('complete_challenge', { p_uid: user.id });
    if (error) {
      console.error(error);
      return json({ code: 'failed-precondition', message: 'The challenge could not be completed.' }, 422);
    }
    if (!data || typeof data !== 'object') return json({ code: 'internal', message: 'The backend returned an invalid completion result.' }, 500);
    return json(data);
  } catch (error) {
    if (error instanceof Response) return error;
    console.error(error);
    return json({ code: 'internal', message: 'Something went wrong on the server.' }, 500);
  }
});
