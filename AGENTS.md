# AGENTS.md — Conventions & Guidance for AI Agents

This document is the authoritative reference for AI agents and contributors working in this repository.
It captures hard-won conventions, architectural decisions, and repo-specific constraints that must be
respected to keep the fleet automation consistent, idempotent, and safe.

---

## Repository Overview

This repository manages a fleet of Hetzner bare-metal servers using Ansible.
All servers run Ubuntu 24.04, are reachable as `root` via SSH key, and belong to the `bare_metal`
inventory group.  Two sub-groups exist for lower-risk hosts:

| Group | Purpose |
|---|---|
| `bare_metal` | All 27 bare-metal hosts — primary target for all plays |
| `staging` | Subset; `ssh_security` skips authorized_keys reset here |
| `development` | Subset; `ssh_security` skips authorized_keys reset here |

Monitoring hub: `uptime-monitor-1` runs the Beszel hub at `https://beszel.yral.com`.

---

## Directory Layout

```
ansible/
  ansible.cfg                   # roles_path = ansible/roles (already set)
  inventory/
    hosts.yml                   # single source of truth for hosts and IPs
    group_vars/all/vars.yml     # non-secret shared variables
    group_vars/all/vault.yml    # encrypted vault (ansible-vault AES256)
    group_vars/bare_metal.yml   # connection defaults (ansible_user: root, key path)
    host_vars/<host>/vars.yml   # references vault_* vars from host vault
    host_vars/<host>/vault.yml  # per-host encrypted secrets
  roles/                        # all task logic lives here
  playbooks/                    # thin wrappers and orchestrator playbooks
  files/                        # (legacy) — authoritative files now live inside roles
  .vault_pass                   # gitignored; populated by postCreate.sh placeholder
.devcontainer/
  devcontainer.json
  postCreate.sh                 # idempotent dev-container bootstrap
scripts/
  run-local.sh                  # interactive menu for local operators
```

---

## Core Architecture: Roles + Thin Playbooks

**All task logic lives in roles under `ansible/roles/`.  Playbooks are thin wrappers.**

### Roles

| Role | Purpose |
|---|---|
| `hetzner_rescue` | Activates Hetzner rescue mode via Robot API, reboots, waits for SSH |
| `bare_metal_provision` | Runs installimage in rescue, reboots into OS, sets up btrfs RAID 0 |
| `system_update` | `apt full-upgrade`, autoremove, optional reboot |
| `ssh_security` | Hardens sshd config; resets `authorized_keys` to canonical set |
| `docker` | Idempotent Docker CE install via official upstream repo |
| `beszel_agent` | Upserts `beszel-agent` service in `/root/docker-compose.yml` |
| `beszel_hub` | Pulls latest hub image and restarts the hub service on `uptime-monitor-1` |
| `ssh_key_grant` | Adds a single team member's key — temporary; revoked on next weekly run |

Each role follows the standard Ansible structure:

```
roles/<name>/
  defaults/main.yml   # overridable defaults
  tasks/main.yml      # all task logic
  handlers/main.yml   # only if role needs handlers (currently: ssh_security)
  files/              # static assets copied to remote (currently: ssh_security, beszel_agent)
```

**Roles must be atomic** — a role does exactly one concern.  Do not combine unrelated operations
(e.g., do not mix Docker install with system update in one role).

### Primary Playbooks

Three playbooks cover all intended operations — there are no other playbooks in `ansible/playbooks/`:

| Playbook | Purpose | Key flags |
|---|---|---|
| `provision.yml` | Full idempotent bootstrap of a new host | `skip_rescue_activation=true`, `force_provision=true` |
| `ssh-access.yml` | Grant temporary SSH access to a team member | `team_member_name=<name>` (required) |
| `weekly-update.yml` | Weekly maintenance: update → agent refresh → hub update → key reset | `enable_reboot=true` |

---

## Variable Conventions

### Vault Pattern

