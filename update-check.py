import json
import os
import re
import subprocess
import sys

import requests


is_pull_request = sys.argv[1] == "true"
print(f"is_pull_request={is_pull_request}")


def check_version(directory, new_version):
    print(f"Checking version for {directory}")

    if not new_version:
        print("Failed to get new version. Exiting.")
        exit(1)

    with open(f"{directory}/VERSION", "r") as f:
        old_version = f.read().rstrip()

    print(f"Up-to-date version {new_version}")
    print(f"Current version: {old_version}")

    if old_version != new_version:
        print(f"New release found: {new_version}")

        # bump up to new release
        with open(f"{directory}/VERSION", "w") as f:
            f.write(new_version)

        subprocess.run(
            ["git", "config", "--local", "user.email", "actions@github.com"],
            check=True,
        )
        subprocess.run(
            ["git", "config", "--local", "user.name", "GitHub Actions"],
            check=True,
        )
        subprocess.run(["git", "add", f"{directory}/VERSION"], check=True)
        subprocess.run(
            ["git", "commit", "-m", f"Bump {directory} version to {new_version}"],
            check=True,
        )

        if is_pull_request:
            print("Action triggered by pull request. Do not push.")
        else:
            subprocess.run(["git", "push"], check=True)
    else:
        print(f"Already newest version {old_version}")


# check build version
response = requests.get(
    "https://api.github.com/repos/ProtonMail/proton-bridge/tags",
    headers={"Accept": "application/vnd.github.v3+json"},
    timeout=30,
)
response.raise_for_status()
tags = json.loads(response.content)
version_re = re.compile(r"v\d+\.\d+\.\d+")
releases = [tag["name"][1:] for tag in tags if version_re.match(tag["name"])]
if not releases:
    raise RuntimeError("No matching releases returned from the Proton Bridge tags API")
check_version("build", releases[0])
