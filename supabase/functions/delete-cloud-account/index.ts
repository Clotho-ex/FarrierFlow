import { readDeletionConfiguration } from './environment.ts';
import { createDeletionHandler } from './handler.ts';
import { HTTPDeletionBackend } from './http.ts';

Deno.serve(async (request: Request) => {
  try {
    // Read per request: an operator can repair missing/rotated secrets without
    // logging their values or leaving a warm instance on an obsolete key.
    const configuration = readDeletionConfiguration((name) => Deno.env.get(name));
    const handler = createDeletionHandler({ ...configuration,
      backend: new HTTPDeletionBackend(configuration.backend), now: () => Math.floor(Date.now() / 1_000) });
    return await handler(request);
  } catch {
    return Response.json({ error: 'deletion_unavailable' }, {
      status: 503, headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
    });
  }
});
