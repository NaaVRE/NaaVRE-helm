set -euo pipefail

{
  echo "## Rendered chart diff"
  echo
  echo "Compared rendered chart manifest with \`$BASE_REF\` ([workflow run]($RUN_URL))"
  echo
  echo "| Values | Result |"
  echo "|---|---|"
  while read -r name status; do
    case "$status" in
      unchanged) result="No changes" ;;
      changed) result="**Changed** ($(grep -m1 'files changed' "diffs/$name.md" || echo "dependencies only"))" ;;
      *) result=":x: Render failed" ;;
    esac
    echo "| \`$name\` | $result |"
  done < diffs/status
  echo
  while read -r name status; do
    case "$status" in
      unchanged) ;;
      changed)
        echo "<details><summary><b>$name</b></summary>"
        echo
        cat "diffs/$name.md"
        echo
        echo "</details>"
        echo
        ;;
      *)
        echo "<details><summary><b>$name</b> (render failed)</summary>"
        echo
        echo '```text'
        tail -n 30 "diffs/$name.log"
        echo '```'
        echo
        echo "</details>"
        echo
        ;;
    esac
  done < diffs/status
} > report.md

cat report.md >> "$GITHUB_STEP_SUMMARY"

# GitHub comments are limited to 65536 characters
max_size=60000
if [[ "$(wc -c < report.md)" -gt "$max_size" ]]; then
  {
    head -c "$max_size" report.md
    echo
    echo '```'
    echo
    echo "**Output truncated**, see the [workflow run]($RUN_URL) for the full diff."
  } > comment.md
else
  cp report.md comment.md
fi
