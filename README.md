<img src="icon.svg" alt="" width="80">

# ChatGPT History Search

Let ChatGPT search your past conversations by keyword, read surrounding messages, and return links to the original chats.

Runs as an MCP server in Docker, connected to ChatGPT through OpenAI's Secure MCP Tunnel. No public domain or exposed host ports are needed.

## Requirements

- Docker with Docker Compose.
- A ChatGPT login saved by `codex login` on the Docker host.
  An OpenAI API-key login alone cannot access chat history.
- A [Secure MCP Tunnel](https://platform.openai.com/settings/organization/tunnels) and a [Platform runtime API key](https://platform.openai.com/settings/organization/api-keys) with **Tunnels Read + Use** permissions.
  See [OpenAI's setup guide](https://github.com/openai/tunnel-client/blob/master/docs/onboarding.md).

## Setup

1. Copy [`.env.example`](.env.example) to `.env` and fill in your tunnel ID and API key:

   ```sh
   cp .env.example .env
   ```

   ```dotenv
   TUNNEL_ID=tunnel_your_tunnel_id
   TUNNEL_API_KEY=sk-your-runtime-api-key
   CODEX_CREDENTIALS_DIR=${HOME}/.codex
   ```

   If the file already exists, edit it. Set `CODEX_CREDENTIALS_DIR` to the directory containing your ChatGPT `auth.json`. Keep `.env` private; it is ignored by Git.

2. Start both containers:

   ```sh
   docker compose pull
   docker compose up -d
   ```

3. Add a custom MCP connection in ChatGPT, choose **Tunnel**, and select the same tunnel ID. Keep the connection private: it can read the chat history belonging to the mounted account.

Try asking: "Find my chats about `your topic` and link me to the relevant conversations."

## Optional proxy

Set `HTTPS_PROXY` in `.env` to route both ChatGPT requests and the tunnel's OpenAI
connection through an HTTP or SOCKS5 proxy:

```dotenv
HTTPS_PROXY='socks5h://username:password@proxy-host:10808'
```

For an HTTP proxy, use `http://proxy-host:port`. Omit `username:password@` if no authentication is needed; URL-encode special characters in either credential.
Leave the setting empty for direct connections. Internal MCP traffic stays direct.

For a proxy running on the Docker host, use `host.docker.internal` as the hostname.
The proxy must listen on an interface reachable from Docker, rather than only the host's loopback address. Apply changes with `docker compose up -d`.

## Tools

| Tool | What it does |
| --- | --- |
| `search_chatgpt_messages` | Searches message text by keyword. Returns snippets, chat links, message IDs, and a cursor for the next page. |
| `get_chatgpt_chat` | Reads context around a message: one preceding message and two following messages by default. Adjust `before` and `after` to explore further. |

Conversation results contain visible user and assistant text from the selected branch. Both tools are read-only.

## Troubleshooting

Check startup and request errors:

```sh
docker compose logs --tail=50 mcp tunnel
```

- **Authentication rejected:** renew the host login with `codex login`. The server rereads credentials but does not refresh them.
- **Credentials unreadable:** check the mount path and file permissions. On Fedora, also check SELinux access.
- **HTTP 429:** wait before retrying.

Stop both containers with `docker compose down`.

The MCP image is published to [GitHub Container Registry](https://github.com/alryks/ChatGPT-history-search/pkgs/container/chatgpt-history-search-mcp)
for AMD64 and ARM64 under release versions such as `1.1.0`. Docker selects the
architecture automatically; architecture images and provenance records remain
untagged. There are no `latest`, build-number, or architecture-specific aliases.
To update, change the MCP image version in `docker-compose.yml`, then run
`docker compose pull` followed by `docker compose up -d`.

## Releases

Use `MAJOR.MINOR.PATCH`: increment MINOR for a backward-compatible feature,
PATCH for a compatible fix or maintenance release, and MAJOR for a breaking
change to the tools or supported configuration. Documentation-only changes do
not need an image release. Version numbers are chosen manually; GitHub does not
infer them from commits. Ordinary commits do not publish images.

| Version | Change |
| --- | --- |
| `1.0.0` | First published server, using curl. |
| `1.0.1` | Python HTTPX replaces the curl subprocess. |
| `1.1.0` | Optional HTTP and SOCKS5 proxies for the server and tunnel. |

These historical releases were rebuilt from their original source commits after
the registry was reset; their digests differ from the original published builds.

For a release, update the version in `server.py` and `docker-compose.yml`, commit
the changes, and push a matching Git tag:

```sh
git tag v1.1.1
git push origin v1.1.1
```

GitHub Actions publishes only the corresponding image tag (`1.1.1` in this
example) and refuses to overwrite an existing version. A feature release after
`1.1.0` would be `1.2.0`; a breaking release would be `2.0.0`.

This project uses undocumented ChatGPT endpoints, which may change or stop working.
The connection between containers is private-network HTTP without authentication; do not expose the MCP server's port.

For authentication and endpoint details, see the
[API guide](CHATGPT_HISTORY_SEARCH_API.md).
