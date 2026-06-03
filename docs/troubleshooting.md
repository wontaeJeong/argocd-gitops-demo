# Troubleshooting

이 문서는 `argocd-kind-lab` 실습 중 자주 발생하는 문제와 확인 방법을 정리합니다.

## Docker daemon 미실행

### 증상

`make cluster` 실행 시 Docker 연결 오류가 발생합니다.

```text
Cannot connect to the Docker daemon
```

### 해결

Docker Desktop 또는 Docker daemon을 실행한 뒤 다시 시도합니다.

```bash
docker ps
make cluster
```

## kind cluster 중복 생성

### 증상

이미 같은 이름의 cluster가 있을 때 cluster 생성 오류가 발생할 수 있습니다.

### 해결

이 repository의 `make cluster`는 `argocd-kind-lab` cluster가 이미 있으면 새로 만들지 않습니다. 기존 cluster를 새로 만들고 싶다면 삭제 후 다시 생성합니다.

```bash
make delete-cluster
make cluster
```

## Argo CD pod Pending 또는 ImagePullBackOff

### 증상

`make wait-argocd`가 timeout되거나 pod 상태가 `Pending`, `ImagePullBackOff`로 표시됩니다.

```bash
kubectl -n argocd get pod
```

### 해결

노드 상태와 이벤트를 확인합니다.

```bash
kubectl get node
kubectl -n argocd describe pod <pod-name>
```

`ImagePullBackOff`는 네트워크 문제나 registry 접근 문제일 수 있습니다. Docker가 정상 동작하는지, 인터넷 연결이 가능한지 확인한 뒤 다시 시도합니다.

## `argocd login localhost:8080` TLS 관련 문제

### 증상

CLI 로그인 시 certificate 또는 TLS 오류가 발생합니다.

### 해결

local lab에서는 port-forward된 `argocd-server`의 자체 서명 인증서를 사용하므로 `--insecure` 옵션을 사용합니다.

```bash
make port-forward
# another terminal
make login
```

직접 실행한다면 다음처럼 로그인합니다.

```bash
argocd login localhost:8080 --username admin --password <password> --insecure
```

## `REPO_URL` 접근 불가

### 증상

Application은 생성되었지만 Argo CD가 repository를 읽지 못합니다.

### 해결

`REPO_URL`이 Argo CD가 접근 가능한 Git remote URL인지 확인합니다. 로컬 파일 경로나 아직 push하지 않은 repository는 사용할 수 없습니다.

```bash
git remote get-url origin
make app-create REPO_URL=<your-git-repo-url>
```

Public repository라면 브라우저나 `git ls-remote`로 접근 가능한지 확인합니다.

```bash
git ls-remote <your-git-repo-url>
```

## private repo 사용 시 repo credential 등록 필요

### 증상

Private repository를 `REPO_URL`로 사용하면 authentication 오류가 발생합니다.

### 해결

Application 생성 전에 Argo CD에 repository credential을 등록합니다.

```bash
argocd repo add <private-repo-url> --username <username> --password <token>
```

SSH key를 사용할 수도 있습니다.

```bash
argocd repo add <private-repo-url> --ssh-private-key-path <path-to-private-key>
```

## Application이 OutOfSync인 경우

### 증상

`make app-status`에서 `OutOfSync`가 표시됩니다.

### 해결

이 lab은 수동 sync를 실습하기 위해 automated sync를 끈 상태입니다. Git 변경사항을 클러스터에 반영하려면 sync를 실행합니다.

```bash
make app-sync
make app-status
```

## namespace가 없어서 sync 실패하는 경우

### 증상

sync 시 `namespaces "hello-app" not found`와 유사한 오류가 발생합니다.

### 해결

`apps/hello-app/namespace.yaml`이 repository에 있고 Git remote에 push되었는지 확인합니다.

```bash
git status
git log --oneline -5
```

필요하면 namespace를 수동으로 만든 뒤 다시 sync할 수 있습니다.

```bash
kubectl create namespace hello-app
make app-sync
```

## port-forward 프로세스 종료 문제

### 증상

브라우저나 CLI가 `localhost:8080`에 연결하지 못합니다.

### 해결

`make port-forward`는 foreground 프로세스입니다. 실행 중인 터미널이 닫히거나 프로세스가 중단되면 접속할 수 없습니다. 다시 실행합니다.

```bash
make port-forward
```

이미 8080 포트가 사용 중이면 기존 프로세스를 종료하거나 다른 포트를 사용하도록 Makefile의 `port-forward` 명령을 임시로 변경합니다.
