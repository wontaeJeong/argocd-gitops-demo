# Argo CD GitOps Demo

로컬 kind 클러스터에서 Argo CD와 GitOps 배포 흐름을 실습하기 위한 데모 묶음입니다. 처음 보는 사용자는 이 파일에서 전체 구조를 확인한 뒤, 목적에 맞는 하위 README로 이동하면 됩니다.

## 어디부터 읽을까

- GitOps repo 구조, ApplicationSet, Helm chart 검증을 보려면 [`platform-gitops/README.md`](platform-gitops/README.md)를 읽습니다.
- kind 클러스터 생성, Argo CD 설치, 샘플 Application 배포 실습을 하려면 [`cluster-bootstrap/README.md`](cluster-bootstrap/README.md)를 읽습니다.
- bootstrap 중 문제가 생기면 [`cluster-bootstrap/docs/troubleshooting.md`](cluster-bootstrap/docs/troubleshooting.md)를 봅니다.

## 구조

```text
argocd-gitops-demo/
├── platform-gitops/      # Argo CD가 읽는 GitOps repo 예시
└── cluster-bootstrap/    # 로컬 kind + Argo CD bootstrap 실습
```

`platform-gitops/`의 demo app workload는 별도 앱 source repo를 만들지 않고 공개 OSS 이미지(`prom/prometheus`, `prom/alertmanager`, `prom/pushgateway`)를 공통 chart에 주입합니다. 앱별 차이는 ApplicationSet list generator 값으로 관리합니다.

## 로컬에서 확인한 명령

다음 문서화된 명령은 이 repository에서 로컬로 실행해 확인했습니다.

```sh
cd platform-gitops
helm lint charts/demo-app
helm lint charts/app-data
helm lint charts/observability-config
helm template app-a charts/demo-app --namespace app-a \
  --set fullnameOverride=app-a \
  --set nameOverride=app-a \
  --set image.repository=prom/prometheus \
  --set image.tag=v2.55.1 \
  --set containerPort=9090 \
  --set service.port=9090 \
  --set ingress.host=app-a.localtest.me \
  --set probes.path=/-/healthy
```

`cluster-bootstrap`의 cluster 생성과 Argo CD sync 흐름은 Docker, kind, kubectl, argocd CLI, 접근 가능한 Git remote가 필요한 실습입니다. 이 환경에서는 template rendering과 Makefile command contract만 로컬로 확인했고, 실제 cluster 실행 절차는 [`cluster-bootstrap/docs/quickstart.md`](cluster-bootstrap/docs/quickstart.md)에 분리했습니다.
