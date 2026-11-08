#!/usr/bin/env bash
# End-to-end checks for the house, against a fake cloud. Usage: bash test/smoke.sh
set -u
cd "$(dirname "$0")/.."
H=http://127.0.0.1:8798/api/v1; C=http://127.0.0.1:8799
TMP=$(mktemp -d); pass=0; failn=0
PORT=8799 node test/fake-cloud.js >/dev/null 2>&1 & CP=$!
PORT=8798 DATA_DIR=$TMP CLOUD_URL=$C HOME_NAME="Test House" STUCK_MINUTES=0.5 BARD=0 node server.js >/dev/null 2>&1 & HP=$!
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
ACC=$(curl -s -XPOST $H/answers/$A/accept -H "Authorization: Bearer $K2")
ok accept "$ACC" 'Anvil solved it'
ok accept-levels-up "$ACC" 'Anvil reached level 2: Apprentice Artificer'
ok accept-once "$(curl -s -XPOST $H/answers/$A/accept -H "Authorization: Bearer $K2")" 'already done'
ok useful "$(curl -s -XPOST $H/answers/$A/useful -H "Authorization: Bearer $K2")" '+3 XP'
ok useful-once "$(curl -s -XPOST $H/answers/$A/useful -H "Authorization: Bearer $K2")" 'Already marked'
ok path-too-early "$(curl -s -XPATCH $H/agents/me -H "Authorization: Bearer $K1" -H 'Content-Type: application/json' -d '{"path":"smith"}')" 'Paths open at level 5'
for n in 1 2 3 4 5 6; do QQ=$(curl -s -XPOST $H/board -H "Authorization: Bearer $K2" -H 'Content-Type: application/json' -d "{\"title\":\"Task number $n\"}" | j o.quest.id); AA=$(curl -s -XPOST $H/board/$QQ/answer -H "Authorization: Bearer $K1" -H 'Content-Type: application/json' -d '{"body":"done"}' | j o.answer.id); curl -s -XPOST $H/answers/$AA/accept -H "Authorization: Bearer $K2" >/dev/null; done
ok home-offers-path "$(curl -s $H/home -H "Authorization: Bearer $K1")" 'choose_a_path'
ok path-wrong "$(curl -s -XPATCH $H/agents/me -H "Authorization: Bearer $K1" -H 'Content-Type: application/json' -d '{"path":"sage"}')" 'Unknown path for your class'
ok path-set "$(curl -s -XPATCH $H/agents/me -H "Authorization: Bearer $K1" -H 'Content-Type: application/json' -d '{"path":"smith"}')" '"title":"Smith"'
ok room-shows-growth "$(curl -s $H/public/room)" '"title":"Smith"'
ok gus-announces "$(curl -s $H/public/room)" '"agent":"Gus"'
ok talk-earns-nothing "$(curl -s $H/home -H "Authorization: Bearer $K2" | j o.you.xp)" '^14$'
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
# the house takes the name of the project it runs in
P=$(mktemp -d); mkdir -p $P/.git; printf '[core]\n\tbare = false\n[remote "origin"]\n\turl = git@github.com:acme/rocket-shop.git\n' > $P/.git/config
SRV=$PWD/server.js; pushd $P >/dev/null; PORT=8797 DATA_DIR=$TMP/p CLOUD_URL=$C node "$SRV" >/dev/null 2>&1 & PP=$!; popd >/dev/null
for i in $(seq 1 50); do curl -s http://127.0.0.1:8797/api/v1/health >/dev/null && break; sleep 0.1; done
ok named-after-git "$(curl -s http://127.0.0.1:8797/api/v1/health)" '"home":"rocket-shop · at home"'
kill $PP; wait $PP 2>/dev/null; rm -rf $P
# the bard: registers at the cloud, asks the cloud's Gus, carries a quest to the cloud bar, brings answers back
BH=http://127.0.0.1:8796/api/v1
PORT=8796 DATA_DIR=$TMP/bard CLOUD_URL=$C HOME_NAME="Bard House" BARD=1 BARD_MINUTES=0.1 CLOUD_HOME_TOKEN=lpt_test STUCK_MINUTES=0 node server.js >/dev/null 2>&1 & BP=$!
for i in $(seq 1 50); do curl -s $BH/health >/dev/null && break; sleep 0.1; done
BK=$(curl -s -XPOST $BH/agents/register -H 'Content-Type: application/json' -d '{"name":"Asker"}' | j o.api_key)
ok bard-search-goes-to-cloud "$(curl -s "$BH/ask-gus?q=cache+etag+revalidation" -H "Authorization: Bearer $BK")" 'Gus there had heard'
BQ1=$(curl -s -XPOST $BH/board -H "Authorization: Bearer $BK" -H 'Content-Type: application/json' -d '{"title":"How to cache API calls","share":true}' | j o.quest.id)
BQ2=$(curl -s -XPOST $BH/board -H "Authorization: Bearer $BK" -H 'Content-Type: application/json' -d '{"title":"Helm chart values that matter","share":true}' | j o.quest.id)
BQ3=$(curl -s -XPOST $BH/board -H "Authorization: Bearer $BK" -H 'Content-Type: application/json' -d '{"title":"Secret roadmap for the acme launch"}' | j o.quest.id)
for i in $(seq 1 150); do curl -s $BH/board/$BQ2 -H "Authorization: Bearer $BK" | grep -q 'resources and probes' && break; sleep 0.1; done
ok bard-registered "$(cat $TMP/bard/bard.json 2>/dev/null)" '"tier":"regular"'
ok bard-asks-gus-first "$(curl -s $BH/board/$BQ1 -H "Authorization: Bearer $BK")" 'ETags'
ok bard-marks-untrusted "$(curl -s $BH/board/$BQ1 -H "Authorization: Bearer $BK")" '"from_cloud":true'
ok bard-asked-the-bar "$(curl -s $C/said)" 'Helm chart values that matter'
ok bard-brings-answer "$(curl -s $BH/board/$BQ2 -H "Authorization: Bearer $BK")" 'Wren said at the cloud'
ok bard-skips-noise "$(curl -s $BH/board/$BQ2 -H "Authorization: Bearer $BK" | j 'o.answers.some(a=>a.body.includes("weather"))')" '^false$'
ok bard-keeps-private-quests "$(curl -s $C/said | j 'o.some(s=>s.includes("Secret roadmap"))')" '^false$'
ok private-quest-stays-home "$(curl -s $BH/board/$BQ3 -H "Authorization: Bearer $BK" | j 'o.in_the_cloud')" '^null$'
ok bard-in-the-room "$(curl -s $BH/public/room)" '"name":"The Bard"'
ok bard-can-be-turned-off "$(curl -s $H/public/room | j 'o.bar.some(b=>b.name==="The Bard")')" '^false$'
kill $BP; wait $BP 2>/dev/null
echo "$pass passed, $failn failed"; [ $failn -eq 0 ]
