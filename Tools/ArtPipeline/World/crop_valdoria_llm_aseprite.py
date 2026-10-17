"""Export isolated, alpha-cleaned crops from the Aseprite-refined LLM atlas."""
from pathlib import Path
import hashlib, json, subprocess

ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/"ArtSource/Labs/World2026/R10/Aseprite/valdoria-llm-detail-clean.aseprite"
OUT=ROOT/"Assets/Mmorpg/Art/Experimental/ValdoriaEnvironmentR10Llm"
ITEMS={
    # crop: x, y, width, height, normalized bottom-left pivot, role
    "village-panorama": (0,0,990,690,(0.5,0.5),"continuous village-edge grass, stone path and winding stream composition"),
    "oak-full": (478,0,338,360,(0.5,0.06),"large oak canopy, trunk and root silhouette"),
    "oak-bare": (816,155,188,242,(0.5,0.05),"separate bare oak trunk with roots"),
    "cottage-roof": (972,0,482,397,(0.5,0.05),"large thatch roof with dormer, separate roof layer"),
    "cottage-front": (996,274,379,386,(0.5,0.04),"stone and timber cottage facade, entry, steps and window box"),
    "cottage-full": (972,0,472,650,(0.5,0.03),"complete cottage composition including thatched roof, stone facade and doorway"),
    "cottage-side": (1368,287,168,230,(0.5,0.04),"small gabled cottage front"),
    "footbridge": (0,660,488,356,(0.5,0.05),"timber bridge with stone landing and water"),
    "village-well": (488,735,234,289,(0.5,0.04),"stone well, canopy, winch and buckets"),
    "market-cart": (696,755,287,269,(0.5,0.04),"loaded timber market wagon"),
    "berry-garden": (972,410,210,225,(0.5,0.04),"flowering berry bush"),
    "flowers-blue-white": (872,453,192,211,(0.5,0.04),"mixed white and blue wildflower clump"),
    "flowers-gold-purple": (804,539,194,215,(0.5,0.04),"gold and purple tall flowers"),
    "moss-boulders": (1150,543,155,148,(0.5,0.04),"moss-covered stone clusters"),
    "timber-fence": (1012,787,214,237,(0.5,0.04),"flowered timber fence module"),
    "village-bench": (1197,832,168,192,(0.5,0.04),"detailed timber bench"),
    "village-sign": (1275,711,145,226,(0.5,0.04),"painted wooden wayfinding sign"),
    "lantern-post": (1415,710,121,232,(0.5,0.04),"warm amber hanging lantern"),
    "stone-chimney": (1438,100,98,233,(0.5,0.04),"masonry chimney prop"),
}

def main():
    if not SOURCE.is_file(): raise FileNotFoundError(SOURCE)
    if OUT.exists(): raise FileExistsError(f"Refusing to change a published library: {OUT}. Use rebuild_valdoria_r10.py --output <new-dir>.")
    OUT.mkdir(parents=True,exist_ok=True)
    exe=Path(r"D:\Aseprite\Aseprite.exe")
    manifest_path=OUT/"manifest.json"
    existing={}
    if manifest_path.exists():
        existing={item["id"]:item for item in json.loads(manifest_path.read_text(encoding="utf-8")).get("assets",[])}
    rows=list(existing.values())
    for name,(x,y,w,h,pivot,description) in ITEMS.items():
        path=OUT/f"{name}.png"
        if path.exists():
            if name not in existing: raise FileExistsError(f"Unregistered crop already exists; refusing overwrite: {path}")
            continue
        run=subprocess.run([str(exe),"-b",str(SOURCE),"--crop",f"{x},{y},{w},{h}","--save-as",str(path)],capture_output=True,text=True)
        if run.returncode or not path.is_file(): raise RuntimeError(f"Aseprite crop failed {name}: {run.stdout}\n{run.stderr}")
        rows.append({"id":name,"file":path.name,"sourceCrop":[x,y,w,h],"canvas":[w,h],"ppu":32,"pivotNormalizedBottomLeft":list(pivot),"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"description":description})
    manifest={"schema":"valdoria-environment-kit/v2","status":"experimental-integrated-for-gameplay-review","source":"Aseprite-cleaned LLM concept reference; original concept stays separate and Aseprite source remains editable","artSource":"ArtSource/Labs/World2026/R10/Aseprite/valdoria-llm-detail-clean.aseprite","conceptReference":"ArtSource/References/Generated/ValdoriaVillageR10-Detail-LLM.png","license":"generated locally for this project; no external source asset","pixelsPerUnit":32,"filter":"Point","assets":rows}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"assets":len(rows),"output":str(OUT),"source":str(SOURCE)},indent=2))
if __name__=="__main__": main()
