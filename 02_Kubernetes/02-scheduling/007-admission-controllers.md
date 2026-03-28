# Admission Controllers

### Overview

- **Why it exists** — Authentication proves who you are; authorization (RBAC) proves what you're allowed to do. But neither enforces organizational policy on the content of requests: "all pods must have resource limits," "images must come from approved registries," "namespaces being deleted must not have live resources." Admission controllers fill this gap — they intercept requests after auth and can modify or reject them before any object is stored.
- **What it is** — Admission controllers are plugins that run in the API server and intercept write requests (create, update, delete — not read). They run in two phases: mutating first (can modify the request), then validating (can only allow or reject). Built-in controllers handle common defaults and policy; custom logic runs via webhook admission controllers.
- **One-liner** — Admission controllers are the last line of defense in the API request pipeline — they enforce policy and inject defaults after authn/authz, before objects are written to etcd.

### Architecture (ASCII diagram)

```text
kubectl apply / API client
        │
        ▼
  [1] Authentication       ← Who are you? (certs, tokens)
        │
        ▼
  [2] Authorization (RBAC) ← Are you allowed to do this?
        │
        ▼
  [3] Mutating Admission Controllers    ← Can modify the request object
        │   (run in order; each sees the output of the previous)
        │   Built-in: DefaultStorageClass, LimitRanger, MutatingAdmissionWebhook
        ▼
  [4] Object schema validation          ← Is the object valid?
        │
        ▼
  [5] Validating Admission Controllers  ← Can only allow or reject
        │   Built-in: NamespaceLifecycle, ResourceQuota, ValidatingAdmissionWebhook
        ▼
  [6] Write to etcd                     ← Object is persisted
```

### Mental Model

Think of the API server pipeline as a border crossing:
1. **Authentication** = show your passport (who are you?)
2. **Authorization** = visa check (are you allowed to enter?)
3. **Mutating admission** = customs agent who opens your bag and adds required paperwork
4. **Validating admission** = security scanner that rejects prohibited items
5. **etcd write** = you're allowed through

The critical property: **mutating runs before validating**. This means a mutating controller can inject defaults (e.g. `defaultStorageClass`) and the validating controller then checks the final, mutated object.

### Core Building Blocks

### Mutating vs Validating admission

**Why the distinction matters** — Separating mutation from validation prevents circular dependency: if validation ran before mutation, a request could be rejected for missing a default that mutation would have added.
**What they are:**
- **Mutating admission controllers** can read AND modify the request object. They run first. Used for injecting defaults, adding sidecar containers, normalizing fields.
- **Validating admission controllers** can only read the request and return allow/deny. They run second (after mutation). Used for policy enforcement.
- **One-liner** — Mutating controllers modify objects first; validating controllers approve or reject the final result.

| Aspect | Mutating | Validating |
|--------|----------|------------|
| Can modify object? | Yes | No |
| Run order | First | Second (after mutation) |
| Purpose | Inject defaults, add labels/annotations, sidecars | Enforce policy, reject invalid objects |
| Webhook type | `MutatingAdmissionWebhook` | `ValidatingAdmissionWebhook` |
| Example | DefaultStorageClass, LimitRanger | ResourceQuota, NamespaceLifecycle |

### Built-in admission controllers

| Controller | Type | Purpose |
|------------|------|---------|
| `NamespaceLifecycle` | Validating | Rejects creation of objects in terminating namespaces; prevents deletion of `default`, `kube-system`, `kube-public` |
| `NamespaceExists` | Validating | Rejects objects in non-existent namespaces (superseded by NamespaceLifecycle in recent versions) |
| `LimitRanger` | Mutating + Validating | Injects default resource requests/limits from LimitRange objects; rejects pods exceeding limits |
| `ResourceQuota` | Validating | Rejects objects that would cause a namespace to exceed its ResourceQuota |
| `DefaultStorageClass` | Mutating | Injects the default StorageClass into PVCs that do not specify one |
| `ServiceAccount` | Mutating | Automatically mounts the default service account token into pods |
| `PodSecurity` | Validating | Enforces Pod Security Standards (restricted/baseline/privileged) per namespace |
| `MutatingAdmissionWebhook` | Mutating | Invokes external webhooks for custom mutation logic |
| `ValidatingAdmissionWebhook` | Validating | Invokes external webhooks for custom validation logic |
| `NodeRestriction` | Validating | Restricts what kubelets can modify (only their own node/pods) |
| `AlwaysPullImages` | Mutating | Forces `imagePullPolicy: Always` on every pod (security: prevents using cached images) |

