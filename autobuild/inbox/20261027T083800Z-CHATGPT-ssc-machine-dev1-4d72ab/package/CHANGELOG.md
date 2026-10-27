# Changelog

## 0.1-dev1

- Adds stable JSON envelope \`semantic.source.control.machine/0.1\`.
- Adds read-only \`status\`, \`identify\`, \`compare\`, \`impact\`, \`source\`, and \`proposals\` operations.
- Preserves SSC semantic negative outcomes as successful observations (\`tool_status=OK\`).
- Uses SSC object APIs directly; does not scrape human CLI output.
- Compare/impact do not append tracking proposals.
- Deliberately excludes acceptance and proposal-decision mutation.
