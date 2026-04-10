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


def github_headers():
    headers = {
        "Accept": "application/vnd.github.v3+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def latest_full_release_version():
    response = requests.get(
        "https://api.github.com/repos/ProtonMail/proton-bridge/releases",
        headers=github_headers(),
        params={"per_page": 10},
        timeout=30,
    )
    response.raise_for_status()

    version_re = re.compile(r"v\d+\.\d+\.\d+")
    releases = [
        release["tag_name"][1:]
        for release in response.json()
        if not release.get("draft")
        and not release.get("prerelease")
        and version_re.fullmatch(release.get("tag_name", ""))
    ]
    if not releases:
        raise RuntimeError(
            "No matching full releases returned from the Proton Bridge releases API"
        )

    return releases[0]


# check build version
check_version("build", latest_full_release_version())
