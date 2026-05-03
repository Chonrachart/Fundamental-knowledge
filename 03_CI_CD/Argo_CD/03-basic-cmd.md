# install command

```bash
helm repo add argocd https://argoproj.github.io/argo-helm
helm repo update
helm search repo argo/argo-cd --version                       # search argocd version
helm upgrade argocd argo/argo-cd --version x.x.x --install --create-namespace -n argocd

### access UI
kubectl port-forward svc/argocd-server -n argocd 8080:80

### URL
https://127.0.0.1:8080

### initial-admin-password
kubectl get  secret argocd-initial-admin-secret -o jsonpath="{.data.password}" -n argocd | base64 -d
```

# argocd cmd 

```bash
which argocd 

argocd version

argocd help

argocd login localhost:8080 --name local  # login to specific address of argocd server

argocd context

argocd app list
```