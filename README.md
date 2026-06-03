# argocd-kind-lab

로컬 개발환경에서 `kind` 클러스터 위에 Argo CD를 설치하고, 이 Git repository 안의 Kubernetes manifest를 Argo CD Application으로 배포해 보는 실습용 repository입니다. 이 구성은 production 구성이 아니라 학습과 테스트를 위한 local lab입니다.

Argo CD는 kind 클러스터 내부의 `argocd` namespace에 설치됩니다. 사용자는 `kubectl port-forward`로 로컬 `https://localhost:8080`에 Argo CD UI/API를 노출한 뒤, `argocd` CLI와 브라우저로 접근합니다. 샘플 앱은 `apps/hello-app` manifest를 사용하며, Argo CD가 접근 가능한 Git remote URL을 `REPO_URL`로 전달해 Application을 생성합니다.

## 전체 구조

```text
argocd-kind-lab/
  README.md
  Makefile
  .gitignore
  kind/
    cluster.yaml
  argocd/
    application.yaml.tpl
  apps/
    hello-app/
      namespace.yaml
      deployment.yaml
      service.yaml
  docs/
    troubleshooting.md
  scripts/
    render-application.sh
```

## 사전 요구사항

다음 도구가 로컬에 설치되어 있어야 합니다.

- Docker: kind 노드를 컨테이너로 실행합니다.
- kind: 로컬 Kubernetes 클러스터를 생성합니다.
- kubectl: 클러스터와 Argo CD Application manifest를 적용합니다.
- argocd CLI: Argo CD 로그인, sync, status 확인에 사용합니다.
- Git: 이 repository를 Git remote에 push해야 Argo CD가 manifest를 읽을 수 있습니다.

이 실습은 cluster 내부에서 로컬 파일시스템 repository를 직접 읽을 수 있다고 가정하지 않습니다. 반드시 GitHub, GitLab 등 Argo CD가 접근 가능한 Git URL이 필요합니다.

## 빠른 시작

```bash
git clone <this-repo>
cd argocd-kind-lab

make cluster
make install-argocd
make wait-argocd

make argocd-password
make port-forward
# another terminal
make login

make app-create REPO_URL=<your-git-repo-url>
make app-sync
make app-status
```

`make port-forward`는 foreground로 실행됩니다. 해당 터미널을 계속 열어 둔 상태에서 다른 터미널에서 `make login`, `make app-sync` 등을 실행합니다.

## 단계별 설명

### 1. kind 클러스터 생성

```bash
make cluster
```

`kind/cluster.yaml`을 사용해 `argocd-kind-lab` 이름의 단일 control-plane 클러스터를 생성합니다. 클러스터 이름은 Makefile의 `CLUSTER_NAME ?= argocd-kind-lab`와 `kind create cluster --name`으로 지정합니다. kind의 moving default image에 의존하지 않도록 `KIND_NODE_IMAGE ?= kindest/node:v1.31.2`를 사용합니다. 이미 같은 이름의 클러스터가 있으면 새로 만들지 않습니다.

필요하면 다음처럼 node image를 바꿀 수 있습니다.

```bash
make cluster KIND_NODE_IMAGE=kindest/node:v1.30.4
```

### 2. Argo CD 설치

```bash
make install-argocd
make wait-argocd
```

`install-argocd`는 `argocd` namespace를 만들고 공식 Argo CD install manifest를 적용합니다. stable manifest의 CRD가 커도 적용되고 반복 실행이 수렴하도록 Makefile은 server-side apply와 force-conflicts를 사용합니다.

```bash
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
```

기본값은 `ARGOCD_VERSION=stable`입니다. 특정 버전을 설치하려면 다음처럼 실행합니다.

```bash
make install-argocd ARGOCD_VERSION=v2.13.3
```

### 3. 초기 admin password 확인

```bash
make argocd-password
```

Makefile은 다음 흐름으로 초기 password를 출력합니다.

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

초기 계정은 `admin`입니다.

### 4. Argo CD UI/API 접속

한 터미널에서 다음 명령을 실행하고 유지합니다.

```bash
make port-forward
```

그 다음 브라우저에서 다음 주소로 접속합니다.

```text
https://localhost:8080
```

다른 터미널에서는 CLI 로그인을 실행합니다.

