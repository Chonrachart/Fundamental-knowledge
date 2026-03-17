# Authorization

- Determines what an authenticated user can do: answers "What are you allowed to access?"
- Runs after authentication; uses identity and context to evaluate permissions against policies
- Enforced by comparing a request (subject + action + resource) against rules, roles, or attributes

# Architecture

```text
+---------+    request     +----------------+    query     +-----------+
| Subject | ------------> | Policy         | ----------> | Policy    |
| (user / |               | Enforcement    |             | Store     |
|  app)   | <------------ | Point (PEP)    | <---------- | (rules,  |
+---------+  allow/deny   +----------------+   decision   |  roles)  |
                                 |                        +-----------+
                                 v
                          +-------------+
                          | Policy      |
                          | Decision    |
                          | Point (PDP) |
                          | (OPA, IAM)  |
                          +-------------+
```

# Mental Model

```text
1. Authenticated subject sends request (action + resource)
2. Enforcement point intercepts the request
3. Decision point evaluates request against stored policies
4. Result: allow or deny
```

Example -- RBAC check in a web app:

```text
User "alice" (role: Developer) -> POST /repos/main/delete
Policy lookup: Developer role has [read_repo, push_branch, create_pr]
Result: DENY (delete_repo requires Admin role)
```

# Core Building Blocks

### RBAC (Role-Based Access Control)

- Permissions are assigned to roles; users are assigned roles
- Example: "Admin" role can delete users; "Viewer" role can only read
- Simple to manage; scales well for many users with similar needs

```text
Role: Developer
  - Read repo
  - Push to branch
  - Create PR

Role: Admin
  - All Developer permissions
  - Delete repo
  - Manage members
```

Related notes: [authentication](./004-authentication.md)

### ABAC (Attribute-Based Access Control)

- Decisions based on attributes of user, resource, action, and environment
- More flexible than RBAC; can express rules like "allow if user.department == resource.owner"
- Used in complex policies (e.g. AWS IAM policies, XACML)

**Attribute categories:**

- **User**: department, clearance, location
- **Resource**: owner, classification, project
- **Action**: read, write, delete
- **Environment**: time of day, source IP, device type

Related notes: [authentication](./004-authentication.md)

### ACL (Access Control List)

- List of permissions attached per resource
- Each entry specifies a subject and its allowed operations
- Common in file systems and network devices

**File ACL example:**

```text
file.txt: user=rw, group=r, others=
```

**Network ACL:**

- Firewall rules: allow/deny traffic by IP, port, protocol
- Evaluated in order; first match wins (in most implementations)

Related notes: [secrets-management](./006-secrets-management.md)

### Policy and Policy Engines

- Policy is the set of rules defining allowed and denied actions
- Can be expressed as RBAC roles, ABAC attribute rules, or per-resource ACLs
- Policy engine evaluates requests against policies; returns allow or deny
- Examples: OPA (Open Policy Agent), AWS IAM policy evaluator, Kubernetes RBAC

Related notes: [authentication](./004-authentication.md), [secrets-management](./006-secrets-management.md)

### RBAC vs ABAC vs ACL

| Model | Basis        | Best for                    |
| :---- | :----------- | :-------------------------- |
| RBAC  | Role         | Simple org hierarchy        |
| ABAC  | Attributes   | Complex, dynamic policies   |
| ACL   | Per resource | Files, network, objects     |

---

# Troubleshooting Guide

```text
Access denied
  |-> User authenticated? -> check authn first (see 004-authentication)
  |-> Correct role assigned? -> verify role bindings / group membership
  |-> Policy exists? -> check policy store (IAM, OPA, RBAC rules)
  |-> Policy too restrictive? -> review deny rules / attribute conditions
  |-> Cached permissions? -> clear session / re-authenticate
  |-> Network ACL? -> check firewall rules, security groups, NACLs
```

# Quick Facts (Revision)

- Authorization answers "what can you do?" -- always runs after authentication
- RBAC: users -> roles -> permissions; simple and widely used
- ABAC: decisions based on attributes (user, resource, action, environment); most flexible
- ACL: per-resource permission list; used in file systems and network firewalls
- Policy engine (OPA, IAM) evaluates requests and returns allow/deny decisions
- RBAC scales well for uniform access patterns; ABAC handles complex, context-aware rules
- Principle of least privilege: grant only the minimum permissions required
- Always log authorization decisions for audit trails
