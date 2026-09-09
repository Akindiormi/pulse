import { corsHeaders, json, requireUser } from '../_shared/auth.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const { client, user } = await requireUser(req);
    const body = await req.json().catch(() => ({}));
    if (body == null || typeof body !== 'object' || Array.isArray(body) || Object.keys(body).length !== 0) {
      return json({ code: 'invalid-argument', message: 'This operation does not accept client-controlled arguments.' }, 422);
    }
    const { error } = await client.auth.admin.deleteUser(user.id);
    if (error) {
      console.error(error);
      return json({ code: 'internal', message: 'The account could not be deleted.' }, 500);
    }
    return json({ deleted: true });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error(error);
    return json({ code: 'internal', message: 'Something went wrong on the server.' }, 500);
  }
});
