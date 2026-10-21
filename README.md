<img src="icon.svg" alt="" width="80">

# ChatGPT History Search

Let ChatGPT search your past conversations by keyword, read surrounding messages, and return links to the original chats.

Runs as an MCP server in Docker, connected to ChatGPT through OpenAI's Secure MCP Tunnel. No public domain or exposed host ports are needed.

## Requirements

- Docker with Docker Compose.
- A ChatGPT login saved by `codex login` on the Docker host.
  An OpenAI API-key login alone cannot access chat history.
- A [Secure MCP Tunnel](https://platform.openai.com/settings/organization/tunnels) and a Platform runtime API key with **Tunnels Read + Use** permissions.
  See [OpenAI's setup guide](https://github.com/openai/tunnel-client/blob/master/docs/onboarding.md).

## Setup

1. Create a `.env` file in the project directory:

   ```dotenv
   TUNNEL_ID=tunnel_your_tunnel_id
   TUNNEL_API_KEY=sk-your-runtime-api-key
   CODEX_CREDENTIALS_DIR=${HOME}/.codex
   ```

   If the file already exists, edit it. Set `CODEX_CREDENTIALS_DIR` to the directory containing your ChatGPT `auth.json`. Keep `.env` private; it is ignored by Git.

2. Start both containers:

   ```sh
   docker compose up -d --build
   ```

3. Add a custom MCP connection in ChatGPT, choose **Tunnel**, and select the same tunnel ID. Keep the connection private: it can read the chat history belonging to the mounted account.

Try asking: "Find my chats about <your topic> and link me to the relevant conversations."

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

This project uses undocumented ChatGPT endpoints, which may change or stop working.
The connection between containers is private-network HTTP without authentication; do not expose the MCP server's port.

For authentication and endpoint details, see the
[API guide](CHATGPT_HISTORY_SEARCH_API.md).
