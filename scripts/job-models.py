"""Configure persisted OpenClaw agent-turn routes through the production CLI."""

import json
import os
import shlex
import subprocess
import sys


def main():
    primary = os.getenv("MODEL", "")
    fallback = os.getenv("FALLBACK", "")
    profile_override = os.getenv("PROFILE")
    job_id = os.getenv("JOB_ID")
    apply = os.getenv("APPLY", "0")
    if apply not in ("0", "1"):
        sys.exit("APPLY must be 0 (preview) or 1 (write).")
    if not all("/" in ref and "@" not in ref for ref in (primary, fallback)):
        sys.exit("Set MODEL and FALLBACK to provider/model IDs; use PROFILE for the account.")
    if primary == fallback:
        sys.exit("Choose distinct primary and fallback models.")

    ssh = ["ssh", "-n", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10"]
    if os.getenv("SSH_KEY"):
        ssh.extend(["-i", os.environ["SSH_KEY"]])
    ssh.append("openclaw@" + sys.argv[1])

    def cli(*args):
        cmd = "cd ~/openclaw && " + shlex.join(
            ["docker", "compose", "exec", "-T", "openclaw-gateway", "openclaw", *args]
        )
        result = subprocess.run([*ssh, cmd], stdout=subprocess.PIPE, text=True)
        if result.returncode:
            sys.exit(f"OpenClaw {args[0]} {args[1]} failed. Retry to resume.")
        return json.loads(result.stdout)

    models = cli("models", "list", "--json")
    available = {m["key"] for m in models["models"] if m.get("available")}
    for ref in (primary, fallback):
        if ref not in available:
            sys.exit(f"Model unavailable in the gateway catalog: {ref}")

    listing = cli("cron", "list", "--all", "--json")
    if len(listing["jobs"]) != listing.get("total", len(listing["jobs"])):
        sys.exit("Incomplete job inventory; refusing a partial update.")
    jobs = [j for j in listing["jobs"] if j["payload"]["kind"] == "agentTurn"
            and (not job_id or j["id"] == job_id)]
    if not jobs:
        sys.exit("No matching model-backed job.")
    plan = []
    for job in jobs:
        current = job["payload"]
        old_model, _, old_profile = (current.get("model") or "").partition("@")
        profile = profile_override or old_profile
        if not profile or (not profile_override and
                           old_model.partition("/")[0] != primary.partition("/")[0]):
            sys.exit(f"Set PROFILE for {job['name']} when establishing or changing providers.")
        target = primary + "@" + profile
        if (current.get("model") == target and current.get("fallbacks") == [fallback]
                and current.get("thinking") is None):
            continue
        plan.append((job, target))
        print(f"{job['name']} [{job['id']}]: {old_model or 'inherited'} -> {primary}, fallback {fallback}")
    print(f"{len(jobs)} jobs checked; {len(plan)} changes.", flush=True)
    if apply == "0":
        print("Preview only. Use APPLY=1 to write.")
        return
    for job, target in plan:
        updated = cli("cron", "edit", job["id"], "--model", target, "--fallbacks",
                      fallback, "--clear-thinking")
        payload = updated["payload"]
        if (payload.get("model") != target or payload.get("fallbacks") != [fallback]
                or payload.get("thinking") is not None):
            sys.exit(f"Unexpected saved settings for {job['name']}.")
        print(f"Verified {job['name']}", flush=True)


if __name__ == "__main__":
    main()
