# Pod and Service Networking

## Overview
**Why it exists** — Pods are ephemeral; their IPs change on restart. Services provide a stable virtual IP and DNS name so consumers are decoupled from individual pod lifecycles.
**What it is** — A networking layer built on top of the pod IP model. A Service gets a ClusterIP (virtual IP) that never changes; kube-proxy translates that VIP into real pod IPs using iptables or IPVS rules on every node.
**One-liner** — Services are stable virtual IPs backed by iptables/IPVS rules that load-balance to real pod IPs.

## Architecture (ASCII)

```text
Kubernetes Networking Model Requirements:
  1. Every pod gets a unique cluster-wide IP
  2. Pods can reach each other without NAT
  3. Nodes can reach all pods without NAT
  4. Pod's own IP is the same inside and outside the pod

Service (ClusterIP) Packet Flow:

Pod A (10.244.1.5)
  │
  │  curl 10.96.0.10:80   ← ClusterIP (virtual, no interface)
  ▼
iptables PREROUTING (on Pod A's node)
  │
  │  DNAT rule: 10.96.0.10:80 → one of the endpoint IPs
  ▼
Selected Endpoint: 10.244.2.7:8080   ← actual pod IP + port
  │
  ▼
Packet routed to Pod B's node via CNI
  │
  ▼
Pod B (10.244.2.7) receives packet on port 8080
```

## Mental Model

ClusterIP is a **virtual IP that exists nowhere as an interface**. No pod and no node owns it. It only exists as an iptables DNAT rule on every node. When traffic hits the ClusterIP, iptables intercepts it in the PREROUTING chain and rewrites the destination to one of the healthy pod IPs (chosen round-robin or via IPVS).

Think of ClusterIP as a pointer, not an address. The real addresses are in the Endpoints object.

```text
Service object  →  Endpoints object  →  Pod IPs
(ClusterIP VIP)     (live pod IPs)        (real targets)
```

kube-proxy watches Services and Endpoints and keeps the iptables/IPVS rules on every node in sync. When a pod fails its readiness probe, it's removed from Endpoints → kube-proxy removes the DNAT rule → no more traffic to that pod.

## Core Building Blocks

### ClusterIP
**Why it exists** — Pods restart and get new IPs; consumers need a stable address to target.
**What it is** — A virtual IP allocated from the Service CIDR (e.g., `10.96.0.0/12`). No NIC or interface owns it; it's a iptables/IPVS rule that performs DNAT.
**One-liner** — A stable virtual IP that iptables silently rewrites to a real pod IP.

```bash
# See all services and their ClusterIPs
kubectl get svc -A

# Test connectivity from inside a pod
kubectl exec -it <pod> -- curl http://<clusterIP>:<port>

# Or use the DNS name (see 004-dns-coredns.md)
kubectl exec -it <pod> -- curl http://<svc-name>.<namespace>
```

### Endpoints / EndpointSlices
**Why it exists** — The Service needs to know which pods are currently healthy and ready to receive traffic.
**What it is** — An Endpoints object (or the newer EndpointSlice) is automatically maintained by the Endpoints controller. It holds the list of pod IPs + ports that match the Service's selector and have passed readiness probes. kube-proxy reads this to build DNAT rules.
**One-liner** — The live roster of pod IPs backing a Service; updated automatically as pods come and go.

```bash
# See endpoints for a service
kubectl get endpoints <svc-name>

# See endpoint slices (newer API)
kubectl get endpointslices -l kubernetes.io/service-name=<svc-name>

# If endpoints are empty — selector doesn't match any ready pod
kubectl get pods -l <selector-key>=<selector-value>
```

### kube-proxy
**Why it exists** — Something must translate the virtual ClusterIP into real pod IPs on every node; kube-proxy does this by programming iptables/IPVS.
**What it is** — A DaemonSet pod on every node that watches the API server for Service and Endpoint changes, then writes iptables rules (or IPVS entries) to implement the ClusterIP → pod IP translation.
**One-liner** — The agent on every node that keeps iptables rules in sync with Service/Endpoint state.

```bash
# Check kube-proxy is running
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# View iptables rules for a service (on a node)
iptables -t nat -L KUBE-SERVICES -n | grep <clusterIP>

# kube-proxy mode (iptables vs ipvs)
kubectl -n kube-system get configmap kube-proxy -o yaml | grep mode
```

### Service YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web          # must match pod labels
  ports:
  - port: 80          # Service port (what consumers call)
    targetPort: 8080  # Container port (what the app listens on)
  type: ClusterIP     # default; only reachable inside cluster
```

### Service Types Summary

| Type | Reachable From | How It Works |
|------|---------------|--------------|
| ClusterIP | Inside cluster only | Virtual IP + iptables DNAT |
| NodePort | Outside via `<NodeIP>:<port>` | Built on ClusterIP; adds node port 30000-32767 |
| LoadBalancer | Outside via cloud LB | Built on NodePort; cloud provider creates external LB |
| ExternalName | Inside cluster | DNS CNAME to external hostname; no proxying |

## Troubleshooting

### Service returns "connection refused" or times out
1. Check Endpoints are populated: `kubectl get endpoints <svc>` — empty means no matching ready pods.
2. Check pod selector matches pod labels: `kubectl get pods --show-labels`.
3. Verify `targetPort` matches what the app actually listens on: `kubectl exec <pod> -- ss -tlnp`.
4. Check kube-proxy is running: `kubectl get pods -n kube-system -l k8s-app=kube-proxy`.

### Can reach pod IP directly but not ClusterIP
1. kube-proxy iptables rules may be stale or missing.
2. Check iptables rule: `iptables -t nat -L -n | grep <clusterIP>`.
3. Restart kube-proxy pod: `kubectl delete pod -n kube-system -l k8s-app=kube-proxy`.

### Intermittent failures (some requests succeed, some fail)
1. One of the backing pods is unhealthy — check pod readiness: `kubectl get pods`.
2. Check readiness probe configuration on the Deployment.
3. `kubectl get endpoints <svc>` — count the IPs; should equal number of ready pods.
