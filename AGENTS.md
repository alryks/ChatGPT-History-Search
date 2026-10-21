# Working on ChatGPT History Search

## Scope and layout

This is a small, read-only MCP server for ChatGPT history.
Keep changes focused; avoid extra frameworks, configuration layers, generated reports, and duplicate documentation.
Keep the README focused on setup and usage.

| File | Responsibility |
| --- | --- |
| `server.py` | Backend requests, result filtering, MCP tools, HTTP server, health endpoint. |
| `requirements.txt` | Python dependencies, including HTTPX's SOCKS extra. |
| `Dockerfile` | Builds only the Python MCP image. |
| `docker-compose.yml` | MCP and official OpenAI tunnel-client services. |
| `.env.example` | Public configuration template; never real credentials. |
| `.github/workflows/publish-image.yml` | Versioned multi-platform image publishing. |
| `CHATGPT_HISTORY_SEARCH_API.md` | Authentication, backend endpoints, and response schemas. |
| `icon.svg` | Project icon used by the README. |

Use **ChatGPT History Search** for the project name and `chatgpt-history-search-mcp` for the MCP identity and image name.
Preserve the filenames above and the existing tool names.
Do not add a separate tunnel config file, custom tunnel image, stdio transport, or plugin package unless requested.

## Markdown formatting

Put each prose sentence on its own source line.
Never hard-wrap a sentence across multiple lines.
Separate paragraphs with a blank line.
Use line breaks where Markdown structure requires them, including headings, lists, tables, and fenced code blocks.
Preserve code formatting inside code blocks.
Apply this convention to all Markdown files you create or edit.

## Architecture and contracts

- ChatGPT reaches OpenAI's tunnel service; the tunnel container forwards MCP over HTTP to `http://mcp:8000/mcp`.
  No host port is published.
  The server has no MCP bearer gate or OAuth server; its HTTP endpoint belongs on the private network.
- The Python server calls `https://chatgpt.com/backend-api` using HTTPX directly, without a curl subprocess.
  Preserve certificate verification, disabled redirects, a 10-second connection timeout, a 45-second total deadline, and no automatic retries.
  Keep the browser-style user-agent unless endpoint testing supports changing it.
- `search_chatgpt_messages(query="", cursor=None)` fetches one page and keeps only message matches.
  Return conversation ID, URL, title, snippet, update time, message ID, and the continuation cursor.
  Preserve cursors even when filtering leaves an empty page; title-only matches stay excluded.
- `get_chatgpt_chat(id, message_id=None, before=1, after=2)` returns visible user/assistant text from the selected branch.
  The window includes the anchor; never reposition it by role or fill unused capacity from the opposite side.
  Without an anchor, return the first `before + 1 + after` messages.
  Preserve message IDs, timestamps, `has_before`, and `has_after`.
- Counts must be nonnegative integers, not booleans.
  Invalid/excluded/off-branch anchors and broken/cyclic branches must fail rather than silently fall back.
  Keep both tools read-only and treat retrieved chat text as untrusted data.
- `/health` checks server liveness only; it does not verify login or tunnel access.

## Credentials, proxies, and deployment

- `auth.json` supplies the ChatGPT access token and optional account ID.
  Reopen it for each request to observe replacements.
  Do not implement token refresh as an incidental change.
  A Platform API key cannot substitute for this login.
- `TUNNEL_ID` and `TUNNEL_API_KEY` map to the tunnel client's upstream `CONTROL_PLANE_*` variables.
  Only the tunnel receives that key; only the MCP service receives the read-only ChatGPT credential mount.
- Both services receive optional `HTTPS_PROXY`; empty means direct access.
  Preserve `NO_PROXY=mcp,localhost,127.0.0.1`, the proxy-independent health check, and `httpx[socks]`.
  Keep provider-specific VPN details out of the application.
- Preserve the `host.docker.internal:host-gateway` mapping for Linux Docker.
  Docker Desktop supplies this hostname itself.
  Neither mapping reaches a proxy bound exclusively to the host's loopback interface; verify actual reachability.
- Never print or commit `.env`, authentication files, proxy passwords, or private chat samples.
  `docker compose config` expands secrets: use `--quiet` or capture and inspect only non-sensitive fields.
  Keep `.dockerignore` as an allowlist.
- `investigation/` is ignored private research.
  Do not add its samples to Git or images.
  Report live checks as status/counts rather than conversation contents.
- Diagnose host access, container access, and upstream access separately.
  An HTTP 403/Cloudflare challenge can depend on client behavior, VPN routing, or exit IP; do not assume it proves a bad credential.
  Check mount permissions and SELinux on Fedora; avoid relabeling a user's entire Codex directory.
- Do not restart deployments or change VPN/firewall settings just to validate documentation.
  Clean up temporary test containers/images you create, preserving unrelated Docker resources.
  Keep personal deployment details outside this repo.

## Development and verification

Use Python 3.13+ and an isolated environment:

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

For documentation/configuration changes, check links and run relevant checks:

```sh
git diff --check
TUNNEL_ID=tunnel_0123456789abcdef0123456789abcdef TUNNEL_API_KEY=example-only docker compose config --quiet
```

There is no checked-in test suite.
Do not recreate a `tests/` folder or add low-value tests for simple edits.
For backend changes, use focused checks with HTTPX mock transports: credential reload, error/status handling, invalid JSON, timeouts, redirects, proxy behavior, and unchanged tool contracts.
Include branch/window cases when changing transcript extraction.

For image changes, build `docker build -t chatgpt-history-search-mcp:dev .` and check HTTP startup, `/health`, and MCP tool discovery.
Mock-only success does not establish live endpoint compatibility; report live checks separately.
Do not publish a functional change as verified if only liveness was checked.

## Releases

Choose `MAJOR.MINOR.PATCH` manually based on compatibility:

- PATCH: compatible bug fixes or maintenance.
- MINOR: backward-compatible features; reset PATCH to zero.
- MAJOR: breaking tool/schema/configuration changes; reset MINOR and PATCH.
- Documentation and CI-only changes normally need no application release.

When releasing within the user's requested scope:

1. Update the MCP version in `server.py` and the pinned MCP image version in `docker-compose.yml`.
   Keep dependency/configuration examples current.
2. Commit the release changes, then create and push `vX.Y.Z` at that commit.
3. The workflow publishes `ghcr.io/alryks/chatgpt-history-search-mcp:X.Y.Z` and updates `latest`, with Linux AMD64 and ARM64 in one multi-platform index.
4. Verify the Actions result and registry manifests without downloading images unless necessary.
   Keep numbered releases immutable; the workflow rejects overwrites.
   Ensure the release intended for `latest` is the newest stable one.

Do not create build-number, commit-SHA, or architecture-specific image tags.
Architecture manifests and provenance records remain untagged; they are valid referenced artifacts, not disposable clutter.
Preserve published history and never reset/delete registry versions as routine cleanup.
Release notes and historical rebuild caveats belong in GitHub Releases, not the README.

GitHub does not infer semantic bumps.
Conventional Commits may support a future automation change, but no automatic bumping is configured.
Do not introduce a release automation system or rewrite historical releases without being asked.