```bash
make login
```

`argocd-server`는 자체 서명 인증서를 사용하므로 local port-forward 환경에서는 `argocd login localhost:8080 --insecure`를 사용합니다. `--insecure`는 이 local lab에서 인증서 검증 실패를 피하기 위한 옵션이며 production 접근 방식이 아닙니다.

### 5. Git remote 준비

Argo CD가 이 repository의 manifest를 읽으려면 먼저 repository를 GitHub, GitLab 등 remote repository에 push해야 합니다.

```bash
git remote add origin <your-git-repo-url>
git push -u origin main
```

이미 remote가 있으면 사용자의 remote URL을 확인합니다.

```bash
git remote get-url origin
```

이 URL을 `REPO_URL`로 사용합니다. 개인 GitHub URL을 하드코딩하지 않습니다.

### 6. Application 생성

```bash
make app-create REPO_URL=<your-git-repo-url>
```

이 target은 `argocd/application.yaml.tpl`을 임시 파일로 렌더링한 뒤 `kubectl apply -f`로 Argo CD Application을 생성합니다. Application 이름은 `hello-app`이고, source path는 `apps/hello-app`, destination namespace는 `hello-app`입니다.

기본 Application manifest에는 automated sync가 없습니다. 사용자가 `OutOfSync` 상태를 확인하고 수동으로 sync하는 흐름을 실습하기 위해서입니다.

### 7. 샘플 앱 동기화와 상태 확인

```bash
make app-sync
make app-status
```

sync 후에는 다음으로 Kubernetes 리소스를 확인할 수 있습니다.

```bash
kubectl -n hello-app get deploy,svc,pod
```

샘플 앱은 `nginx`를 사용하며 `ClusterIP` Service로 노출됩니다. 외부 LoadBalancer는 사용하지 않습니다. 접속 확인은 port-forward로 합니다.

```bash
kubectl -n hello-app port-forward svc/hello-app 8081:80
```

다른 터미널에서 확인합니다.

```bash
curl http://localhost:8081
```

### 8. GitOps 변경 테스트

`apps/hello-app/deployment.yaml`에서 예를 들어 replicas 값을 변경합니다.

```yaml
spec:
  replicas: 2
```

변경사항을 commit/push합니다.

```bash
git add apps/hello-app/deployment.yaml
git commit -m "Change hello app replicas"
git push
```

Argo CD UI 또는 CLI에서 Application이 `OutOfSync`가 되는지 확인합니다.

```bash
make app-status
```

이후 수동 sync를 실행합니다.

```bash
make app-sync
```

replicas 변경이 반영되었는지 확인합니다.

```bash
kubectl -n hello-app get deploy hello-app
```

image tag를 변경해도 같은 흐름으로 GitOps 변경 테스트를 할 수 있습니다.

### 9. automated sync 옵션

이 repository는 수동 sync 실습을 위해 automated sync를 기본으로 끕니다. 자동 동기화를 실험하려면 `argocd/application.yaml.tpl`의 `spec` 아래에 다음을 추가할 수 있습니다.

```yaml
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

`prune`은 Git에서 제거된 리소스를 클러스터에서도 제거하고, `selfHeal`은 클러스터에서 수동 변경된 리소스를 Git 상태로 되돌립니다.

## Private repository 사용

기본 흐름은 public repository를 기준으로 합니다. Private repository를 사용하려면 Application 생성 전에 Argo CD에 repository credential을 등록해야 합니다.

```bash
argocd repo add <private-repo-url> --username <username> --password <token>
```

SSH key를 사용하는 경우에는 Argo CD CLI의 `argocd repo add --ssh-private-key-path ...` 옵션을 참고해 등록합니다.

## 트러블슈팅

자주 발생하는 문제는 `docs/troubleshooting.md`에 정리되어 있습니다.

```bash
open docs/troubleshooting.md
```

터미널에서 바로 보려면 다음처럼 확인합니다.

```bash
less docs/troubleshooting.md
```

## 정리 방법

Application 삭제 후 kind 클러스터를 삭제합니다.

```bash
make cleanup
```

Application만 삭제하려면 다음을 실행합니다.

```bash
make app-delete
```

클러스터만 삭제하려면 다음을 실행합니다.

```bash
make delete-cluster
```
