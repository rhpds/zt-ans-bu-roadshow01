#!/bin/bash
# Validate Module 02 - Infrastructure Introspection and Reporting

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

# 2.1: Ad-hoc command was run (check for ad-hoc command jobs)
ADHOC_RAN=$(${CURL} "${AAP_HOST}/api/controller/v2/ad_hoc_commands/?order_by=-finished&page_size=10" \
  | python3 -c "
import sys,json
d=json.load(sys.stdin)
# Check if any ad-hoc command used the setup module
found = any(j.get('module_name','') == 'setup' for j in d.get('results',[]))
print('true' if found else 'false')
" 2>/dev/null)
check "Ad-hoc command (setup module) executed" "${ADHOC_RAN:-false}"

# 2.2: Application Server Report job launched
TMPL_ID=$(get_template_id "Application Server Report")
if [ -n "$TMPL_ID" ]; then
  check "Application Server Report job launched" "$(has_successful_job "$TMPL_ID")"
else
  check "Application Server Report job launched" "false"
fi

# 2.3: OpenSCAP Report job launched
TMPL_ID=$(get_template_id "OpenSCAP Report")
if [ -n "$TMPL_ID" ]; then
  check "OpenSCAP Report job launched" "$(has_successful_job "$TMPL_ID")"
else
  check "OpenSCAP Report job launched" "false"
fi

# Print results
echo ""
echo "Module 2 Validation Results"
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
