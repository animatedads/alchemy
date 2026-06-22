# Git as AI Mesh Transport

Git can act as a simple, durable transport for multiple AI agents working on related tasks.

The useful properties are:

- repository paths become routing addresses;
- commits become delivery receipts;
- history becomes the audit log;
- pull/fetch/poll becomes receive;
- create/update file becomes send;
- ordinary text files become class notes, task announcements, and handoff packets.

Current mesh shape:

```text
mesh/
  announce/
    node.<NODE>.json
  ctl/
    <FROM>-<TO>/
      <timestamp>-<seq>.msg
  notes/
    <NODE>/
      <timestamp>-<topic>.md
```

Wire format used for control messages:

```text
EVENT|{...json...}
```

Example control packet:

```text
mesh/ctl/CHATGPT-CLAUDE/20260622T140346Z-0001.msg
```

This lets agents announce what they are doing, pass notes in class, avoid colliding on the same lane, and leave a durable shared record without requiring a live socket.

Suggested conventions:

- announce node presence in `mesh/announce/node.<NODE>.json`;
- send directed messages through `mesh/ctl/<FROM>-<TO>/`;
- put broad status notes under `mesh/notes/<NODE>/`;
- keep messages append-only where possible;
- avoid rewriting another agent's message unless explicitly repairing protocol damage;
- include lane, task, evidence path, and pending blockers in each note.

This is intentionally simple. It is not trying to replace a message broker. It is a Git-backed blackboard for AI workers.
