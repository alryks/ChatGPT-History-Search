<img src="icon.svg" alt="" width="80">

# ChatGPT History Search

Search your past ChatGPT conversations by keyword, read surrounding messages, and get links to the original chats.
Runs in Docker through OpenAI's Secure MCP Tunnel; no public domain or published host ports are needed.

## Setup

You need Docker Compose, a ChatGPT login saved by `codex login` on the Docker host, a [Secure MCP Tunnel](https://platform.openai.com/settings/organization/tunnels), and a [Platform API key](https://platform.openai.com/settings/organization/api-keys) with **Tunnels Read + Use** permissions.
An API-key login alone cannot access chat history.
See [OpenAI's tunnel guide](https://github.com/openai/tunnel-client/blob/master/docs/onboarding.md) for tunnel setup.

1. Copy [`.env.example`](.env.example) to `.env` and fill in `TUNNEL_ID` and `TUNNEL_API_KEY`.
   Set `CODEX_CREDENTIALS_DIR` to the directory containing your ChatGPT `auth.json` (default: `~/.codex`).
   Keep `.env` private.

   ```sh
   cp .env.example .env
   ```

2. Start the services:

   ```sh
   docker compose pull
   docker compose up -d
   ```

3. Add a custom MCP connection in ChatGPT, choose **Tunnel**, and select your tunnel ID.
   Keep the connection private: it can read the mounted account's chats.

Try asking:

> Find my chats about `your topic` and link me to the relevant conversations.

## Optional proxy

Set `HTTPS_PROXY` in `.env`, or leave it empty for direct access:

```dotenv
HTTPS_PROXY='socks5h://username:password@proxy-host:10808'
```

HTTP proxies also work (`http://host:port`).
Omit credentials if unnecessary; URL-encode special characters in them.
Both services use the proxy.
For a proxy on the Docker host, use `host.docker.internal`; the proxy must accept connections from Docker, not just host localhost.
Apply changes with `docker compose up -d`.

## Usage

- `search_chatgpt_messages`: keyword search with snippets, chat links, and pagination.
- `get_chatgpt_chat`: read messages around a match; adjust `before` and `after` for more context.

Both tools are read-only.
For errors, check `docker compose logs --tail=50`.
If the ChatGPT login expires, renew it with `codex login`; the server does not refresh credentials.
Stop with `docker compose down`.

This uses undocumented ChatGPT endpoints and may break when they change.
Keep the MCP port private: the HTTP server has no client authentication.
See the [API guide](CHATGPT_HISTORY_SEARCH_API.md) for technical details.
