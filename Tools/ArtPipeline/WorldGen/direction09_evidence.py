"""Read-only measurements and review boards from real authored/exported pixels."""
import colorsys,json,math
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
import visual_unification09 as v

def font(size=18):return ImageFont.truetype('C:/Windows/Fonts/consola.ttf',size)
def main():
 out=v.EVIDENCE;measure={};board=Image.new('RGB',(1500,1390),'#30372d');d=ImageDraw.Draw(board);d.text((24,16),'VALDORIA 09 - MATERIAL LANGUAGE / REAL SOURCE PIXELS',font=font(26),fill='white')
 for index,(family,(folder,filename,_)) in enumerate(v.FAMILIES.items()):
  meta=v.ref.read(v.ROOT/folder/'SourceV1/house-source.json');p=np.array(meta['frontGroundMaster']);angle=math.degrees(math.atan2(*(p[1]-p[0])[::-1]));height=(meta['doorOpeningMasterPixels']['foot'][1]-meta['doorOpeningMasterPixels']['head'][1])*meta['scaleFromPaintedMaster']/32
  layers=['Roof','WallsSide','Foundation'] if family!='castle' else ['KeepRoof','KeepWalls','LeftTower'];measure[family]={'guideFrontAngleDegrees':angle,'guideIsApproximateNotAnExactPixelEdge':True,'doorHeightUnits':height,'heroVisibleHeightUnits':117*1.25/32,'doorToHeroRatio':height/(117*1.25/32),'layers':{}}
  d.text((24,75+index*255),family.upper()+' - maintained09 / 1x detail',font=font(),fill='#dfd4b6')
  for col,layer in enumerate(layers):
   src=Image.open(v.BASE/'Architecture'/family/'maintained/Export'/(layer+'-trim.png')).convert('RGBA');a=np.array(src);rgb=a[a[:,:,3]>200,:3]/255.;hsv=np.array([colorsys.rgb_to_hsv(*c) for c in rgb[::max(1,len(rgb)//50000)]]);luma=rgb@np.array([.2126,.7152,.0722]);stats={'hsvSaturationPercentP10MedianP90':np.round(np.quantile(hsv[:,1],[.1,.5,.9])*100,2).tolist(),'encodedRGBLumaP10MedianP90':np.round(np.quantile(luma,[.1,.5,.9]),4).tolist()};measure[family]['layers'][layer]=stats
   # True 1x crop; never rescale native pixel detail.
   cw,ch=min(370,src.width),min(166,src.height);mask=(a[:,:,3]>200).astype(int);integral=np.pad(mask,((1,0),(1,0))).cumsum(0).cumsum(1)
   options=[(int(integral[y+ch,x+cw]-integral[y,x+cw]-integral[y+ch,x]+integral[y,x]),x,y) for y in range(0,src.height-ch+1,8) for x in range(0,src.width-cw+1,8)]
   _,cx,cy=max(options);crop=src.crop((cx,cy,cx+cw,cy+ch))
   x=24+col*490;y=108+index*255;board.paste(crop,(x,y),crop);d.text((x,y+169),layer,font=font(16),fill='white');d.text((x,y+191),'S median '+str(stats['hsvSaturationPercentP10MedianP90'][1])+'%',font=font(14),fill='#bbbbad')
 for row,(kind,colors) in enumerate(v.PALETTES.items()):
  y=860+row*68;d.text((25,y+15),kind,font=font(),fill='white')
  for j,color in enumerate(colors):
   x=180+j*205;d.rectangle((x,y,x+194,y+38),fill=color);d.text((x,y+41),color,font=font(14),fill='#ded5bd')
 d.text((24,1290),'Upper-left warm light / cool recesses / Point RGBA32 / 32 PPU',font=font(18),fill='white');d.text((24,1325),'Original house07R is the finish reference. 09 revisions await user review.',font=font(16),fill='#ded5bd');board.save(out/'visual-language-material-board.png');v.write(out/'measured-style.json',measure)
 # Same-scale game shots, explicitly labelled. No colour correction.
 for family in ['House','Barn']:
  images=[Image.open(out/(family+'QA')/f'00-{s}-same-pose.png').convert('RGB') for s in 'ABC'];sheet=Image.new('RGB',(1280,3*750),'#222820');draw=ImageDraw.Draw(sheet)
  for j,im in enumerate(images):sheet.paste(im,(0,j*750+30));draw.text((12,j*750+5),['A - previous environment / current architecture','B - revised material families','C - materials + revised vegetation'][j],font=font(18),fill='white')
  sheet.save(out/(family.lower()+'-ABC-same-camera.png'))
 # Do not label these as Unity video; derived GIFs retain original frames.
 for folder in ['HouseQA','BarnQA','CastleQA','EnvironmentQA']:
  frames=[Image.open(p).convert('RGB') for p in sorted((out/folder/'Motion').glob('*.png'))]
  if frames:frames[0].save(out/folder/'camera-motion.gif',save_all=True,append_images=frames[1:],duration=100,loop=0)
 performance={}
 for family in ['House','Barn','Castle']:
  data=v.ref.read(out/(family+'QA')/'play-qa.json');performance[family]={}
  for item in data['results']:
   if item['name'].startswith('ABC material'):
    p=item['evidence']['performance'];performance[family]['ABC'[item['evidence']['stage']]]={k:p[k] for k in ['drawCalls','renderers','visible','textureCount','textureBytes']}
  editor=v.ref.read(out/(family+'QA')/'editor-qa.json');performance[family]['comparisonResidentTextureCount']=editor['comparisonResidentTextureCount'];performance[family]['comparisonResidentTextureBytes']=editor['comparisonResidentTextureBytes']
 v.write(out/'performance-summary.json',performance)
 # Pixel-identical Aseprite reexports are checked separately by the tests.
if __name__=='__main__':main()
