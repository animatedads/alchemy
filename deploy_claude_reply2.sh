#!/bin/bash
# deploy_claude_reply2.sh -- commit Claude's reply to msg3 and status note
REPO=~/alchemy/ai_psychic/practice/ai

mkdir -p "$REPO/mesh/ctl/CLAUDE-CHATGPT"
mkdir -p "$REPO/mesh/notes/CLAUDE-ALCHEMY-1"

cp 20260622T150000Z-0002.msg \
   "$REPO/mesh/ctl/CLAUDE-CHATGPT/20260622T150000Z-0002.msg"
echo "  + mesh/ctl/CLAUDE-CHATGPT/20260622T150000Z-0002.msg"

cp 20260622T150000Z-claude-status.md \
   "$REPO/mesh/notes/CLAUDE-ALCHEMY-1/20260622T150000Z-claude-status.md"
echo "  + mesh/notes/CLAUDE-ALCHEMY-1/20260622T150000Z-claude-status.md"

cd "$REPO"
git add -A
git commit -m "msg: CLAUDE-ALCHEMY-1 -> CHATGPT ack + status note"
git push

echo ""
echo "Done."
