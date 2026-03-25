#!/bin/bash
# Validate Module 01 - Introspection and System Backups

AAP_HOST="https://localhost"
AAP_USER="admin"
AAP_PASS="ansible123!"
CURL="curl -sk -u ${AAP_USER}:${AAP_PASS}"

PASS=0
FAIL=0
RESULTS=""

check() {
  local desc="$1"
  local ok="$2"
  if [ "$ok" = "true" ]; then
    RESULTS="${RESULTS}[OK] ${desc}\n"
    PASS=$((PASS + 1))
  else
    RESULTS="${RESULTS}[X]  ${desc}\n"
    FAIL=$((FAIL + 1))
  fi
}

get_template_id() {
  ${CURL} "${AAP_HOST}/api/controller/v2/job_templates/?name=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$1'))")" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['results'][0]['id'] if d['count']>0 else '')" 2>/dev/null
}

has_successful_job() {
  local tmpl_id="$1"
  ${CURL} "${AAP_HOST}/api/controller/v2/job_templates/${tmpl_id}/jobs/?order_by=-finished&page_size=10" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if any(j['status']=='successful' for j in d['results']) else 'false')" 2>/dev/null
}

# 1.1: Check RHEL Backup job launched
TMPL_ID=$(get_template_id "Check RHEL Backup")
if [ -n "$TMPL_ID" ]; then
  check "Check RHEL Backup job launched" "$(has_successful_job "$TMPL_ID")"
else
  check "Check RHEL Backup job launched" "false"
fi

# 1.2: Server Backup - XFS/RHEL job launched
TMPL_ID=$(get_template_id "Server Backup - XFS/RHEL")
if [ -n "$TMPL_ID" ]; then
  check "Server Backup - XFS/RHEL job launched" "$(has_successful_job "$TMPL_ID")"
else
  check "Server Backup - XFS/RHEL job launched" "false"
fi

# 1.3: Server Backup - VSS/Windows job launched
TMPL_ID=$(get_template_id "Server Backup - VSS/Windows")
VSS_ID="$TMPL_ID"
if [ -n "$TMPL_ID" ]; then
  check "Server Backup - VSS/Windows job launched" "$(has_successful_job "$TMPL_ID")"
else
  check "Server Backup - VSS/Windows job launched" "false"
fi

# 1.4: Check Windows Backups job launched
TMPL_ID=$(get_template_id "Check Windows Backups")
if [ -n "$TMPL_ID" ]; then
  check "Check Windows Backups job launched" "$(has_successful_job "$TMPL_ID")"
else
  check "Check Windows Backups job launched" "false"
fi

# 1.5: Schedule "2 Min Snappy" created on VSS/Windows template
if [ -n "$VSS_ID" ]; then
  SCHED=$(${CURL} "${AAP_HOST}/api/controller/v2/job_templates/${VSS_ID}/schedules/" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if any('2 Min Snappy' in s['name'] for s in d['results']) else 'false')" 2>/dev/null)
  check "Schedule '2 Min Snappy' created on VSS/Windows template" "${SCHED:-false}"
else
  check "Schedule '2 Min Snappy' created on VSS/Windows template" "false"
fi

# Print results
echo ""
echo "Module 1 Validation Results"
echo "==========================="
echo -e "$RESULTS"
echo "Passed: ${PASS} / $((PASS + FAIL))"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "One or more checks failed. Complete the missing tasks and try again."
  exit 1
fi

echo "All checks passed!"
exit 0
