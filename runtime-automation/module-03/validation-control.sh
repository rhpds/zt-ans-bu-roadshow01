#!/bin/bash
# Validate Module 03 - Generating a Windows Patch Report

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

# Get Windows Update Report template ID
WUR_ID=$(${CURL} "${AAP_HOST}/api/controller/v2/job_templates/?name=$(python3 -c "import urllib.parse; print(urllib.parse.quote('Windows Update Report'))")" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['results'][0]['id'] if d['count']>0 else '')" 2>/dev/null)

# 3.1: Survey created on Windows Update Report template
if [ -n "$WUR_ID" ]; then
  SURVEY_SPEC=$(${CURL} "${AAP_HOST}/api/controller/v2/job_templates/${WUR_ID}/survey_spec/" \
    | python3 -c "
import sys,json
d=json.load(sys.stdin)
specs = d.get('spec', [])
# Check if there's a survey question with the update_category variable
has_survey = any(s.get('variable','') == 'update_category' for s in specs)
print('true' if has_survey else 'false')
" 2>/dev/null)
  check "Survey created on Windows Update Report template" "${SURVEY_SPEC:-false}"
else
  check "Survey created on Windows Update Report template" "false"
fi

# 3.2: Survey enabled on Windows Update Report template
if [ -n "$WUR_ID" ]; then
  SURVEY_ENABLED=$(${CURL} "${AAP_HOST}/api/controller/v2/job_templates/${WUR_ID}/" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if d.get('survey_enabled', False) else 'false')" 2>/dev/null)
  check "Survey enabled on Windows Update Report template" "${SURVEY_ENABLED:-false}"
else
  check "Survey enabled on Windows Update Report template" "false"
fi

# 3.3: Windows Update Report job launched
if [ -n "$WUR_ID" ]; then
  JOBS=$(${CURL} "${AAP_HOST}/api/controller/v2/job_templates/${WUR_ID}/jobs/?order_by=-finished&page_size=10" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if any(j['status']=='successful' for j in d['results']) else 'false')" 2>/dev/null)
  check "Windows Update Report job launched" "${JOBS:-false}"
else
  check "Windows Update Report job launched" "false"
fi

# Print results
echo ""
echo "Module 3 Validation Results"
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
