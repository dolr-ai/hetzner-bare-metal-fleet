# Retry Failed Hosts Guide

## Overview

All playbooks now include automatic retry logic for connection failures. When a host fails to connect, Ansible will:

1. **Automatically retry** connection attempts (3 times by default with 10-second delays)
2. **Create a retry file** in the `ansible/retry/` directory with the pattern `<playbook-name>.retry`
3. **Allow partial failures** with `max_fail_percentage: 50`, so the workflow doesn't fail completely if some hosts are unreachable

## Automatic Retry Features

### Connection Retries
Each playbook now includes:
- **retry_count**: 3 attempts
- **retry_delay**: 10 seconds between attempts
- **max_fail_percentage**: 50% - allows up to half the hosts to fail without stopping the playbook

### Example from system-update.yml:
```yaml
- name: Wait for system to be ready
  wait_for_connection:
    timeout: 60
    delay: "{{ retry_delay }}"
  retries: "{{ retry_count }}"
  register: connection_result
  until: connection_result is succeeded
```

## Manual Retry Options

### Option 1: Using Ansible's Auto-Generated Retry File

When a playbook fails, Ansible automatically creates a `.retry` file:

```bash
# Retry just the failed hosts from system-update
ansible-playbook ansible/playbooks/system-update.yml \
  --limit @ansible/playbooks/system-update.retry \
  --extra-vars "enable_reboot=false"
```

### Option 2: Using the Dedicated Retry Playbook

Use the `retry-failed-hosts.yml` playbook to retry specific hosts:

```bash
# Retry a specific host
ansible-playbook ansible/playbooks/retry-failed-hosts.yml \
  --limit offchain-agent-1
```

### Option 3: Re-run Original Playbook with Specific Host

```bash
# Retry system update for a specific host
ansible-playbook ansible/playbooks/system-update.yml \
  --limit offchain-agent-1 \
  --extra-vars "enable_reboot=false"
```

### Option 4: Run Full Workflow for Specific Host

Use the original maintenance workflow targeting just the failed host:

```bash
# Local run
./scripts/run-local.sh offchain-agent-1

# Or directly with ansible-playbook
ansible-playbook ansible/playbooks/system-update.yml --limit offchain-agent-1 --extra-vars "enable_reboot=false"
ansible-playbook ansible/playbooks/ssh-security.yml --limit offchain-agent-1
```

## GitHub Actions Integration

### Manually Trigger for Failed Host

1. Go to Actions → Fleet Maintenance
2. Click "Run workflow"
3. In "Target hosts" field, enter the failed hostname (e.g., `offchain-agent-1`)
4. Configure other options as needed
5. Click "Run workflow"

### Identifying Failed Hosts

Check the workflow logs for entries like:
```
PLAY RECAP *********************************************************************
offchain-agent-1           : ok=0    changed=0    unreachable=1    failed=0
```

## Troubleshooting Connection Failures

### Common Causes:
1. **Host is down or rebooting**
   - Wait a few minutes and retry
   
2. **SSH service not responding**
   - Check if the server is accessible: `ping <hostname>`
   - Verify SSH is running: `ssh user@<hostname>`

3. **Network issues**
   - Check your network connection
   - Verify firewall rules

4. **SSH key issues**
   - Ensure SSH keys are properly configured
   - Check `~/.ssh/config` or vault credentials

### Example: Latest Failure
The most recent failure was:
```
fatal: [offchain-agent-1]: UNREACHABLE! => {
  "msg": "Connection reset by 136.243.174.45 port 22"
}
```

**Resolution steps:**
1. Check if host is responding: `ping 136.243.174.45`
2. Try manual SSH: `ssh root@136.243.174.45`
3. If the host is back online, retry:
   ```bash
   # Local
   ./scripts/run-local.sh offchain-agent-1
   
   # Or via GitHub Actions with target_hosts: offchain-agent-1
   ```

## Retry Configuration

### Adjusting Retry Parameters

You can override the default retry settings:

```bash
ansible-playbook ansible/playbooks/system-update.yml \
  --limit offchain-agent-1 \
  --extra-vars "retry_count=5 retry_delay=30"
```

### Available Variables:
- `retry_count`: Number of connection retry attempts (default: 3)
- `retry_delay`: Seconds between retries (default: 10)
- `enable_reboot`: Allow automatic reboots (default: false)

## Best Practices

1. **Investigate before retrying**: Understand why the host failed
2. **Use specific limits**: Target only failed hosts to save time
3. **Check host status**: Verify the host is accessible before retrying
4. **Monitor retry files**: Check `ansible/retry/` for auto-generated retry files
5. **Serial execution**: Playbooks use `serial: 1` to process hosts one at a time, minimizing impact of failures

## Advanced: Custom Retry Logic

To add custom retry logic to a specific task:

```yaml
- name: Your task name
  your_module:
    param: value
  retries: 3
  delay: 10
  register: result
  until: result is succeeded
```
