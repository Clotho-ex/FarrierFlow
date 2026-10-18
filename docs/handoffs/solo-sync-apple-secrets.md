# FarrierFlow Apple deletion credentials — private operator handoff

These credentials are for server-side Apple authorization-code exchange and
revocation. They do not belong in the iPhone app, Git, chat, screenshots, or a
shared document. No private values have been entered or verified by this work.

## Create the Apple key yourself

If you already created and securely saved the FarrierFlow key, reuse it; do not
create a duplicate or revoke a working key merely to follow these instructions.

1. Open Apple Developer → Certificates, Identifiers & Profiles → Keys → **+**.
2. Name the key **FarrierFlow** and enable **Sign in with Apple**.
3. Configure primary App ID **com.farrierflow.yusufcan.FarrierFlow** under team
   **5SN9TWDXQ4**, then register and download the `.p8` file privately.
4. Record its Key ID and keep the one-time download in a private secure backup.
   Do not revoke an existing key or change another app's configuration.

[Apple's key creation instructions](https://developer.apple.com/help/account/capabilities/create-a-sign-in-with-apple-private-key).

## Enter server-only secrets yourself

In **FarrierFlow Dev**, project **xufledziawaapvrifbfv**, open Edge Functions →
Secrets. Enter and submit the following yourself; the agent must not inspect or
paste private key/secret contents.

| Secret name | Value |
| --- | --- |
| `FF_APPLE_TEAM_ID` | `5SN9TWDXQ4` |
| `FF_APPLE_KEY_ID` | Key ID from the new Apple key |
| `FF_APPLE_SIGNING_PRIVATE_KEY` | Entire `.p8` text, including BEGIN/END lines and real line breaks |
| `FF_APPLE_TOKEN_ENCRYPTION_KEY` | A new random 32-byte key in standard padded Base64 |
| `FF_DELETION_WORKER_KEY` | A separate new random 32-byte key in unpadded Base64url |

For the last two values, use a secure local generator. If using your own
Terminal, these commands generate the required formats; run them privately and
copy their output directly to the respective Supabase fields, not this chat:

```sh
openssl rand -base64 32
openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n'
```

Save each value in your password manager. The encryption key protects Apple
refresh tokens belonging to pending deletion jobs. Do not rotate it while jobs
still depend on it; rotation requires a separately reviewed migration.

Supabase injects `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEYS`, and
`SUPABASE_SECRET_KEYS`; the function uses their `default` entries internally.
Do not retrieve an administrative secret for the iPhone or add one to source.
The function fails closed if required configuration is absent or malformed.

The scheduled retry needs the **same** worker-key value stored privately in
Supabase Vault under **ff_deletion_worker_key**. Store the existing public Dev
publishable key separately as **ff_deletion_publishable_key**. The agent will
request approval for the schedule separately and guide that human-only entry. This narrowly
scoped key can run already-authorized deletion jobs; it cannot authorize a new
deletion or read business records through the endpoint.

[Supabase's server-secret instructions](https://supabase.com/docs/guides/functions/secrets).

## Deployment and acceptance are separate

The source endpoint routes are POST `delete-cloud-account/request`, `/status`,
and `/run`. The request verifies a live owner session, a fresh signed Apple
identity with a nonce, and an exchanged Apple grant for that same immutable
identity. It stores only an encrypted refresh token with job-bound authenticated
encryption. Status uses a random device-held receipt, not a user ID or email;
worker calls require the separate server-only worker key.

Gateway JWT verification is disabled specifically because completion must be
confirmable after Auth removal and workers do not carry a user JWT. The route
checks above are mandatory. Deployment/access changes require action-time
approval; setting secrets does not mean the function or scheduler is deployed.

Local tests and Deno type checking do not verify a real Apple grant, deployed
Storage cleanup, the retry schedule, or actual native iPhone behavior. Real
Apple sign-in, revocation, and two-iPhone acceptance remain deferred release
gates, as requested.
