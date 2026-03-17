# Loops, Conditions, and Blocks

- `loop` repeats a single task over a list — avoids copy-pasting identical tasks.
- `when` skips or runs a task based on a Jinja2 boolean condition.
- `block` groups tasks so shared options (become, when, tags) apply to all at once, and errors can be caught.


# Mental Model

```text
Task execution per host:

  evaluate when:
    → false: SKIPPED
    → true: proceed

  evaluate loop (if present):
    → iterate: run task once per item
    → no loop:  run task once

  evaluate block/rescue/always (if present):
    → block fails: run rescue
    → always:      run regardless
```


# when (Conditions)

```yaml
# fact-based condition
- name: Install on Debian only
  ansible.builtin.package:
    name: nginx
    state: present
  when: ansible_os_family == "Debian"

# variable-based condition
- name: Deploy only in production
  ansible.builtin.template:
    src: prod.conf.j2
    dest: /etc/app/app.conf
  when: app_env == "production"

# register result condition
- name: Check if file exists
  ansible.builtin.stat:
    path: /opt/app/config.yml
  register: cfg_stat

- name: Run setup only if config missing
  ansible.builtin.command: /opt/app/setup.sh
  when: not cfg_stat.stat.exists

# multiple conditions (AND)
- name: Run when both true
  ansible.builtin.debug:
    msg: "ok"
  when:
    - app_env == "production"
    - ansible_os_family == "RedHat"
```

- Multiple `when` items in a list = **AND** (all must be true).
- Use `or` inside a single string for OR: `when: x == "a" or x == "b"`.


# loop

```yaml
# simple list
- name: Create users
  ansible.builtin.user:
    name: "{{ item }}"
    state: present
  loop:
    - alice
    - bob
    - carol

# list of dicts
- name: Create directories with permissions
  ansible.builtin.file:
    path: "{{ item.path }}"
    mode: "{{ item.mode }}"
    state: directory
  loop:
    - { path: /opt/app, mode: "0755" }
    - { path: /opt/app/logs, mode: "0750" }
    - { path: /opt/app/tmp, mode: "0700" }
```

### loop_control

```yaml
- name: Deploy services
  ansible.builtin.template:
    src: "{{ item.name }}.conf.j2"
    dest: "/etc/{{ item.name }}/config.conf"
  loop:
    - { name: nginx, port: 80 }
    - { name: app, port: 8080 }
  loop_control:
    label: "{{ item.name }}"    # cleaner output (shows name instead of full dict)
    pause: 1                    # seconds to wait between iterations
```

- Default loop variable is `item`; rename with `loop_control.loop_var` to avoid conflicts in nested includes.


# block / rescue / always

```yaml
- name: Deploy application
  block:
    - name: Pull image
      ansible.builtin.command: docker pull myapp:{{ app_version }}

    - name: Start container
      ansible.builtin.command: docker run -d myapp:{{ app_version }}

  rescue:
    - name: Notify on failure
      ansible.builtin.debug:
        msg: "Deployment failed — rolling back"

    - name: Restart previous version
      ansible.builtin.command: docker start myapp_prev

  always:
    - name: Clean up temp files
      ansible.builtin.file:
        path: /tmp/deploy_lock
        state: absent
```

- `block`: tasks to attempt.
- `rescue`: runs only when a task in `block` fails (like `catch`).
- `always`: runs regardless of block/rescue outcome (like `finally`).
- `when` on a block applies to all tasks inside it.


# changed_when and failed_when

```yaml
# command is read-only; never mark as changed
- name: Get app status
  ansible.builtin.command: /opt/app/status.sh
  register: app_status
  changed_when: false

# treat specific exit codes as non-fatal
- name: Run migration script
  ansible.builtin.command: /opt/app/migrate.sh
  register: migrate_result
  failed_when: migrate_result.rc not in [0, 2]   # 2 = "already migrated"
```


# retries / until

```yaml
- name: Wait for service to be healthy
  ansible.builtin.uri:
    url: http://localhost:8080/health
    status_code: 200
  register: health
  retries: 12        # try up to 12 times
  delay: 5           # wait 5 seconds between retries
  until: health.status == 200
```

---

# Practical Command Set (Core)

```bash
# run only tasks matching a condition (use tags instead — when is runtime)
ansible-playbook site.yml --tags deploy

# check what tasks would run (dry-run)
ansible-playbook site.yml --check --diff

# debug loop output: add to playbook
- ansible.builtin.debug:
    msg: "Processing {{ item }}"
  loop: "{{ my_list }}"
```


# Troubleshooting Guide

### Task unexpectedly skipped

1. Add a debug task before it: `debug: var=<condition_variable>`.
2. Check type (string `"false"` vs bool `false` -- use `| bool` filter).
3. Check the fact value: `ansible web1 -m setup -a "filter=ansible_os_family"`.
4. Verify the list variable is defined and non-empty before the loop.
5. Check for a `loop_var` conflict if using nested `include_tasks` with loop.


# Quick Facts (Revision)

- Multiple `when` list items = **AND**; use `or` keyword inside a string for OR.
- Default loop variable is `item`; rename with `loop_control.loop_var` for nested loops.
- `block` + `rescue` is the correct pattern for error recovery — not `ignore_errors`.
- `changed_when: false` is the right call for any read-only command/shell task.
- `until` retries until condition is true; combine with `retries` and `delay`.
- `when` evaluates Jinja2 — wrap string comparisons: `when: ansible_os_family == "Debian"`.
- A `when` on a `block` applies to every task inside the block.
