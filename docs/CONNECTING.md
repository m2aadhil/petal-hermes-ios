# Connect Petal to Hermes over Tailscale

Petal needs the official **`hermes serve`** process. The messaging gateway used by Telegram, Discord and other channels is a separate process. Hermes should already be configured and able to answer a CLI chat.

## 1. Join the private network

Install/enable Tailscale on the Hermes host and iPhone and sign into the same tailnet. Keep Tailscale connected on the iPhone. Your tailnet rules must allow the phone to reach the Hermes host.

## 2. Configure Hermes' own authentication

Edit the secrets file for the Hermes profile serving the backend. In a standard default installation this is `~/.hermes/.env`; with a custom `HERMES_HOME`, use that directory instead. Add these keys with your own values:

```dotenv
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=your-username
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=your-long-password
HERMES_DASHBOARD_BASIC_AUTH_SECRET=your-stable-random-signing-secret
```

Generate the signing secret with `openssl rand -hex 32`, then paste its output as the value. Do not paste the command as a literal value. Preserve existing credentials and keep the file private (`chmod 600`). A stable signing secret lets valid sessions survive backend restarts.

The native password provider is designed for a trusted network, including Tailscale. [Official Hermes remote-backend guide](https://hermes-agent.nousresearch.com/docs/user-guide/desktop#connecting-to-a-remote-backend).

## 3. Start the native backend

On the server:

```sh
tailscale ip -4
hermes serve --host <the-Tailscale-IP-above> --port 9119
```

Keep that process running using your normal service/process manager. Petal does not install another server, copy your Hermes data or start an SSH tunnel.

In Petal, enter `http://<the-Tailscale-IP>:9119` and the native Hermes username/password. A short MagicDNS name also works if the iPhone resolves it. Petal tests both HTTP and the authenticated WebSocket before saving the connection.

## Optional: HTTPS with Tailscale Serve

Set the public URL in the serving profile's `config.yaml` to the **actual HTTPS name** Tailscale gives the host:

```yaml
dashboard:
  public_url: https://your-host.your-tailnet.ts.net
```

This setting is important: it declares the trusted proxy hostname and engages Hermes' auth gate even when the backend binds to loopback.

```sh
hermes serve --host 127.0.0.1 --port 9119
# In another terminal:
tailscale serve --bg http://127.0.0.1:9119
```

Enter the resulting HTTPS URL in Petal. Tailscale Serve remains private to your tailnet; Funnel is not needed. [Official Tailscale Serve reference](https://tailscale.com/docs/reference/tailscale-cli/serve).

## If it doesn't connect

| Symptom | Check |
| --- | --- |
| Timeout | Tailscale is connected on both devices, the backend process is running, the bind IP/port and tailnet grants are correct. |
| HTTP works but chat fails | The proxy must forward WebSocket upgrades and the `/api/ws` path. A ticket is single-use and minted just before connecting. |
| Sign-in fails | Check native dashboard credentials and that `/api/status` advertises `basic`. A model provider API key is not a Petal login. |
| Login expires on every server restart | Set a stable `HERMES_DASHBOARD_BASIC_AUTH_SECRET`. |
| Keychain error in Simulator | Leave code signing enabled for the simulator test/run. No paid team is needed for simulator signing. |
| Profile or bot unavailable | Update Hermes and use its current `hermes serve` backend. Petal doesn't replace a missing canonical chat after a failed lookup. |
| OAuth-only server | This initial release doesn't implement the browser-based Nous/OIDC sign-in. Use the native private-network password provider, or an existing supported legacy session token on a backend configured for that mode. |

Removing a connection in Petal erases its cached chats and credentials on that iPhone. It does not delete any server-side conversation or profile.

## Staying signed in

Hermes' password sign-in lasts 12 hours by default and issues no refresh token. Two server settings affect how often you're asked to sign in again:

```sh
# Required for sessions to survive a server restart (otherwise a random key is generated on every start):
HERMES_DASHBOARD_BASIC_AUTH_SECRET=$(openssl rand -hex 32)
# Optional: longer sessions (seconds). 2592000 = 30 days.
HERMES_DASHBOARD_BASIC_AUTH_TTL_SECONDS=2592000
```

With **Stay signed in** turned on in the app (the default), Petal keeps your username and password in this iPhone's Keychain (this device only, never synced) and signs in again silently when the session expires. If the server rejects the saved password, the app deletes it and shows the sign-in form. To stop saving it, reconnect from Settings with the switch turned off. Removing the connection deletes everything stored for it.
