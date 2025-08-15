import os
import re
import requests

LANGUAGES = {
    'es': 'es',
    'fr': 'fr',
    'de': 'de',
    'zh-CN': 'zh-Hans',
    'ru': 'ru',
    'ar': 'ar',
    'pt': 'pt'
}

SRC_FILE = os.path.join('ScreenShotAutoRun', 'en.lproj', 'Localizable.strings')
pattern = re.compile(r'"(.+)"\s*=\s*"(.+)";')

def translate(text, dest):
    url = 'https://translate.googleapis.com/translate_a/single'
    params = {
        'client': 'gtx',
        'sl': 'en',
        'tl': dest,
        'dt': 't',
        'q': text,
    }
    response = requests.get(url, params=params, timeout=10)
    data = response.json()
    return data[0][0][0]

with open(SRC_FILE, 'r', encoding='utf-8') as f:
    entries = []
    for line in f:
        line = line.strip()
        if not line or line.startswith('//'):
            continue
        m = pattern.match(line)
        if m:
            entries.append((m.group(1), m.group(2)))

for lang_code, folder_code in LANGUAGES.items():
    print(f'Translating to {lang_code}...')
    out_dir = os.path.join('ScreenShotAutoRun', f'{folder_code}.lproj')
    os.makedirs(out_dir, exist_ok=True)
    out_file = os.path.join(out_dir, 'Localizable.strings')
    with open(out_file, 'w', encoding='utf-8') as out:
        for key, source in entries:
            value = translate(source, lang_code)
            value = value.replace('"', '\\"')
            out.write(f'"{key}" = "{value}";\n')
    print(f'Written {out_file}')
