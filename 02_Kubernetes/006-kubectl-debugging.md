kubectl
get
describe
logs
exec
debug
events
port-forward

---

# kubectl Basics

- **kubectl** talks to the cluster API server; uses **kubeconfig** (default ~/.kube/config) for cluster, user, context.
- **kubectl config get-contexts**: List contexts; **kubectl config use-context name**: Switch context.
- Most commands are **namespaced**; use **-n namespace** or **--all-namespaces** (-A).

# get — List Resources

- **kubectl get pods**: List pods in current namespace; **-o wide** adds node, IP; **-o yaml** full spec.
- **kubectl get pods -l app=web**: Filter by label selector.
- **kubectl get pods -w**: Watch for changes.
- **kubectl get deployment,svc,pods**: Multiple resource types; **kubectl get all** (common resources).
- **-o jsonpath**, **-o custom-columns**: Custom output.

```bash
kubectl get pods -n production
kubectl get pods --sort-by=.metadata.creationTimestamp
```

# describe — Detailed Info and Events

- **kubectl describe pod <name>**: Shows spec, status, events; **why** a pod is Pending, CrashLoopBackOff, etc.
- **kubectl describe node <name>**: Node capacity, allocatable, conditions, pods.
- **Events** at bottom: scheduler decisions, pull errors, probe failures, OOMKilled.

# logs — Container Logs

- **kubectl logs <pod>**: Logs from first container; **-c container_name** for multi-container pod.
- **kubectl logs -f**: Follow (like tail -f).
- **kubectl logs --previous**: Logs from previous container instance (after crash/restart).
- **kubectl logs deployment/myapp**: Logs from one pod of deployment (convenience).

# exec — Run Command in Container

- **kubectl exec -it <pod> -- sh** (or /bin/bash): Interactive shell; **--** separates kubectl args from command.
- **kubectl exec <pod> -- env**: Run non-interactive command.
- **-c container_name** when pod has multiple containers.
- Use for debug; avoid in production if not needed; prefer ephemeral debug containers (debug profile).

# port-forward — Access Service or Pod Locally

- **kubectl port-forward pod/<name> 8080:80**: Local 8080 → pod port 80; access via localhost:8080.
- **kubectl port-forward svc/<name> 8080:80**: Forward to service.
- **kubectl port-forward deployment/myapp 8080:80**: Picks a pod of deployment.
- Useful for local testing; not for production traffic.

# Debugging Workflow

1. **kubectl get pods**: Is pod Running? Pending? CrashLoopBackOff?
2. **kubectl describe pod**: Events, conditions, image pull status, resource limits.
3. **kubectl logs**: Application errors; **--previous** if restarted.
4. **kubectl exec**: Inspect files, run commands, check connectivity (e.g. curl from pod).
5. **kubectl get events -n ns**: Cluster events; often duplicates describe but for whole namespace.

# Common Issues (Quick Checks)

- **Pending**: Insufficient CPU/memory, node selector/affinity, PVC not bound, image pull (describe for reason).
- **ImagePullBackOff**: Wrong image name, private image without imagePullSecret, network.
- **CrashLoopBackOff**: App exits; check logs and **restartCount**; often config or dependency.
- **NotReady (node)**: Kubelet problem, network, disk pressure; describe node.
