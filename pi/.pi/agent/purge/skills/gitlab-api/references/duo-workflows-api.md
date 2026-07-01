# Duo Workflows API

Reference for the GitLab Duo Workflows REST & GraphQL API, based on the [duo-reporter](https://gitlab.com/viktomas/duo-reporter) project at `/Users/tomas/workspace/gl/duo-reporter`.

## Endpoints

### Create a workflow

```
POST /api/v4/ai/duo_workflows/workflows
Headers: PRIVATE-TOKEN: <PAT>
Body:
{
  "project_id": "<project_id>",
  "namespace_id": "<namespace_id>",
  "goal": "<text>",
  "workflow_definition": "chat",
  "environment": "ide",
  "allow_agent_to_request_user": true,
  "agent_privileges": [1, 2, 3, 4, 6, 5],
  "pre_approved_agent_privileges": [1, 2]
}
Response: { "id": <workflow_id> }
```

### Get a direct-access token

Checkpoints are posted with a **Bearer token**, not the PAT. Obtain it via:

```
POST /api/v4/ai/duo_workflows/direct_access
Headers: PRIVATE-TOKEN: <PAT>
Body: { "workflow_definition": "chat" }
Response:
{
  "gitlab_rails": { "base_url": "...", "token": "<bearer_token>", "token_expires_at": "..." },
  "duo_workflow_service": { "base_url": "...", "token": "...", ... }
}
```

Use `gitlab_rails.token` as `Authorization: Bearer <token>` for checkpoint calls.

### Post a checkpoint

```
POST /api/v4/ai/duo_workflows/workflows/<workflow_id>/checkpoints
Headers: Authorization: Bearer <direct_access_token>
Body:
{
  "thread_ts": "<uuid>",
  "parent_ts": "<previous_thread_ts or null>",
  "checkpoint": { ... },   // see Checkpoint Shape below
  "metadata": { "step": <int>, "source": "loop"|"input", "parents": {} }
}
```

### Update workflow status

```
PATCH /api/v4/ai/duo_workflows/workflows/<workflow_id>
Headers: PRIVATE-TOKEN: <PAT>
Body: { "status_event": "<event>" }
```

### Delete a workflow (GraphQL)

```graphql
mutation deleteDuoWorkflowsWorkflow($input: DeleteDuoWorkflowsWorkflowInput!) {
  deleteDuoWorkflowsWorkflow(input: $input) {
    clientMutationId
    errors
    success
  }
}
# variables: { "input": { "workflowId": "gid://gitlab/Ai::DuoWorkflows::Workflow/<id>" } }
```

## Checkpoint Shape

The `checkpoint.channel_values` object is what the GitLab UI reads:

```json
{
  "goal": "<original goal text>",
  "plan": { "steps": [] },
  "status": "Execution",
  "project": { "id": 123, "name": "...", "web_url": "..." },
  "approval": null,
  "namespace": null,
  "ui_chat_log": [ ... ],
  "last_human_input": "<last user message>",
  "preapproved_tools": ["read_file", "list_directory"],
  "conversation_history": {}
}
```

The first checkpoint (step -1, `__start__`) has a minimal shape:
```json
{ "channel_values": { "__start__": { "goal": "<text>" } } }
```

## ui_chat_log Entry Types

Each entry in `ui_chat_log` is rendered by the GitLab UI. Three `message_type` values:

### User message

```json
{
  "status": "success",
  "content": "the user's message",
  "timestamp": "2025-03-25T...",
  "tool_info": null,
  "message_id": "user-<uuid>",
  "message_type": "user",
  "correlation_id": null,
  "message_sub_type": null,
  "additional_context": null
}
```

### Agent message

```json
{
  "status": "success",
  "content": "agent's response text",
  "timestamp": "2025-03-25T...",
  "tool_info": null,
  "message_id": "lc_run--<uuid>",
  "message_type": "agent",
  "correlation_id": null,
  "message_sub_type": null,
  "additional_context": null
}
```

### Tool message

```json
{
  "status": "success",
  "content": "Read file",
  "timestamp": "2025-03-25T...",
  "tool_info": {
    "name": "read_file",
    "args": { "file_path": "README.md" },
    "tool_response": {
      "id": null,
      "name": "read_file",
      "type": "ToolMessage",
      "status": "success",
      "content": "<tool output>",
      "artifact": null,
      "tool_call_id": "toolu_<24chars>",
      "additional_kwargs": {},
      "response_metadata": {}
    }
  },
  "message_id": "toolu_<24chars>",
  "message_type": "tool",
  "correlation_id": null,
  "message_sub_type": "read_file",
  "additional_context": null
}
```

Key details:
- `content` for tool entries is a human-readable label (e.g. "Read file"), not the output
- `message_sub_type` for tool entries is the tool name
- `message_id` for tool entries matches `tool_response.tool_call_id`
- The `tool_response` shape must match what DWS produces or the UI won't render it correctly

## Reference Material

- Working implementation: `/Users/tomas/workspace/gl/duo-reporter/src/` (api.ts, state.ts, workflow-cli.ts)
- Reference DWS workflow: `/Users/tomas/workspace/gl/duo-reporter/samples/workflow-3168090.json`
- DWS source (the real agent backend): `/Users/tomas/workspace/gl/ai-assist`
