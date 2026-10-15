"""Read-only preservation/link checks and a reviewable file manifest. Never reads secret files."""
import hashlib,json,re
from pathlib import Path
root=Path(__file__).resolve().parent.parent
baseline=json.loads((root/'Temp/m05-baseline-files.json').read_text(encoding='utf-8-sig'))
base={x['path'].replace('\\','/'):x['hash'] for x in baseline}
modified=[];missing=[];created=[]
for name,digest in base.items():
    p=root/name
    if not p.exists():missing.append(name)
    elif hashlib.sha256(p.read_bytes()).hexdigest().upper()!=digest.upper():modified.append(name)
for folder in ['Assets/Mmorpg','AgentScripts','Backend/authority','supabase','Docs']:
    for p in (root/folder).rglob('*'):
        if not p.is_file():continue
        name=p.relative_to(root).as_posix()
        if p.name.startswith('.env') and p.name!='.env.example':continue
        if '.temp' in p.parts or 'data' in p.parts:continue
        if name not in base:created.append(name)
for name in ['.gitignore','Backend/decisions/marco05_test.go','Backend/decisions/marco05_manual_test.go']:
    if (root/name).exists() and name not in base:created.append(name)
broken=[]
for name in ['Architecture.md','SupabaseIntegration.md','WorldContent.md','Abilities.md','Items.md','WorldMap.md','Simulation.md','Validation/Marco05.md','Validation/Marco05A.md','Validation/Marco05B.md','Validation/Marco05C.md']:
    p=root/'Docs'/name
    for link in re.findall(r'\]\(([^)]+)\)',p.read_text(encoding='utf-8')):
        if link.startswith(('http','app:','#')):continue
        link=link.split('#')[0]
        if not (p.parent/link).exists():broken.append({'document':name,'link':link})
saves=[]
for entry in json.loads((root/'Temp/m05-baseline-saves.json').read_text(encoding='utf-8-sig')):
    p=Path(entry['path']);saves.append({'path':str(p),'unchanged':p.exists() and hashlib.sha256(p.read_bytes()).hexdigest().upper()==entry['hash'].upper()})
report={'created':sorted(set(created)),'modifiedOriginals':sorted(modified),'missingOriginals':missing,'brokenDocumentationLinks':broken,'originalSaves':saves,'credentialsExcluded':True}
(root/'Docs/Validation/m05-files.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'createdFiles':len(set(created)),'modifiedOriginals':modified,'missingOriginals':missing,'brokenDocumentationLinks':broken,'allOriginalSavesMatch':all(x['unchanged'] for x in saves)},ensure_ascii=False))
if missing or broken or not all(x['unchanged'] for x in saves):raise SystemExit(1)
