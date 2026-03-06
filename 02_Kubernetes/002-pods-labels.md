pod
label
selector
probe
lifecycle
resource

---

# Pod Spec

- **containers**: List of containers; required; name, image, ports, env, resources, etc.
- **initContainers**: Run to completion before main containers start; order matters.
- **restartPolicy**: Always, OnFailure, Never; default Always.
- **nodeSelector**, **affinity**: Constrain which nodes the pod can run on.

# Labels and Selectors

- **Labels**: Key-value pairs on objects (pods, etc.); e.g. `app=web`, `env=prod`.
- **Selectors**: Match labels; used by Deployment (selector), Service (selector), and when listing: `kubectl get pods -l app=web`.
- Label selectors: equality (`=`, `!=`) or set-based (`in`, `notin`, `exists`).

```yaml
metadata:
  labels:
    app: myapp
    tier: frontend
spec:
  selector:
    matchLabels:
      app: myapp
```

# Probes

- **livenessProbe**: Is the container alive? If fail, kubelet restarts container.
- **readinessProbe**: Is the container ready for traffic? If fail, pod removed from Service endpoints.
- Types: httpGet, tcpSocket, exec; initialDelaySeconds, periodSeconds, timeoutSeconds.

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
readinessProbe:
  tcpSocket:
    port: 8080
  periodSeconds: 3
```

# Lifecycle

- **postStart**: Hook after container starts (run alongside main process).
- **preStop**: Hook before container is terminated; use for graceful shutdown.
- **terminationGracePeriodSeconds**: Time to wait after SIGTERM before SIGKILL.

# Resources

- **requests**: Guaranteed; scheduler uses this; e.g. `cpu: "100m"`, `memory: "128Mi"`.
- **limits**: Max; container can be throttled (CPU) or OOMKilled (memory) if exceeded.
- Always set requests (and limits where needed) for production.

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```
