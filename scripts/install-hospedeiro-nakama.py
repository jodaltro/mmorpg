"""Install pinned Windows binaries on D:; no service, PATH or registry changes."""
from pathlib import Path
import tarfile
import urllib.request
import zipfile

ROOT = Path('D:/tools/hospedeiro-online')
PACKAGES = {
    'nakama.tar.gz': 'https://github.com/heroiclabs/nakama/releases/download/v3.41.0/nakama-3.41.0-windows-amd64.tar.gz',
    'postgres.zip': 'https://get.enterprisedb.com/postgresql/postgresql-17.6-2-windows-x64-binaries.zip',
}

def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, url in PACKAGES.items():
        target = ROOT / name
        if not target.exists():
            temporary = target.with_suffix('.download')
            urllib.request.urlretrieve(url, temporary)
            temporary.replace(target)
        if name.endswith('.gz'):
            with tarfile.open(target) as archive:
                archive.extractall(ROOT / 'nakama', filter='data')
        else:
            with zipfile.ZipFile(target) as archive:
                for entry in archive.namelist():
                    if entry.startswith(('pgsql/bin/', 'pgsql/lib/', 'pgsql/share/')):
                        archive.extract(entry, ROOT)
        print('Installed', name)

if __name__ == '__main__':
    main()