- **Group-level secrets** live in `ansible/inventory/group_vars/all/vault.yml` (encrypted).
- **Host-level secrets** live in `ansible/inventory/host_vars/<host>/vault.yml` (encrypted).
- All vault variables are prefixed `vault_*`.
- Plain `vars.yml` files only contain `key: "{{ vault_key }}"` references — never raw secrets.
- The vault password file is `ansible/.vault_pass` (600 permissions, gitignored).

Example pattern:
```yaml
# group_vars/all/vars.yml
beszel_agent_token: "{{ vault_beszel_agent_token }}"

# group_vars/all/vault.yml  (encrypted)
vault_beszel_agent_token: "actual-token-here"
```

### Role Defaults

- Each role keeps its own overridable defaults in `defaults/main.yml`.
- Variables already defined in `group_vars/all/vars.yml` (e.g., `beszel_hub_url`,
  `beszel_listen_port`, `beszel_ssh_key`) are **not** duplicated in role `defaults/main.yml` —
  the group vars take precedence and roles inherit them automatically.
- Role `defaults/main.yml` is for role-private knobs only (paths, retry counts, feature flags).

### Target Override

All playbooks accept an optional `target` variable to scope execution without using `--limit`:

```yaml
hosts: "{{ target | default('all') }}"
```

Standard invocation still uses `--limit`; `target` is an alternative for programmatic callers.

---

## SSH and authorized_keys Management

**Canonical set** (always present on every non-staging/non-development host):

- `github-actions@yral.com` — CI/CD pipeline key
- `saikatdas0790@gmail.com` — admin key

These are stored in `ansible/roles/ssh_security/files/authorized_keys`.

**Team member keys** are defined in `group_vars/all/vars.yml` under `team_members`.
They are added temporarily via the `ssh_key_grant` role and **automatically expelled** the next time
`ssh_security` runs (weekly-update play 4, or manual `weekly-update.yml` run).

> **Never add team member keys to the canonical `authorized_keys` file.**
> Temporary access is the intentional model; canonical access requires adding keys to the file
> in the role's `files/` directory and committing the change.

**`authorized_keys` reset is skipped** for hosts in the `staging` and `development` inventory groups.

---

## Idempotency Requirements

Every role and playbook must be safe to re-run without side effects.

Key patterns used:

| Concern | Pattern |
|---|---|
| Already-provisioned host | Marker file `/root/.provisioned`; fail unless `force_provision=true` |
| Docker already installed | `docker --version` check; all install tasks are `when: docker_check.rc != 0` |
| Beszel agent config | `blockinfile` with named marker; Python cleanup script removes stale blocks first |
| SSH keys | `lineinfile` + grep-based existence check before inserting |
| `authorized_keys` reset | Content diff check; only copies when canonical ≠ existing |
| apt upgrades | `cache_valid_time: 3600`; skips upgrade when `upgradable_packages == 0` |

---

## Execution Patterns

### Serial and failure tolerance

- `system_update` role (and its wrapper): `serial: 1`, `max_fail_percentage: 50` — rolling, one host at a time.
- `ssh_security` role wrapper: `max_fail_percentage: 50` — tolerates up to half failing.
- All other plays run parallel (no `serial`).

### Connection reliability

Every role that touches a remote host via apt/systemd starts with:

```yaml
- name: Wait for system to be ready
  wait_for_connection:
    timeout: 60
    delay: "{{ retry_delay }}"   # default: 10
  retries: "{{ retry_count }}"   # default: 3
  register: connection_result
  until: connection_result is succeeded

- name: Gather facts
  setup:

- name: Check if system is Debian/Ubuntu
  fail:
    msg: "This role is designed for Debian/Ubuntu systems only"
  when: ansible_os_family != "Debian"
```

Roles that only run locally (e.g., `hetzner_rescue`) or only use raw/shell before
`gather_facts` omit this block.

### Become

`become: false` is the default — we SSH directly as root.  Only use `become: true` in the
`ssh_security` play wrapper where legacy usage required it; individual role tasks do not need it.

---

## Beszel Monitoring

- **Agent token**: `beszel_agent_token` — defined per-host in `host_vars/*/vars.yml`
  (references `vault_beszel_agent_token`).  A universal token also exists in
  `group_vars/all/vars.yml` as a fallback.
