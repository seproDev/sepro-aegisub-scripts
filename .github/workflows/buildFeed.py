import os
import json
import re
from datetime import datetime
from packaging import version
import hashlib

# Try to read existing DependencyControl.json
if os.path.isfile("DependencyControl.json"):
    with open("DependencyControl.json") as f:
        feed = json.load(f)
else:
    # Build basic feed
    print("No feed exists. Trying to create one.")
    feed = {
        "dependencyControlFeedFormatVersion": "0.3.0",
        "name": os.environ["FEED_NAME"],
        "description": os.environ["FEED_DESCRIPTION"],
        "maintainer": os.environ["FEED_MAINTAINER"],
        "baseUrl": os.environ["REPO_URL"],
        "url": "@{baseUrl}",
        "fileBaseUrl": f"https://raw.githubusercontent.com/{os.environ['REPO_PATH']}/@{{channel}}/",
        "knownFeeds": {},
        "macros": {},
        "modules": {},
    }

automation_type = os.environ["AUTOMATION_TYPE"]
automation_namespace = os.environ["AUTOMATION_NAMESPACE"]
automation_changelog = os.environ["AUTOMATION_CHANGELOG"]


if os.path.isfile(f"{automation_type}/{automation_namespace}.lua"):
    file_location = f"{automation_type}/{automation_namespace}.lua"
elif os.path.isfile(f"{automation_type}/{automation_namespace}.moon"):
    file_location = f"{automation_type}/{automation_namespace}.moon"
else:
    print("Could not find automation file")
    exit(1)

file_name = os.path.basename(file_location)

# Calculate filehash
file_sha1 = hashlib.sha1()

with open(file_location, "rb") as f:
    data = f.read()
    file_sha1.update(data)

file_hash = file_sha1.hexdigest()


# Get info from file
def extract_property(script, property):
    match = re.findall(
        f"\\s*{property}\\s*=\\s*(?:tr)?(?:\"([^\"]*)\"|'([^']*)')", script
    )
    if len(match) == 1:
        return match[0][0] or match[0][1]
    else:
        print(f"Couldn't find property {property}")
        exit(1)


with open(file_location) as f:
    script_text = f.read()

if automation_type == "macros":
    script_name = extract_property(script_text, "script_name")
    script_description = extract_property(script_text, "script_description")
    script_author = extract_property(script_text, "script_author")
    script_version = extract_property(script_text, "script_version")
    script_namespace = extract_property(script_text, "script_namespace")
elif automation_type == "modules":
    script_name = extract_property(script_text, "name")
    script_description = extract_property(script_text, "description")
    script_author = extract_property(script_text, "author")
    script_version = extract_property(script_text, "version")
    script_namespace = extract_property(script_text, "moduleName")
else:
    print("Unknown automation type")
    exit(1)

if script_namespace != automation_namespace:
    print("Namespace mismatch")
    exit(1)


default_branch = os.environ["REPO_BRANCH"]
current_date = datetime.today().strftime("%Y-%m-%d")

# Try to find existing automation in feed
if automation_namespace in feed[automation_type]:
    automation = feed[automation_type][automation_namespace]

    if not default_branch in automation["channels"]:
        print(f"No channel for branch {default_branch}")
        exit(1)

    current_version = automation["channels"][default_branch]["version"]
    if version.parse(script_version) <= version.parse(current_version):
        print("File version did not increase")
        exit(1)

else:
    print("Automation not present in feed. Adding it.")
    automation = {
        "url": "@{baseUrl}#@{namespace}",
        "fileBaseUrl": f"@{{fileBaseUrl}}/{automation_type}/",
        "channels": {
            default_branch: {
                "default": True,
            }
        },
        "changelog": {},
        "requiredModules": [],
    }
    feed[automation_type][automation_namespace] = automation

# Update variables
automation["name"] = script_name
automation["description"] = script_description
automation["author"] = script_author

automation["channels"][default_branch]["version"] = script_version
automation["channels"][default_branch]["released"] = current_date
automation["channels"][default_branch]["files"] = [
    {
        "name": file_name,
        "url": "@{fileBaseUrl}@{fileName}",
        "sha1": file_hash,
    }
]

if automation_changelog != None:
    automation["changelog"][script_version] = automation_changelog.split("\\n")


# Write back JSON file
with open("DependencyControl.json", "w", encoding="utf8") as f:
    json.dump(feed, f, indent=4)
