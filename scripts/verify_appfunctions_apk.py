"""Fail the build if Android cannot discover the generated AppFunctions schema."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
from zipfile import ZipFile


def verify(path: Path) -> None:
    with ZipFile(path) as apk:
        schema = apk.read("assets/yabus_app_functions.xml")
        apk.getinfo("assets/app_functions_schema.xsd")
    root = ET.fromstring(schema)
    actual = {entry.findtext("id") for entry in root.findall("appfunction")}
    prefix = "tw.avianjay.taiwanbus.flutter.BaseYabusAppFunctionService#"
    expected = {prefix + name for name in (
        "listFavoriteGroups", "listFavorites", "openFavorite", "openFavoriteGroup",
    )}
    if actual != expected:
        raise ValueError("APK AppFunctions schema does not contain exactly the four supported functions")
    print("APK contains all four AppFunctions and the platform schema")


if __name__ == "__main__":
    verify(Path(sys.argv[1]))
