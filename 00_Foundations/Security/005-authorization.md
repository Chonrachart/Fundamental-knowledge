RBAC
ABAC
ACL
policy

---

# Authorization

- Determines what an authenticated user can do: "What are you allowed to access?"
- Runs after authentication; uses identity and context to enforce permissions.

# RBAC (Role-Based Access Control)

- Permissions are assigned to roles; users get roles.
- Example: "Admin" role can delete users; "Viewer" role can only read.
- Simple to manage; scales well for many users with similar needs.

### Example

```
Role: Developer
  - Read repo
  - Push to branch
  - Create PR

Role: Admin
  - All Developer permissions
  - Delete repo
  - Manage members
```

# ABAC (Attribute-Based Access Control)

- Decisions based on attributes: user, resource, environment.
- More flexible than RBAC; can express "allow if user.department == resource.owner".
- Used in complex policies (e.g. AWS IAM policies, XACML).

### Attributes

- User: department, clearance, location.
- Resource: owner, classification, project.
- Action: read, write, delete.
- Environment: time, IP, device.

# ACL (Access Control List)

- List of permissions per resource.
- Each resource has a list: who can do what.
- Example: file permissions (user, group, others; read, write, execute).

### Example (File)

```
file.txt: user=rw, group=r, others=
```

### Network ACL

- Firewall rules: allow/deny by IP, port, protocol.

# Policy

- Policy is the set of rules that define allowed and denied actions.
- Can be expressed in RBAC (roles), ABAC (attributes), or ACL (per-resource).

### Policy Engine

- Evaluates requests against policies; returns allow or deny.
- Examples: OPA (Open Policy Agent), AWS IAM policy evaluator.

# RBAC vs ABAC vs ACL

| Model | Basis              | Use case                    |
| :---- | :----------------- | :-------------------------- |
| RBAC  | Role               | Simple org hierarchy        |
| ABAC  | Attributes         | Complex, dynamic policies   |
| ACL   | Per resource       | Files, network, objects     |