### MutatingAdmissionWebhook and ValidatingAdmissionWebhook

**Why they exist** — Built-in controllers cover common cases, but organizations need custom policy: "all pods must have an `owner` label," "no `latest` image tags," "inject an Istio sidecar." Webhooks make admission extensible without forking the API server.
**What they are** — A webhook admission controller calls an external HTTPS server (the webhook) and passes the request object. The webhook returns `allowed: true/false` (and optionally a JSON Patch for mutating). Kubernetes provides `MutatingWebhookConfiguration` and `ValidatingWebhookConfiguration` resources to register webhooks.
- **One-liner** — Webhook admission controllers call external HTTPS services for custom mutation/validation — making admission extensible without modifying the API server.

```yaml
# Example ValidatingWebhookConfiguration
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: policy-webhook
webhooks:
- name: validate-pods.example.com
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE", "UPDATE"]
    resources: ["pods"]
  clientConfig:
    service:
      name: policy-webhook-svc
      namespace: policy-system
      path: /validate
    caBundle: <base64-encoded-CA>
  admissionReviewVersions: ["v1"]
  sideEffects: None
  failurePolicy: Fail    # Fail = reject if webhook is unreachable; Ignore = allow
```

### Checking which admission plugins are enabled

```bash
# Check enabled plugins via kube-apiserver help output
kubectl exec -n kube-system kube-apiserver-<node> -- \
  kube-apiserver -h | grep -A 1 "enable-admission-plugins"

# View the current API server flags (static pod manifest)
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep admission

# Check API server process flags directly
kubectl get pod kube-apiserver-controlplane -n kube-system -o yaml | grep admission

# On the control-plane node
ps aux | grep kube-apiserver | grep -o 'enable-admission-plugins=[^ ]*'
```

### Adding or removing admission plugins

Admission plugins are configured via `--enable-admission-plugins` and `--disable-admission-plugins` flags on the kube-apiserver. On kubeadm clusters, edit the static pod manifest:

```bash
# Edit the kube-apiserver static pod manifest
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# Find the command section and add/modify:
# - --enable-admission-plugins=NodeRestriction,ResourceQuota,PodSecurity
# - --disable-admission-plugins=AlwaysPullImages
# kubelet will detect the change and restart kube-apiserver automatically
```

### Troubleshooting

### Request rejected with "admission webhook ... denied the request"
1. Identify which webhook fired: the error message includes the webhook name.
2. Check webhook configuration: `kubectl get validatingwebhookconfigurations` or `kubectl get mutatingwebhookconfigurations`.
3. Check webhook pod logs: `kubectl logs -n <webhook-namespace> <webhook-pod>`.
4. If the webhook service is down and `failurePolicy: Fail`, all requests to matching resources are blocked.

### Webhook is unreachable and blocking all creates (failurePolicy: Fail)
1. Quickly check webhook pod status: `kubectl get pods -n <webhook-namespace>`.
2. Temporary fix: change `failurePolicy` to `Ignore` or delete the webhook configuration to unblock.
3. Fix the webhook deployment, then restore `failurePolicy: Fail`.

### Pod created without resource limits despite LimitRange existing
1. Check LimitRange: `kubectl get limitrange -n <namespace> -o yaml`.
2. LimitRange only applies when no limits are set; if a pod explicitly sets limits, LimitRange defaults are not injected.
3. Check if the pod was created before the LimitRange existed — existing pods are not retroactively updated.

### "unable to validate against any security policy" (PodSecurity)
1. Check the namespace's pod security label: `kubectl get namespace <ns> --show-labels | grep pod-security`.
2. The pod spec violates the enforced policy (e.g. `restricted` policy forbids `privileged: true`).
3. Either fix the pod spec to comply or change the namespace policy label.
