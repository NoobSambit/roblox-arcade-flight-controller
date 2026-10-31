"""Standard-library check for the explicit public source package boundary."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
files = json.loads((ROOT / 'package-files.json').read_text(encoding='utf-8'))
assert len(files) == len(set(files)), 'Duplicate manifest entries'
actual = {str(p.relative_to(ROOT)).replace('\\', '/') for p in ROOT.rglob('*')
          if p.is_file() and '.git' not in p.relative_to(ROOT).parts
          and '__pycache__' not in p.relative_to(ROOT).parts}
assert actual == set(files), f'Unlisted/missing files: {actual ^ set(files)}'
digest = hashlib.sha256()
for name in files:
    path = ROOT / name
    assert not path.is_symlink() and path.resolve().is_relative_to(ROOT), name
    data = path.read_bytes()
    text = data.decode('utf-8')
    assert not re.search(r'rbxassetid://\d+|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}', text), name
    if path.suffix == '.luau':
        assert not re.search(r'Vimana|Vehicles023|INDIAN HOOD|74021733262795|A-Chassis|HttpService|loadstring', text), name
        assert not re.search(r'require\s*\(\s*\d', text), name
    digest.update(name.encode() + b'\0' + data)
print(f'PASS: {len(files)} allowlisted text files; package SHA256 {digest.hexdigest()}')
