when
loop
block
changed_when
failed_when
until

---

# when

- `when` controls whether a task runs.
- Condition is a Jinja2 expression.

```yaml
- name: Install only on Debian
  package:
    name: nginx
    state: present
  when: ansible_os_family == "Debian"
```

# loop

- `loop` repeats a task for each item.
- Default item variable is `item`.

```yaml
- name: Create users
  user:
    name: "{{ item }}"
    state: present
  loop:
    - alice
    - bob
```

### loop_control

```yaml
- name: Example
  debug:
    msg: "name={{ item.name }} port={{ item.port }}"
  loop:
    - { name: app1, port: 8080 }
    - { name: app2, port: 9090 }
  loop_control:
    label: "{{ item.name }}"
```

# block / rescue / always

- `block` groups tasks.
- `rescue` runs when a task in block fails.
- `always` runs no matter what.

```yaml
- block:
  - name: Do something
    command: /opt/app/do
  rescue:
  - debug:
      msg: "failed, do cleanup"
  always:
  - debug:
      msg: "always run"
```

# changed_when and failed_when

- Override Ansible detection when module output is not ideal.
- Use carefully; wrong logic can hide real changes or failures.

```yaml
- name: Run command
  command: /opt/app/check
  register: r
  changed_when: false
  failed_when: r.rc not in [0, 2]
```

# retries / until

```yaml
- name: Wait service
  uri:
    url: http://localhost:8080/health
    status_code: 200
  register: health
  retries: 10
  delay: 3
  until: health.status == 200
```
