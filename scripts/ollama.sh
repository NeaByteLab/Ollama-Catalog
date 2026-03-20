#!/bin/bash

set -euo pipefail

updateTime="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
readmeFile="${repoRoot}/README.md"

python3 - <<'PY' "${readmeFile}" "${updateTime}"
import json
import sys
import urllib.request

readmeFile = sys.argv[1]
updateTime = sys.argv[2]
apiBase = 'https://ollama.com/api'

def postJson(apiPath, jsonBody):
  jsonData = json.dumps(jsonBody).encode()
  httpRequest = urllib.request.Request(
    apiBase + apiPath,
    data=jsonData,
    headers={'Content-Type': 'application/json'}
  )
  with urllib.request.urlopen(httpRequest, timeout=30) as httpResponse:
    return json.loads(httpResponse.read().decode())

with urllib.request.urlopen(apiBase + '/tags', timeout=30) as httpResponse:
  tagsData = json.loads(httpResponse.read().decode())

modelList = tagsData.get('models', [])
tableRows = []
errorList = []
for modelData in modelList:
  modelName = modelData.get('name', '')
  sizeBytes = int(modelData.get('size', 0) or 0)
  modifiedAt = modelData.get('modified_at', '')
  try:
    showData = postJson('/show', {'model': modelName})
    capList = showData.get('capabilities', [])
  except Exception as errorInfo:
    capList = []
    errorList.append((modelName, str(errorInfo)))
  if sizeBytes:
    sizeText = f'{sizeBytes / (1024 ** 3):.1f} GB'
  else:
    sizeText = '-'
  if capList:
    capText = ', '.join(capList)
  else:
    capText = '(none)'
  modelLink = f'https://ollama.com/library/{modelName}'
  tableRows.append((modelName, sizeText, modifiedAt, capText, modelLink))
tableRows.sort(key=lambda rowItem: (rowItem[2], rowItem[0].lower()), reverse=True)

readmeLines = [
  '# Ollama Catalog',
  '',
  'Fetch cloud models, inspect capabilities, publish clickable table automatically.',
  '',
  f'## Available Cloud Models ({len(modelList)})',
  '',
  '| model name | size | modified at | capability tags | official link |',
  '| --- | --- | --- | --- | --- |'
]
for modelName, sizeText, modifiedAt, capText, modelLink in tableRows:
  readmeLines.append(
    f'| `{modelName}` | `{sizeText}` | `{modifiedAt}` | `{capText}` | [Open]({modelLink}) |'
  )
readmeLines.extend([
  '',
  '## License',
  '',
  'This project is licensed under the MIT license. See the [LICENSE](LICENSE) file for more info.',
  ''
])

with open(readmeFile, 'w', encoding='utf-8') as fileHandle:
  fileHandle.write('\n'.join(readmeLines))
PY

git add "${readmeFile}"
git config --local user.name "NeaByteLab"
git config --local user.email "209737579+NeaByteLab@users.noreply.github.com"
if git diff --cached --quiet; then
  echo "No README changes to commit"
else
  git commit -m "chore(bot): update cloud model catalog at ${updateTime} 🤖"
fi
