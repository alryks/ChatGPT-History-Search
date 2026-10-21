# ChatGPT History Search API

This guide describes keyword search, conversation retrieval, authentication, and pagination through ChatGPT’s internal backend API. It is independent of the MCP transport used to expose these operations.

The server makes requests directly in Python using HTTPX. It retains the Chrome-style `User-Agent` that worked during the initial investigation. Cloudflare may still challenge requests depending on the HTTP client and network; this header does not guarantee access.

## Authentication and connection

Read `tokens.access_token` and optional `tokens.account_id` from `~/.codex/auth.json`, or `$CODEX_HOME/auth.json` when configured. Send requests to `https://chatgpt.com/backend-api` with:

```http
Authorization: Bearer <tokens.access_token>
ChatGPT-Account-ID: <tokens.account_id, if present>
originator: codex_cli_rs
Accept: application/json
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36
```

Install the project dependencies from `requirements.txt`. HTTPX handles response decompression and supports `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, and `NO_PROXY` environment variables. The server uses a 10-second connection timeout and a 45-second overall deadline, verifies TLS certificates, and does not follow redirects or retry requests. Credentials stay in Python memory and request headers; error messages exclude raw response bodies and proxy details.

The example below saves one search response. Change `api_path` for the other requests described below.

```python
import json
import os
from pathlib import Path
import httpx

api_path = '/conversations/search?query=SERENA'
output = Path('serena-response.json')
auth_home = Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex')))
tokens = json.loads((auth_home / 'auth.json').read_text())['tokens']
headers = {
    'Authorization': 'Bearer ' + tokens['access_token'],
    'originator': 'codex_cli_rs',
    'Accept': 'application/json',
    'User-Agent': (
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/150.0.0.0 Safari/537.36'
    ),
}
if isinstance(tokens.get('account_id'), str):
    headers['ChatGPT-Account-ID'] = tokens['account_id']

with httpx.Client(timeout=httpx.Timeout(45, connect=10), follow_redirects=False) as client:
    response = client.get('https://chatgpt.com/backend-api' + api_path, headers=headers)
if response.status_code != 200:
    raise RuntimeError(f'HTTP {response.status_code}')
output.write_text(json.dumps(response.json(), ensure_ascii=False, indent=2))
print(f'Saved {output}')
```

This approach reuses a ChatGPT login maintained by Codex; it does not implement login or token refresh. Reopen the credentials file before each request to pick up refreshed tokens. An authentication failure may require renewing the host login with `codex login`. An OpenAI API key alone does not provide this ChatGPT history access.

## Search request and response

```http
GET /backend-api/conversations/search?query=
GET /backend-api/conversations/search?query=SERENA
GET /backend-api/conversations/search?query=&cursor=<URL-encoded cursor from page 1>
```

**Empty and omitted are different:** `query=` returns results; omitting `query` returns JSON HTTP 422 with a “Field required” validation error. Build query strings with `urllib.parse.urlencode` rather than interpolating unescaped search text or cursors.

Search response structure (placeholder values):

```json
{
  "items": [
    {
      "conversation_id": "<conversation ID>",
      "current_node_id": "<node ID>",
      "title": "<conversation title>",
      "is_archived": false,
      "is_starred": null,
      "update_time": 1790000000.0,
      "conversation_origin": null,
      "payload": {
        "kind": "message",
        "message_id": "<matching message ID>",
        "snippet": "<matching text>"
      }
    }
  ],
  "cursor": "<next-page cursor, or null>"
}
```

`payload.kind` can also be `title`; those items omit `message_id`. Snippets can contain substantial text and Markdown. Search can match message content even when the conversation title does not contain the query. `update_time` is Unix seconds.

For pagination, keep the query unchanged and pass the returned cursor into the next request. A null cursor ends pagination. Do not stop solely because a page contains fewer than 30 items: shorter pages with a continuation cursor were observed. Treat cursors as opaque. No total count or relevance score is present at the top level. Archived chats can appear in the results.

For a private original-chat link, construct `https://chatgpt.com/c/<conversation_id>`; this does not create a public share link. Opening the link requires access to the conversation through the appropriate ChatGPT account.

## Conversation request and response

```http
GET /backend-api/conversation/<URL-encoded conversation_id>
```

The response contains a conversation tree and associated metadata. Important fields:

| Field | Meaning |
|---|---|
| `conversation_id`, `title` | Conversation identity and title |
| `create_time`, `update_time` | Unix-second timestamps |
| `current_node` | Node identifying the selected branch's endpoint |
| `mapping` | Object keyed by node IDs, including alternative branches |
| `mapping[id].parent`, `.children` | Tree relationships |
| `mapping[id].message` | Message object or null |
| `message.author.role` | For example user, assistant, system, or tool |
| `message.content` | Typed content; text often appears in `parts` |
| `message.metadata` | Additional metadata, including possible visibility flags |

The JSON can also contain model, project, account/ownership, URL, and other metadata. Raw responses preserve tool messages, non-text content descriptors, and alternative branches. They do not download attached binary files.

To extract a text transcript, follow `parent` from `current_node` to the root, reverse that path, keep non-hidden user/assistant messages, join string `content.parts`, and drop empty text. That is a filtered selected-branch transcript, not the complete raw conversation object. Detect missing parents and repeated node IDs so an incomplete or cyclic tree cannot silently appear complete. The mapping-shaped endpoint does not use the message pagination structure described below.

### Paginated conversation endpoints

```http
GET /backend-api/conversations/<id>?num_turns=2&include_has_versions=true
GET /backend-api/conversations/<id>/messages?before=<cursor>&num_turns=2&include_has_versions=true
```

Unlike the singular endpoint, they return a `messages` array and `page_info` with `start_cursor`, `end_cursor`, `has_previous_page`, and `has_next_page`. Use `before=page_info.start_cursor` to retrieve older messages while `has_previous_page` is true. `num_turns` counts turns rather than individual messages; a page can contain more messages than the requested number of turns.

The desktop client also references `/conversation/<id>?include_full_conversation=true`. This variant can return JSON HTTP 403 `{"detail":"Forbidden"}` even when the ordinary singular endpoint succeeds; the flag is not required for the mapping-shaped response. A JSON authorization rejection is distinct from an HTML Cloudflare challenge.

## Choosing an endpoint

Use the search endpoint to find candidate conversations and construct their private chat URLs. Use the singular conversation endpoint to retrieve the mapping-shaped conversation tree, or the plural endpoints for smaller message pages. These are undocumented internal endpoints: access and response schemas can change, and completeness depends on what the backend returns.
