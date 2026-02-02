# CI Failure Analysis and Retry Implementation Summary

## Issue Analysis

**Latest CI Run Failure:** Run ID 21590120550 (Fleet Maintenance)

**Failed Host:** `offchain-agent-1` (IP: 136.243.174.45)

**Error:**
```
fatal: [offchain-agent-1]: UNREACHABLE! => {
  "msg": "Connection reset by 136.243.174.45 port 22"
}
```

**Root Cause:** SSH connection was reset, likely due to:
- Host temporarily down or rebooting
- Network connectivity issue
- SSH service not responding
- High system load

## Implemented Solutions

### 1. Automatic Retry Logic in All Playbooks

Added to all playbooks (`system-update.yml`, `ssh-security.yml`, `docker-setup.yml`, `beszel-agent-setup.yml`):

```yaml
- name: System Update and Upgrade
  hosts: all
  serial: 1
  gather_facts: true
  max_fail_percentage: 50  # NEW: Allow up to 50% failures
  vars:
    ansible_python_interpreter: /usr/bin/python3
    retry_count: 3           # NEW: Number of retry attempts
    retry_delay: 10          # NEW: Seconds between retries

  tasks:
    - name: Wait for system to be ready
      wait_for_connection:
        timeout: 60
        delay: "{{ retry_delay }}"    # NEW
      retries: "{{ retry_count }}"    # NEW
      register: connection_result     # NEW
      until: connection_result is succeeded  # NEW
```

**Benefits:**
- Automatically retries failed connections 3 times with 10-second delays
- Allows workflow to continue even if some hosts are unreachable
- Prevents single host failure from blocking entire fleet maintenance

### 2. Ansible Retry Files

**Updated `ansible.cfg`:**
```properties
retry_files_enabled = True
retry_files_save_path = ansible/retry
```

**Benefit:** When playbooks fail, Ansible automatically creates `.retry` files listing failed hosts for easy re-execution.

### 3. Dedicated Retry Playbook

**Created:** `ansible/playbooks/retry-failed-hosts.yml`

Purpose: Standalone playbook specifically designed to retry connections to problematic hosts with configurable retry parameters.

Usage:
```bash
ansible-playbook ansible/playbooks/retry-failed-hosts.yml --limit offchain-agent-1
```

### 4. Comprehensive Documentation

**Created:** `RETRY_GUIDE.md` with:
- Complete retry mechanisms explanation
- Multiple retry strategies
- Troubleshooting guide
- GitHub Actions integration
- Best practices

**Updated:** `readme.md` with:
- Quick retry examples
- Link to full retry guide
- Updated playbooks table

### 5. Infrastructure Setup

**Created:** `ansible/retry/README.md`
- Explains retry directory purpose
- Usage examples

**Updated:** `.gitignore`
- Excludes `*.retry` files from version control
- Prevents temporary files from being committed

## How to Retry the Failed Host

### Option 1: Via GitHub Actions (Easiest)
1. Go to Actions → Fleet Maintenance
2. Click "Run workflow"
3. Set `target_hosts` to `offchain-agent-1`
4. Click "Run workflow"

### Option 2: Via Local Script
```bash
./scripts/run-local.sh offchain-agent-1
```

### Option 3: Direct Ansible Command
```bash
# Just system update
ansible-playbook ansible/playbooks/system-update.yml --limit offchain-agent-1

# Or if retry file was generated
ansible-playbook ansible/playbooks/system-update.yml --limit @ansible/retry/system-update.retry
```

## Files Changed

1. **Playbooks (Added retry logic):**
   - `ansible/playbooks/system-update.yml`
   - `ansible/playbooks/ssh-security.yml`
   - `ansible/playbooks/docker-setup.yml`
   - `ansible/playbooks/beszel-agent-setup.yml`

2. **New Files:**
   - `ansible/playbooks/retry-failed-hosts.yml` - Dedicated retry playbook
   - `RETRY_GUIDE.md` - Comprehensive retry documentation
   - `ansible/retry/README.md` - Retry directory documentation
   - `SUMMARY.md` - This file

3. **Configuration:**
   - `ansible.cfg` - Enabled retry files
   - `.gitignore` - Added retry file patterns

4. **Documentation:**
   - `readme.md` - Added retry section

## Key Improvements

### Before
- Single connection failure would fail entire playbook
- No automatic retry mechanism
- Manual intervention required for every failure
- No visibility into which hosts failed

### After
- 3 automatic retry attempts with delays
- Up to 50% of hosts can fail without stopping workflow
- Automatic retry file generation
- Dedicated retry playbook
- Comprehensive documentation
- Easy re-run for failed hosts via GitHub Actions

## Testing Recommendations

1. **Test retry logic:**
   ```bash
   # Temporarily disable a host to test retry behavior
   ansible-playbook ansible/playbooks/retry-failed-hosts.yml --limit offchain-agent-1
   ```

2. **Verify retry file generation:**
   - Run a playbook against an unreachable host
   - Check for `.retry` file in `ansible/retry/`

3. **Test partial failures:**
   - Run against multiple hosts with one unreachable
   - Verify workflow continues for reachable hosts

## Next Steps

1. **Immediate:** Retry `offchain-agent-1` once it's back online
2. **Short-term:** Monitor retry files to identify frequently failing hosts
3. **Long-term:** Consider implementing health checks before maintenance runs

## Configuration Tunables

Override default retry behavior:
```bash
ansible-playbook ansible/playbooks/system-update.yml \
  --extra-vars "retry_count=5 retry_delay=30" \
  --limit offchain-agent-1
```

Available variables:
- `retry_count`: Number of retry attempts (default: 3)
- `retry_delay`: Seconds between retries (default: 10)
- `max_fail_percentage`: Percentage of hosts that can fail (set at play level: 50)
