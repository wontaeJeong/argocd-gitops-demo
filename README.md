# Argo CD GitOps Demo

이 디렉토리는 로컬 kind 클러스터에서 Argo CD와 GitOps 배포 흐름을 실습하기 위한 데모 묶음입니다.

## 구조

```text
argocd-gitops-demo/
├── platform-gitops/
└── cluster-bootstrap/
```

- `platform-gitops/`: Argo CD가 읽는 GitOps repo입니다. ApplicationSet, cluster별 platform values, app/data/observability chart를 관리합니다. demo app workload는 별도 source repo 없이 공개 OSS 이미지(`prom/prometheus`, `prom/alertmanager`, `prom/pushgateway`)를 사용합니다.
- `cluster-bootstrap/`: kind cluster 생성, Argo CD 설치, Application 생성과 sync 실습을 담당하는 local bootstrap repo입니다.

## 기본 사용법

GitOps manifest와 chart 검증은 platform GitOps repo에서 실행합니다.

```sh
cd argocd-gitops-demo/platform-gitops
helm lint charts/demo-app
helm lint charts/app-data
helm template app-a charts/demo-app --namespace app-a \
  --set fullnameOverride=app-a \
  --set nameOverride=app-a \
  --set image.repository=prom/prometheus \
  --set image.tag=v2.55.1 \
  --set containerPort=9090 \
  --set service.port=9090 \
  --set probes.path=/-/healthy
```

local kind와 Argo CD 실습은 bootstrap repo에서 실행합니다.

```sh
cd argocd-gitops-demo/cluster-bootstrap
make cluster
make install-argocd
make wait-argocd
make app-create REPO_URL=<argocd-accessible-git-url>
```

`argocd-gitops-demo/cluster-bootstrap/.tmp/`는 `make app-create` 실행 시 다시 생성되는 임시 산출물입니다.
