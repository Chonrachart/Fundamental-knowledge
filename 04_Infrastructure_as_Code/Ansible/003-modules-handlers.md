module
handler
notify
when
loop
block

---

# Common Modules

- **package** / **yum**, **apt**: Install packages; use `state: present` or `latest`.
- **copy**: Copy file from control node; **template**: Copy after Jinja2 render.
- **file**: Create dir, symlink; set permissions.
- **service**: Start, stop, enable; **systemd** for more control.
- **user**, **group**: Manage users and groups.
- **lineinfile**, **blockinfile**: Edit specific lines.
- **command**, **shell**: Run command; **command** no shell; **shell** for pipes/redirects; use modules when possible.
- **get_url**: Download file; **unarchive**: Extract archive.

# Handler

- Task that runs only when notified; typically "restart service" after config change.
- Defined in **handlers** section; notified by **notify: handler name** in task.
- Run at end of play (per host); multiple notify same handler → run once.

```yaml
tasks:
- template:
    src: app.conf.j2
    dest: /etc/app/app.conf
  notify: restart app
handlers:
- name: restart app
  service:
    name: app
    state: restarted
```

# when

- Conditional; task runs only when condition true; Jinja2 expression.
- `when: ansible_os_family == "RedHat"`; `when: not skip_install`.

# loop

- Iterate over list; variable `item` (or **loop_control.label**).
- **loop** with list; or **with_items**, **with_dict** (older style).

```yaml
- user:
    name: "{{ item }}"
    state: present
  loop:
    - alice
    - bob
```

# block

- Group tasks; **rescue** on failure; **always** runs after block (and rescue if any).
- Use for error handling or logical grouping.
