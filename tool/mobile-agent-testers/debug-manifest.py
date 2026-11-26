"""Apply CI-only metadata to the disposable *debug* manifest, never release."""
import json
import secrets
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

path = Path(sys.argv[1])
ns = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', ns)
tree = ET.parse(path)
app = tree.find('application')
if app is None:
    app = ET.SubElement(tree.getroot(), 'application')
# Deactivated overrides Dart's runtime setAnalyticsCollectionEnabled(true).
for name, value in [('firebase_analytics_collection_deactivated', 'true'),
                    ('firebase_messaging_auto_init_enabled', 'false')]:
    node = app.find(f"meta-data[@{{{ns}}}name='{name}']")
    if node is None:
        node = ET.SubElement(app, 'meta-data', {f'{{{ns}}}name': name})
    node.set(f'{{{ns}}}value', value)
tree.write(path, encoding='utf-8', xml_declaration=True)

# auto_init=false alone doesn't stop the app from explicitly calling getToken()
# and posting it to /api/v1/push/fcm-token. Isolate this APK from the real FCM
# project. Gradle prefers src/debug/google-services.json over the app-wide file.
# Keep package matching, not production project identifiers or client keys.
source = path.parents[2] / 'google-services.json'
packages = [c['client_info']['android_client_info']['package_name']
            for c in json.loads(source.read_text(encoding='utf-8'))['client']]
fixture = {'project_info': {'project_number': '000000000000', 'project_id': 'demo-yabus-ui-tests'},
           'client': [{'client_info': {'mobilesdk_app_id': '1:000000000000:android:0000000000000000',
                                       'android_client_info': {'package_name': package}},
                       'api_key': [{'current_key': secrets.token_hex(16)}]} for package in packages],
           'configuration_version': '1'}
(path.parent / 'google-services.json').write_text(json.dumps(fixture), encoding='utf-8')
