# Upstream H candidate TSV parser fix

`candidate_configs.tsv` has 17 positional columns and empty fields are meaningful, especially `reject_bands`.

Do not parse a TSV row directly with Bash whitespace IFS:

```bash
IFS=$'\t' read -r cid lane rr score gain hp lp nf ed eg cs ct co cr th rb chain <<<"$row"
```

Tab is IFS whitespace, so adjacent tabs can collapse and an empty column disappears. In the observed failure an empty `reject_bands` column vanished and `chain` shifted into `rb`, producing `INVALID_REJECT_BANDS` at H.

The bounded Bash fix is:

```bash
column_count=$(awk -F '\t' '{print NF}' <<<"$row")
[[ "$column_count" -eq 17 ]] || {
  echo "invalid candidate TSV column count: $column_count" >&2
  exit 4
}
row_pipe=${row//$'\t'/|}
IFS='|' read -r cid lane rr score gain hp lp nf ed eg cs ct co cr th rb chain <<<"$row_pipe"
```

The non-whitespace delimiter preserves empty positional fields. Upstream, a real TSV reader or explicit field extraction is preferable. The invariant is: never use Bash whitespace splitting when empty TSV fields carry meaning.