- **Hub URL**: `beszel_hub_url` — `https://beszel.yral.com` (defined in `group_vars/all/vars.yml`).
- **Hub host**: `uptime-monitor-1` — the only host where `beszel_hub` role runs.
- **Hub service name**: default `beszel` (override via `beszel_hub_service_name`).
- The agent compose block uses `blockinfile` with marker `ANSIBLE MANAGED BLOCK - BESZEL AGENT`
  and the cleanup script `roles/beszel_agent/files/cleanup_beszel.py` removes stale entries.

---

## Adding a New Host

1. Add host entry to `ansible/inventory/hosts.yml` under `bare_metal`.
2. Create `ansible/inventory/host_vars/<hostname>/vars.yml`:
   ```yaml
   ---
   beszel_agent_token: "{{ vault_beszel_agent_token }}"
   ```
3. Create and encrypt `ansible/inventory/host_vars/<hostname>/vault.yml`:
   ```bash
   ansible-vault create ansible/inventory/host_vars/<hostname>/vault.yml
   # add: vault_beszel_agent_token: "<token>"
   ```
4. Run provisioning:
   ```bash
   ansible-playbook ansible/playbooks/provision.yml --limit <hostname>
   ```

---

## Adding a Team Member

1. Add entry to `team_members` dict in `ansible/inventory/group_vars/all/vars.yml`:
   ```yaml
   team_members:
     newperson:
       email: "newperson@gobazzinga.io"
       ssh_key: "ssh-ed25519 AAAA... newperson@gobazzinga.io"
   ```
2. Grant temporary access:
   ```bash
   ansible-playbook ansible/playbooks/ssh-access.yml \
     --limit <hostname|group> -e team_member_name=newperson
   ```
3. Access is automatically revoked on the next `weekly-update.yml` run.

---

## Dev Container Setup

The dev container (`devcontainer.json` + `postCreate.sh`) installs:

- Ansible (via devcontainer feature `ghcr.io/devcontainers-extra/features/ansible:2`)
- GitHub CLI (via devcontainer feature)
- Ansible runtime libraries `passlib`, `jmespath`, `netaddr` injected into Ansible's pipx
  virtualenv via the feature's `injections` option — runs at image build time as root, no PEP 668 issues
- `ansible-lint` via `pipx` in `postCreate.sh` (isolated env, also no PEP 668 issues)
- Ansible Galaxy collections (from `ansible/requirements.yml` when present)

`postCreate.sh` is idempotent — re-running it is safe.

After container creation, replace the vault password placeholder:
```bash
echo 'real-vault-password' > ansible/.vault_pass
chmod 600 ansible/.vault_pass
```

---

## Naming Conventions

| Item | Convention | Example |
|---|---|---|
| Roles | `snake_case` | `beszel_agent`, `ssh_security` |
| Playbooks | `kebab-case.yml` | `weekly-update.yml`, `ssh-access.yml` |
| Variables | `snake_case` | `beszel_agent_token`, `enable_reboot` |
| Vault vars | `vault_` prefix | `vault_beszel_agent_token` |
| Host names | `kebab-case` | `clickhouse-keeper-1`, `uptime-monitor-1` |
| Role file assets | `snake_case` or `kebab-case` matching their purpose | `cleanup_beszel.py`, `authorized_keys` |

---

## What NOT to Do

- **Do not put task logic in playbooks.** Playbooks call roles; roles contain tasks.
- **Do not duplicate group_vars variables in role defaults.** Use `defaults/main.yml` only for
  role-local overrides.
- **Do not add team members to the canonical `authorized_keys` file** unless they are permanent
  service accounts.
- **Do not run `provision.yml` without `--limit`** unless intentionally reprovisioning the whole
  fleet (destructive).
- **Do not remove `serial: 1` from system update plays** — rolling updates protect the fleet from
  simultaneous reboots.
- **Do not commit `ansible/.vault_pass`** — it is gitignored by design.
- **Do not inline task logic in `when:` conditions that belong in role `defaults/main.yml`** —
  keep booleans in defaults, reference them in tasks.
