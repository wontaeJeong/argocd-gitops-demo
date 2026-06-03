---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: HEAD
    path: apps/hello-app
  destination:
    server: https://kubernetes.default.svc
    namespace: hello-app
