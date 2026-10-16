"""Reviewed glove projections for the new, unmodified Hormelz cels only."""
import json
from pathlib import Path
hands = {
 'dodge': {
  'south': [(105,100),(108,100),(109,96),(109,96),(100,101),(100,101),(103,100),(103,100),(105,100)],
  'west': [(142,97),(140,95),(134,86),(130,81),(122,89),(122,87),(122,87),(130,90),(134,88)],
  'north': [(146,112),(149,112),(153,104),(157,96),(155,98),(156,97),(159,97),(158,100),(151,104)],
  'east': [(117,116),(118,118),(123,113),(131,109),(130,116),(133,115),(133,115),(134,116),(123,112)]},
 'hurt': {
  'south': [(105,100),(107,100),(115,100),(117,96),(112,89),(112,87),(111,94)],
  'west': [(142,97),(143,97),(150,104),(150,104),(145,98),(143,95),(146,96)],
  'north': [(146,112),(144,114),(140,121),(145,121),(140,125),(145,118),(147,114)],
  'east': [(117,116),(116,116),(106,117),(102,113),(105,112),(104,111),(109,112)]}}
if __name__=='__main__':
 p=Path('ArtSource/Labs/IronKnight2026/B11/manifest.json')
 m=json.loads(p.read_text())
 for c in m['clips']:
  if c['animation']=='death': continue
  for i,f in enumerate(c['frames']):
   f['rightHand']=hands[c['animation']][c['direction']][i]
   f['anchorReview']='manual glove projection; rear wrist occluded in west dodge 4-6 and west hurt 3-5'
 m['weaponReview']='New gloves reviewed individually; rear hand projected behind torso when occluded. B10 anchors reused verbatim.'
 p.write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8')
