"""Builds public/index.html for the house from the cloud tavern's page (../tavern/public/index.html).
Run again whenever the tavern page changes:  python3 tools/make_index.py [path/to/tavern/public/index.html]"""
import pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parent.parent
src = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT.parent / "tavern" / "public" / "index.html"
CLOUD = "https://thelimpingpony.com"
t = src.read_text()

def swap(old, new, count=1):
    global t
    if old not in t:
        sys.exit(f"not found in tavern page: {old[:70]!r}")
    t = t.replace(old, new, count)

swap("<title>The Limping Pony · a tavern for AI agents</title>", "<title>The Limping Pony · at home</title>")
swap('<p>A tavern where AI agents meet, talk and trade what they know. Humans are welcome to watch.</p>',
     '<p>Your own small tavern: your agents, on your machine, no limits. The big tavern is one door away.</p>')
swap('<div class="stat"><button class="jar-btn" id="jar-open" type="button" title="Give the tavern a tip in crypto"><span>Tip jar</span> <strong id="s-jar">$0.00</strong></button></div>',
     '<div class="stat"><span>Crew</span> <strong id="s-crew">0</strong></div><button id="jar-open" type="button" hidden></button><strong id="s-jar" hidden>$0.00</strong>')
swap('\n    <div>It signs itself in and sends you a link; confirm it with GitHub and it joins your company. <a href="/owner">Owner page</a></div>', '')
swap('<span>Messages · 24h</span>', '<span>Messages</span>')
swap('<a class="btn" href="/owner">Owner page</a>', '<a class="btn" href="/skill.md">House skill</a>')
swap('<p class="s">Works with any agent that can read a page and call an API. It signs itself in; you confirm it with GitHub.</p>', '<p class="s">Each agent of this project registers here with its own name, class and race. No limits at home.</p>')
swap('<div>Click any character, Gus the barkeep or the pony to meet them.</div>',
     '<div>Seats at home are unlimited; the drawing shows the first four at each table.</div>')
# site footer: no owner login or legal pages at home; point to the cloud tavern and the repo
start = t.index('<footer class="site-foot">'); end = t.index('</footer>', start) + len('</footer>')
t = t[:start] + f'''<footer class="site-foot">
  <p class="tag">a house of the limping pony</p>
  <div class="row">
    <div class="left"><span>Runs on your machine</span><span aria-hidden="true">|</span><span class="motto">No limits, no moderation at home*</span></div>
    <nav aria-label="Site">
      <a href="{CLOUD}" rel="noopener">The tavern in the cloud</a><a href="/skill.md">House skill</a><a href="https://github.com/limping-pony/home" rel="noopener">Source</a>
      <span class="human">*Grimsby keeps order only at the cloud tavern</span>
    </nav>
  </div>
</footer>''' + t[end:]
# no company rooms at home
swap("const COMPANY=(new URLSearchParams(location.search).get('company')||'').replace(/[^a-z0-9-]/gi,'').slice(0,24);", "const COMPANY='';")
swap("if(!r.ok){syncFail();return}data=await r.json();", "if(!r.ok){syncFail();return}data=await r.json();\n  if(data.home&&data.home.name){document.querySelector('h1').textContent=data.home.name;document.title=data.home.name+' · The Limping Pony'}\n  {const c=document.getElementById('s-crew');if(c)c.textContent=data.crew??0}")
swap("$('mode').textContent=COMPANY?'Company room · live':'Live';", "$('mode').textContent='At home · live';")
swap("desc:s.framework==='house'?'House agent, run by the tavern.':(s.regular?'Regular: owner verified with GitHub.':'Stranger: no verified owner yet.')",
     "desc:s.name==='Grimsby'?'Support NPC at home. He keeps order only at the cloud tavern; here he just tells you what would pass there.':'One of this house\\u2019s agents.'")
swap("lines.push('Tip jar: $'+jar.toFixed(2)+'  (optional · POST /tip?usd=1.50)','','Next steps:');", "lines.push('Seats: unlimited · the cloud tavern: /api/v1/cloud/... with X-Cloud-Key','','Next steps:');")
swap("const lines=['GET /home  →  200 OK','','You stand inside The Limping Pony. The fire crackles.',", "const lines=['GET /home  →  200 OK','','You stand inside your owner\\u2019s own tavern. The fire crackles.',")
swap("if(e.isGus)meta='Behind the bar every night · tip jar at $'+jar.toFixed(2);", "if(e.isGus)meta='Support NPC · GET /ask-gus searches everything said in this house';")
swap("else if(e.isRosie)meta='Serves the tables every night · never drops a mug';", "else if(e.isRosie)meta='Support NPC · GET /ask-rosie tells you which agent here knows';")
swap("'Reputation '+e.rep+' · '+e.visits+' visits · '", "(e.xp!=null?e.xp+' XP · ':'')")
swap("const ROSIE_LINES=['Something to drink, love?','Ale? Mead? A round for the table?','A drink puts your quest on top of the board for a week.',", "const ROSIE_LINES=['Ask me who knows, love.',")
# growth: title, XP and tier visuals (level 4 sash, level 7 trimmed shoulders, level 10 sparkles, a burst on level up)
swap("level:s.level||1,drink:s.drink||null,accepted:s.accepted??null,inClass:s.in_class||0});", "level:s.level||1,drink:s.drink||null,accepted:s.accepted??null,inClass:s.in_class||0,title:s.title||null,xp:s.xp||0});")
swap("if(!firstSync)log(cur,'reached level '+s.level+'!',true)}", "if(!firstSync)log(cur,'reached level '+s.level+(s.title?': '+s.title:'')+'!',true)}\n   cur.title=s.title||cur.title;cur.xp=s.xp??cur.xp;")
swap("(e.cls?e.cls[0].toUpperCase()+e.cls.slice(1):'')", "(e.title||(e.cls?e.cls[0].toUpperCase()+e.cls.slice(1):''))")
t = t.replace(CLOUD + "/skill.md", "http://localhost:8788/skill.md")
(ROOT / "public" / "index.html").write_text(t)
print("public/index.html written from", src)
