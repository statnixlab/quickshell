#!/usr/bin/env python3
"""Localized XKB layout and option catalog for the keyboard settings page."""
import gettext
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ElementTree

RULES = Path('/usr/share/X11/xkb/rules/evdev.xml')
# Caps Lock behaviors offered by the page; other XKB options are preserved as-is.
CAPS_OPTIONS = ('ctrl:nocaps', 'ctrl:swapcaps', 'caps:escape', 'caps:swapescape', 'caps:backspace', 'caps:none')


def translator(language):
    for domain in ('xkeyboard-config-2', 'xkeyboard-config'):
        try:
            return gettext.translation(domain, languages=[language, language.split('_')[0]]).gettext
        except (OSError, ValueError):
            continue
    return lambda text: text


def item(element, translate):
    config = element.find('configItem')
    name = config.findtext('name') or ''
    description = config.findtext('description') or name
    return dict(name=name, label=translate(description))


def catalog(request):
    translate = translator(str(request.get('language') or 'en_US'))
    root = ElementTree.parse(request.get('rules') or RULES).getroot()
    layouts = []
    for layout in root.iterfind('layoutList/layout'):
        entry = item(layout, translate)
        entry['variants'] = sorted((item(variant, translate) for variant in layout.iterfind('variantList/variant')),
                                   key=lambda row: row['label'])
        layouts.append(entry)
    layouts.sort(key=lambda row: row['label'])
    options = {}
    for group in root.iterfind('optionList/group'):
        for option in group.iterfind('option'):
            row = item(option, translate)
            options[row['name']] = row
    switch = sorted((row for name, row in options.items() if name.startswith('grp:')), key=lambda row: row['label'])
    caps = [options[name] for name in CAPS_OPTIONS if name in options]
    return dict(schemaVersion=1, layouts=layouts, switchOptions=switch, capsOptions=caps)


if __name__ == '__main__':
    try:
        request = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}
        print(json.dumps(catalog(request), ensure_ascii=False))
    except Exception as error:
        print(json.dumps(dict(schemaVersion=1, error=str(error))), flush=True)
        print(str(error), file=sys.stderr)
        sys.exit(1)
