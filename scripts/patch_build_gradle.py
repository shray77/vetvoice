#!/usr/bin/env python3
"""Патчит android/app/build.gradle для использования release.keystore."""
import sys
from pathlib import Path

gradle_path = Path('android/app/build.gradle')
if not gradle_path.exists():
    print(f'ERROR: {gradle_path} not found')
    sys.exit(1)

content = gradle_path.read_text()
if 'def keystoreProperties' in content:
    print('build.gradle already patched')
    sys.exit(0)

patch = '''
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
'''
content = content.replace('android {', patch + '\nandroid {', 1)

old_block = '    buildTypes {\n        release {\n            signingConfig = signingConfigs.debug'
new_block = (
    '    signingConfigs {\n'
    '        release {\n'
    '            if (keystorePropertiesFile.exists()) {\n'
    "                keyAlias keystoreProperties['keyAlias']\n"
    "                keyPassword keystoreProperties['keyPassword']\n"
    "                storeFile file(keystoreProperties['storeFile'])\n"
    "                storePassword keystoreProperties['storePassword']\n"
    '            }\n'
    '        }\n'
    '    }\n'
    '    buildTypes {\n'
    '        release {\n'
    '            signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug'
)

if old_block in content:
    content = content.replace(old_block, new_block)
else:
    print('WARN: block not found for replacement')

gradle_path.write_text(content)
print('OK: build.gradle patched')
