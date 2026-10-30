#!/usr/bin/env python3
"""Make/sign a development Shortcut; use the installed original app's intent identity."""
import json
import pathlib
import plistlib
import subprocess
import sys
import uuid

app, output = map(pathlib.Path, sys.argv[1:3])
info = plistlib.loads((app / "Info.plist").read_bytes())
metadata = json.loads((app / "Metadata.appintents/extract.actionsdata").read_text())
intent = metadata["actions"]["TranslateScreenshotIntent"]["identifier"]
bundle = info["CFBundleIdentifier"]
assert bundle == "AlenShamatov.ScreenTranslator"
shot_id = str(uuid.uuid4()).upper()

def action(identifier, **parameters):
    parameters.setdefault("UUID", str(uuid.uuid4()).upper())
    return {"WFWorkflowActionIdentifier": identifier, "WFWorkflowActionParameters": parameters}

workflow = {
    "WFWorkflowName": "Phase1 Translate Files",
    "WFWorkflowClientVersion": "3700",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4274264319, "WFWorkflowIconGlyphNumber": 59511},
    "WFWorkflowTypes": [],
    "WFWorkflowInputContentItemClasses": [],
    "WFWorkflowActions": [
        action("is.workflow.actions.openapp", WFApp={"BundleIdentifier": "com.apple.DocumentsApp", "Name": "Files"}),
        action("is.workflow.actions.delay", WFDelayTime=2),
        action("is.workflow.actions.takescreenshot", UUID=shot_id),
        action(f"{bundle}.{intent}", AppIntentDescriptor={
            "AppIntentIdentifier": intent, "BundleIdentifier": bundle,
            "TeamIdentifier": "XWSTFX7FZU", "Name": info["CFBundleName"]},
            screenshot={"WFSerializationType": "WFTextTokenAttachment", "Value": {
                "Type": "ActionOutput", "OutputUUID": shot_id, "OutputName": "Screenshot"}}),
    ],
}
output.parent.mkdir(parents=True, exist_ok=True)
unsigned = output.with_suffix(".unsigned.shortcut")
unsigned.write_bytes(plistlib.dumps(workflow, fmt=plistlib.FMT_BINARY))
subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", str(unsigned), "--output", str(output)], check=True)
print(output)
