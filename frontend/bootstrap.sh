#!/usr/bin/env bash
set -euo pipefail

frontend_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for command_name in flutter python3; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Perintah %s tidak ditemukan. Ikuti README.arch-linux.md terlebih dahulu.\n' "$command_name" >&2
    exit 1
  fi
done

if [[ ! -d "$frontend_root/android" ]]; then
  template_root="$(mktemp -d "${TMPDIR:-/tmp}/cms-flutter.XXXXXXXX")"
  trap 'rm -rf -- "$template_root"' EXIT
  flutter create --platforms=android --org=id.cms --project-name=cms_mobile --empty --no-pub "$template_root"
  cp -R -- "$template_root/android" "$frontend_root/android"
  cp -- "$template_root/.metadata" "$frontend_root/.metadata"
fi

python3 - "$frontend_root" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

root = Path(sys.argv[1])
namespace = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", namespace)
android = "{" + namespace + "}"

main_path = root / "android/app/src/main/AndroidManifest.xml"
main_tree = ET.parse(main_path)
manifest = main_tree.getroot()
application = manifest.find("application")
if application is None:
    raise SystemExit("Manifest utama tidak memiliki application; periksa folder android.")
if not any(item.get(android + "name") == "android.permission.INTERNET"
           for item in manifest.findall("uses-permission")):
    permission = ET.Element("uses-permission", {android + "name": "android.permission.INTERNET"})
    manifest.insert(0, permission)
application.set(android + "label", "CMS")
ET.indent(main_tree, space="    ")
main_tree.write(main_path, encoding="utf-8", xml_declaration=True)

debug_path = root / "android/app/src/debug/AndroidManifest.xml"
debug_tree = ET.parse(debug_path)
debug_application = debug_tree.getroot().find("application")
if debug_application is None:
    debug_application = ET.SubElement(debug_tree.getroot(), "application")
debug_application.set(android + "usesCleartextTraffic", "true")
ET.indent(debug_tree, space="    ")
debug_tree.write(debug_path, encoding="utf-8", xml_declaration=True)
PY

cd -- "$frontend_root"
flutter pub get
flutter analyze
printf 'Bootstrap Android selesai. Jalankan flutter devices lalu flutter run.\n'
