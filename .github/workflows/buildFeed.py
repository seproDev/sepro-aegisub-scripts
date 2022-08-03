import os
import json
import re
from datetime import datetime
from packaging import version
import hashlib
import pathlib


def main():
    # Try to read existing DependencyControl.json
    if os.path.isfile("DependencyControl.json"):
        with open("DependencyControl.json") as f:
            feed = json.load(f)
    else:
        # Build basic feed
        print("No feed exists. Trying to create one.")
        feed = {
            "dependencyControlFeedFormatVersion": "0.3.0",
            "name": os.environ.get("FEED_NAME", "Feed"),
            "description": os.environ.get("FEED_DESCRIPTION", "No Description available"),
            "maintainer": os.environ.get("FEED_MAINTAINER", "Unknown"),
            "baseUrl": os.environ.get("REPO_URL"),
            "url": "@{baseUrl}",
            "fileBaseUrl": f"https://raw.githubusercontent.com/{os.environ.get('REPO_PATH')}/@{{channel}}/",
            "knownFeeds": {},
            "macros": {},
            "modules": {},
        }

    automation_type = os.environ.get("AUTOMATION_TYPE")
    automation_namespace = os.environ.get("AUTOMATION_NAMESPACE")
    automation_changelog = os.environ.get("AUTOMATION_CHANGELOG")

    if automation_type == None and automation_namespace == None:
        # Dev mode
        dev_branch = os.environ.get("DEV_REF").rsplit("/", 1)[1]
        print(f"Updating entire dev branch from {dev_branch}")
        for type in ["macros", "modules"]:
            files = list(pathlib.Path(type).glob("**.lua")) + list(pathlib.Path(type).glob("**.moon"))
            for file in files:
                namespace = os.path.basename(file).rsplit(".", 1)[0]
                print(f"Updating {type}/{namespace}")
                feed = update_automation(
                    file,
                    type,
                    namespace,
                    None,
                    dev_branch,
                    feed,
                )
    elif automation_type == None or automation_namespace == None:
        print("Missing automation variables")
        exit(1)
    else:
        # Regular release mode
        if automation_type == "macros":
            proto_path = f"{automation_type}/{automation_namespace}"
        elif automation_type == "modules":
            proto_path = f"{automation_type}/{automation_namespace.replace('.', '/')}"
        else:
            print("Unknown automation type")
            exit(1)
        
        if os.path.isfile(f"{proto_path}.lua"):
            file_location = f"{proto_path}.lua"
        elif os.path.isfile(f"{proto_path}.moon"):
            file_location = f"{proto_path}.moon"
        else:
            print("Could not find automation file")
            exit(1)
        feed = update_automation(
            file_location,
            automation_type,
            automation_namespace,
            automation_changelog,
            os.environ.get("REPO_BRANCH"),
            feed,
        )

    # Write back JSON file
    with open("DependencyControl.json", "w", encoding="utf8") as f:
        json.dump(feed, f, indent=4)


def update_automation(location, type, namespace, changelog, branch, feed):
    file_name = os.path.basename(location)
    is_default_branch = branch == os.environ.get("REPO_BRANCH")

    # Calculate filehash
    file_sha1 = hashlib.sha1()

    with open(location, "rb") as f:
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

    with open(location) as f:
        script_text = f.read()

    if type == "macros":
        script_name = extract_property(script_text, "script_name")
        script_description = extract_property(script_text, "script_description")
        script_author = extract_property(script_text, "script_author")
        script_version = extract_property(script_text, "script_version")
        script_namespace = extract_property(script_text, "script_namespace")
    elif type == "modules":
        script_name = extract_property(script_text, "name")
        script_description = extract_property(script_text, "description")
        script_author = extract_property(script_text, "author")
        script_version = extract_property(script_text, "version")
        script_namespace = extract_property(script_text, "moduleName")
    else:
        print("Unknown automation type")
        exit(1)

    if script_namespace != namespace:
        print("Namespace mismatch")
        exit(1)

    current_date = datetime.today().strftime("%Y-%m-%d")

    # Try to find existing automation in feed
    if namespace in feed[type]:
        automation = feed[type][namespace]
        
        if not branch in automation["channels"]:
            print(f"No channel for branch {branch}. Creating new one")
            automation["channels"][branch] = {}
        elif is_default_branch:
            current_version = automation["channels"][branch]["version"]
            if version.parse(script_version) <= version.parse(current_version):
                print("File version did not increase")
                exit(1)

    else:
        print("Automation not present in feed. Adding it.")
        automation = {
            "url": "@{baseUrl}#@{namespace}",
            "fileBaseUrl": f"@{{fileBaseUrl}}/{type}/",
            "channels": {branch: {}},
            "changelog": {},
            "requiredModules": [],
        }
        feed[type][namespace] = automation

    # Update variables
    automation["channels"][branch]["default"] = is_default_branch

    automation["name"] = script_name
    automation["description"] = script_description
    automation["author"] = script_author

    automation["channels"][branch]["version"] = script_version
    automation["channels"][branch]["released"] = current_date
    if type == "modules":
        expanded_path = namespace.replace(".", "/").rsplit("/", 1)[0] + "/"
    else:
        expanded_path = ""

    automation["channels"][branch]["files"] = [
        {
            "name": file_name,
            "url": f"@{{fileBaseUrl}}{expanded_path}@{{fileName}}",
            "sha1": file_hash,
        }
    ]

    if changelog != None:
        automation["changelog"][script_version] = changelog.split("\\n")

    return feed


if __name__ == "__main__":
    main()
