#!/usr/bin/env python3
"""Fail closed for missing owner inputs. Does not contact paid services or print keys."""
from pathlib import Path
import json, re, struct, sys, urllib.parse
root=Path(__file__).resolve().parents[1]
failures=[]
config=(root/'Config/Local.xcconfig').read_text() if (root/'Config/Local.xcconfig').exists() else ''
def setting(name):
 m=re.search(r'^'+name+r'\s*=\s*(.*)$',config,re.M);return m.group(1).strip().replace('$()','') if m else ''
for name in ['SUPABASE_URL','SUPABASE_PUBLISHABLE_KEY','PRIVACY_URL','TERMS_URL','SUPPORT_URL','DEVELOPMENT_TEAM']:
 value=setting(name)
 if not value or 'YOUR_' in value:failures.append(name+' is not configured')
 elif name.endswith('URL'):
  u=urllib.parse.urlparse(value)
  if u.scheme!='https' or not u.hostname or u.hostname in ('localhost','127.0.0.1'):failures.append(name+' must use a real public HTTPS URL')
manifest=json.loads((root/'docs/catalog-source-manifest.json').read_text())
if not manifest.get('releaseCurationComplete'):failures.append('Catalog entrance/access/date-specific hours curation remains incomplete')
if not (root/'Between.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved').exists():failures.append('Swift package lockfile missing')
icon=root/'App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
if icon.exists():
 data=icon.read_bytes();w,h=struct.unpack('>II',data[16:24]);color=data[25]
 if (w,h)!=(1024,1024) or color in (4,6):failures.append('App icon must be opaque 1024×1024 RGB')
else:failures.append('App icon missing')
for name in ['HOSTED_BACKEND_VERIFIED','APPLE_SIGNIN_AND_REVOCATION_VERIFIED','PHYSICAL_DEVICE_VERIFIED']:
 if setting(name)!='YES':failures.append(name+' must be confirmed after actual verification')
if failures:
 print('Release is blocked:');print('\n'.join(' - '+x for x in failures));sys.exit(1)
print('Local release inputs are present. This does not replace App Store review or signing validation.')
