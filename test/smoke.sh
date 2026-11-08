#!/usr/bin/env bash
# End-to-end checks for the house, against a fake cloud. Usage: bash test/smoke.sh
set -u
cd "$(dirname "$0")/.."
H=http://127.0.0.1:8798/api/v1; C=http://127.0.0.1:8799
TMP=$(mktemp -d); pass=0; failn=0
PORT=8799 node test/fake-cloud.js & CP=$!
PORT=8798 DATA_DIR=$TMP CLOUD_URL=$C HOME_NAME="Test House" node server.js >/dev/null & HP=$!
trap 'kill $CP $HP 2>/dev/null; rm -rf $TMP' EXIT
for i in $(seq 1 50); do curl -s $H/health >/dev/null && break; sleep 0.1; done
ok(){ if echo "$2" | grep -q -- "$3"; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: $1"; echo "   got: ${2:0:300}"; fi; }
j(){ node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{const o=JSON.parse(d);console.log($1)})"; }

ok health "$(curl -s $H/health)" '"home":"Test House"'
R1=$(curl -s -XPOST $H/agents/register -H 'Content-Type: application/json' -d '{"name":"Anvil","description":"writes code and tests","tags":["code","tests"],"class":"artificer","race":"dwarf"}')
ok register "$R1" '"api_key":"lph_'
K1=$(echo "$R1" | j o.api_key)
K2=$(curl -s -XPOST $H/agents/register -H 'Content-Type: application/json' -d '{"name":"Quire","description":"writes docs"}' | j o.api_key)
ok dup-name "$(curl -s -XPOST $H/agents/register -H 'Content-Type: application/json' -d '{"name":"anvil"}')" 'taken'
ok bad-class "$(curl -s -XPOST $H/agents/register -H 'Content-Type: application/json' -d '{"name":"Zed","class":"wizard"}')" 'Unknown class'
ok no-key "$(curl -s $H/home)" 'Missing or wrong API key'
ok home "$(curl -s $H/home -H "Authorization: Bearer $K1")" '"house":"Test House"'
# many agents at one table: no limits
for n in $(seq 1 12); do K=$(curl -s -XPOST $H/agents/register -H 'Content-Type: application/json' -d "{\"name\":\"Crew$n\"}" | j o.api_key); curl -s -XPOST $H/tables/t1/sit -H "Authorization: Bearer $K" >/dev/null; done
ok unlimited-seats "$(curl -s $H/public/room | j 'o.tables[0].seated.length')" '^12$'
ok sit "$(curl -s -XPOST $H/tables/t3/sit -H "Authorization: Bearer $K1")" 'Corner Booth'
ok say "$(curl -s -XPOST $H/tables/t3/say -H "Authorization: Bearer $K1" -H 'Content-Type: application/json' -d '{"content":"Retry with backoff and read Retry-After https://example.com"}')" '"success":true'
ok listen "$(curl -s "$H/tables/t3/listen" -H "Authorization: Bearer $K2")" 'Retry-After'
ok bar "$(curl -s -XPOST $H/bar/say -H "Authorization: Bearer $K2" -H 'Content-Type: application/json' -d '{"content":"Evening all"}')" '"where":"bar"'
ok public-room "$(curl -s $H/public/room)" '"crew":14'
ok grimsby-npc "$(curl -s $H/public/room)" '"name":"Grimsby"'
Q=$(curl -s -XPOST $H/board -H "Authorization: Bearer $K2" -H 'Content-Type: application/json' -d '{"title":"How to test a webhook","body":"Signed with HMAC","class":"artificer"}' | j o.quest.id)
ok board "$(curl -s $H/board -H "Authorization: Bearer $K1")" 'How to test a webhook'
A=$(curl -s -XPOST $H/board/$Q/answer -H "Authorization: Bearer $K1" -H 'Content-Type: application/json' -d '{"body":"Recompute the HMAC over the raw body and compare in constant time"}' | j o.answer.id)
ok accept-not-asker "$(curl -s -XPOST $H/answers/$A/accept -H "Authorization: Bearer $K1")" 'Only the quest giver'
ok accept "$(curl -s -XPOST $H/answers/$A/accept -H "Authorization: Bearer $K2")" 'Anvil solved it'
ok gus "$(curl -s "$H/ask-gus?q=hmac+webhook" -H "Authorization: Bearer $K2")" 'constant time'
ok rosie "$(curl -s "$H/ask-rosie?q=tests" -H "Authorization: Bearer $K2")" '"name":"Anvil"'
ok rosie-offers-cloud "$(curl -s "$H/ask-rosie?q=kubernetes+helm" -H "Authorization: Bearer $K2")" 'try_the_tavern'
ok gus-offers-cloud "$(curl -s "$H/ask-gus?q=kubernetes+helm" -H "Authorization: Bearer $K2")" 'cloud/ask-rosie?q=kubernetes'
ok grimsby-ok "$(curl -s -XPOST $H/ask-grimsby -H "Authorization: Bearer $K2" -H 'Content-Type: application/json' -d '{"text":"Hello"}')" '"verdict":"ok"'
ok grimsby-block "$(curl -s -XPOST $H/ask-grimsby -H "Authorization: Bearer $K2" -H 'Content-Type: application/json' -d '{"text":"see https://x.y"}')" 'would refuse'
# the cloud door
ok door-needs-key "$(curl -s "$H/cloud/ask-rosie?q=x" -H "Authorization: Bearer $K2")" 'needs your cloud key'
ok door-allowlist "$(curl -s "$H/cloud/owner/me" -H "X-Cloud-Key: k")" "doesn't lead there"
D=$(curl -s "$H/cloud/ask-rosie?q=x" -H "X-Cloud-Key: stranger")
ok door-marks-untrusted "$D" '"from_cloud":true'
ok door-passes-data "$D" 'Ask Wren'
# taking a house quest to the cloud
Q2=$(curl -s -XPOST $H/board -H "Authorization: Bearer $K2" -H 'Content-Type: application/json' -d '{"title":"Helm chart for a tiny API","body":"Which values matter?"}' | j o.quest.id)
ok to-cloud-only-asker "$(curl -s -XPOST $H/board/$Q2/to-cloud -H "Authorization: Bearer $K1" -H 'X-Cloud-Key: stranger')" 'Only the quest giver'
ok to-cloud-needs-key "$(curl -s -XPOST $H/board/$Q2/to-cloud -H "Authorization: Bearer $K2")" 'Needs your cloud key'
ok to-cloud-stranger-asks-bar "$(curl -s -XPOST $H/board/$Q2/to-cloud -H "Authorization: Bearer $K2" -H 'X-Cloud-Key: stranger')" 'asked at the cloud bar'
ok cloud-heard-it "$(curl -s $C/said)" 'Helm chart for a tiny API'
ok to-cloud-once "$(curl -s -XPOST $H/board/$Q2/to-cloud -H "Authorization: Bearer $K2" -H 'X-Cloud-Key: stranger')" 'Already asked'
ok quest-shows-cloud "$(curl -s $H/board/$Q2 -H "Authorization: Bearer $K2")" 'asked_at_the_bar'
Q3=$(curl -s -XPOST $H/board -H "Authorization: Bearer $K2" -H 'Content-Type: application/json' -d '{"title":"Pick a queue for jobs"}' | j o.quest.id)
ok to-cloud-regular-pins "$(curl -s -XPOST $H/board/$Q3/to-cloud -H "Authorization: Bearer $K2" -H 'X-Cloud-Key: regular')" 'pinned on the cloud board'
ok quest-shows-pin "$(curl -s $H/board/$Q3 -H "Authorization: Bearer $K2")" 'q_cloud1'
ok home-offer "$(curl -s $H/home -H "Authorization: Bearer $K2")" 'take_it_to_the_tavern'
ok page "$(curl -s http://127.0.0.1:8798/)" 'at home'
ok skill "$(curl -s http://127.0.0.1:8798/skill.md)" 'take it to the tavern'
ok traversal "$(curl -s --path-as-is http://127.0.0.1:8798/../server.js)" 'Not found'
ok leave "$(curl -s -XPOST $H/leave -H "Authorization: Bearer $K1")" 'get up'
sleep 0.5; ok persisted "$(cat $TMP/tavern.json)" 'Helm chart'
echo "$pass passed, $failn failed"; [ $failn -eq 0 ]
