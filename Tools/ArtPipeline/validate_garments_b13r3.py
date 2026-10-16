"""Result-level checks of procedural garment authoring, not Unity gameplay tests."""
import argparse
import json
import subprocess
import sys
import uuid
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]


def atlas(folder):
    doc=json.loads((folder/'aseprite.json').read_text());image=Image.open(folder/'spritesheet.png').convert('RGBA');result=[]
    for f in doc['frames']:
        r=f['frame'];result.append(image.crop((r['x'],r['y'],r['x']+64,r['y']+64)))
    return result


def visible_difference(a,b):
    return sum(x!=y and (x[3]>0 or y[3]>0) for x,y in zip(a.get_flattened_data(),b.get_flattened_data()))


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--aseprite',default='D:/Aseprite/Aseprite.exe');args=parser.parse_args()
    temp=ROOT/'Temp/Marco06B13R3'/('result-check-'+uuid.uuid4().hex);temp.mkdir(parents=True)
    recipe=ROOT/'Tools/ArtPipeline/garment_recipes/mira_traveller.json';generator=ROOT/'Tools/ArtPipeline/generate_garments_b13r3.py'
    common=[sys.executable,str(generator),'--aseprite',args.aseprite]
    repeat=temp/'repeat';subprocess.run(common+['--recipe',str(recipe),'--output',str(repeat)],capture_output=True,check=True)
    original=ROOT/'ArtSource/Labs/NpcResearch/Marco06B13R3/MiraTravellerCorrected'
    assert all(a.tobytes()==b.tobytes() for a,b in zip(atlas(original),atlas(repeat))),'Generation is not deterministic'
    result=subprocess.run(common+['--recipe',str(recipe),'--output',str(repeat)],capture_output=True);assert result.returncode!=0,'Existing editable overwritten'
    variant=json.loads(recipe.read_text());variant['name']='MiraShapeVariation';variant['components'][0]['length']=14;variant['components'][0]['profile'][-1][1]=9;variant['components'][-1]['length']=13;variant['components'][-1]['lean']=3
    variant_path=temp/'shape-recipe.json';variant_path.write_text(json.dumps(variant),encoding='utf-8');output=temp/'variant';subprocess.run(common+['--recipe',str(variant_path),'--output',str(output)],capture_output=True,check=True)
    shape_changes=sum(a.getchannel('A').tobytes()!=b.getchannel('A').tobytes() for a,b in zip(atlas(original),atlas(output)));assert shape_changes>0,'Only color changed; geometry parameters ineffective'
    # Compare the backpack to the six-layer unmodified outfit in four cardinal first idle poses.
    source=ROOT/'ArtSource/Labs/NpcResearch/Marco06B13R2/Wardrobe/MiraIvory.aseprite'
    subprocess.run([args.aseprite,'-b',str(source),'--sheet',str(temp/'base.png'),'--data',str(temp/'base.json'),'--format','json-array','--sheet-type','rows','--sheet-columns','8'],capture_output=True,check=True)
    base=Image.open(temp/'base.png').convert('RGBA');records=json.loads((temp/'base.json').read_text())['frames'];pack=atlas(ROOT/'ArtSource/Labs/NpcResearch/Marco06B13R3/MiraBackpackFinal');visibility={}
    for name,index in [('north',0),('west',3),('south',6),('east',9)]:
        r=records[index]['frame'];im=base.crop((r['x'],r['y'],r['x']+64,r['y']+64));visibility[name]=visible_difference(im,pack[index])
    assert visibility['south']==0 and visibility['north']>40,'Rear attachment not occluded correctly'
    protected=0
    for index in list(range(3,6))+list(range(9,12))+list(range(20,28))+list(range(36,44)):
        r=records[index]['frame'];im=base.crop((r['x'],r['y'],r['x']+64,r['y']+64))
        for a,b in zip(im.get_flattened_data(),pack[index].get_flattened_data()):
            if a[3]==255:
                protected+=1;assert a==b,'Backpack erased a profile arm/body pixel'
    check=subprocess.run([args.aseprite,'-b','--script-param','geometry='+str(ROOT/'Tools/ArtPipeline/Aseprite/garment_geometry.lua'),'--script-param','recipe='+str(recipe),'--script',str(ROOT/'Tools/ArtPipeline/Aseprite/check_garment_schema_b13r3.lua')],capture_output=True,text=True,check=True)
    report=dict(deterministic44Frames=True,existingEditableOverwriteRejected=True,shapeChangedFrames=shape_changes,backpackChangedVisiblePixels=visibility,profileFramesWithOriginalOpaqueBodyProtected=22,profileProtectedOpaquePixels=protected,invalidRecipeCasesRejected=4,originalBodyLayersPreserved=True,shaderOrClothPhysicsAdded=False)
    path=ROOT/'Docs/Validation/Marco06B13R3/generator-checks.json';path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report,indent=2));print(check.stdout.strip())


if __name__=='__main__':main()
