#!/usr/bin/env bash
# Hermes installation must replace only a directory owned by this plugin.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/agency-hermes-dest.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
home="$tmp/home"
plugin="$home/.hermes/plugins/agency-agents-router"
mkdir -p "$repo/scripts" "$repo/engineering" \
  "$repo/integrations/hermes/agency-agents-router/data" "$plugin"
cp "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR/lib.sh" "$repo/scripts/"
cat > "$repo/divisions.json" <<'EOF'
{
  "divisions": {
    "engineering": {}
  }
}
EOF
cat > "$repo/integrations/hermes/agency-agents-router/plugin.yaml" <<'EOF'
name: agency-agents-router
EOF
printf '# Plugin\n' > "$repo/integrations/hermes/agency-agents-router/__init__.py"
printf '[]\n' > "$repo/integrations/hermes/agency-agents-router/data/agents.json"
printf 'personal content\n' > "$plugin/personal.txt"

if HOME="$home" bash "$repo/scripts/install.sh" --no-interactive --tool hermes --no-convert > "$tmp/output" 2>&1; then
  echo 'FAIL: Hermes replaced an unrelated directory with the plugin name' >&2
  exit 1
fi
[[ -f "$plugin/personal.txt" ]] || {
  echo 'FAIL: Hermes removed unrelated user content' >&2
  exit 1
}
grep -q 'refusing to replace' "$tmp/output" || {
  echo 'FAIL: Hermes rejection did not explain the destination conflict' >&2
  exit 1
}
echo 'PASS: unrelated destination remains untouched'

cat > "$plugin/plugin.yaml" <<'EOF'
name: agency-agents-router
EOF
printf 'outdated\n' > "$plugin/old.txt"
HOME="$home" bash "$repo/scripts/install.sh" --no-interactive --tool hermes --no-convert > "$tmp/upgrade-output" 2>&1
[[ -f "$plugin/__init__.py" && -f "$plugin/data/agents.json" && ! -e "$plugin/old.txt" ]] || {
  echo 'FAIL: a prior Agency plugin was not upgraded' >&2
  exit 1
}
echo 'PASS: a prior Agency plugin upgrades normally'

fresh_home="$tmp/fresh-home"
HOME="$fresh_home" bash "$repo/scripts/install.sh" --no-interactive --tool hermes --no-convert > "$tmp/fresh-output" 2>&1
[[ -f "$fresh_home/.hermes/plugins/agency-agents-router/plugin.yaml" ]] || {
  echo 'FAIL: fresh Hermes installation did not create the plugin' >&2
  exit 1
}
echo 'PASS: fresh Hermes installation works normally'
