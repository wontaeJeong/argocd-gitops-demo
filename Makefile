CLUSTER_NAME ?= argocd-kind-lab
KIND_NODE_IMAGE ?= kindest/node:v1.31.2
ARGOCD_NAMESPACE ?= argocd
ARGOCD_VERSION ?= stable
APP_NAME ?= hello-app
APP_NAMESPACE ?= hello-app
ARGOCD_SERVER ?= localhost:8080
ARGOCD_USERNAME ?= admin
APPLICATION_TEMPLATE ?= argocd/application.yaml.tpl
APPLICATION_RENDERED ?= .tmp/application.yaml

.PHONY: cluster delete-cluster install-argocd wait-argocd argocd-password port-forward login app-create app-sync app-status app-delete cleanup check-repo-url
.PHONY: check-argocd-cli

cluster:
	@if kind get clusters | grep -qx '$(CLUSTER_NAME)'; then \
		echo "kind cluster '$(CLUSTER_NAME)' already exists"; \
	else \
		kind create cluster --name '$(CLUSTER_NAME)' --image '$(KIND_NODE_IMAGE)' --config kind/cluster.yaml; \
	fi

delete-cluster:
	@if kind get clusters | grep -qx '$(CLUSTER_NAME)'; then \
		kind delete cluster --name '$(CLUSTER_NAME)'; \
	else \
		echo "kind cluster '$(CLUSTER_NAME)' does not exist"; \
	fi

install-argocd:
	kubectl get namespace '$(ARGOCD_NAMESPACE)' >/dev/null 2>&1 || kubectl create namespace '$(ARGOCD_NAMESPACE)'
	kubectl apply --server-side --force-conflicts -n '$(ARGOCD_NAMESPACE)' -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml

wait-argocd:
	kubectl -n '$(ARGOCD_NAMESPACE)' rollout status deployment/argocd-server --timeout=180s
	kubectl -n '$(ARGOCD_NAMESPACE)' rollout status deployment/argocd-repo-server --timeout=180s
	kubectl -n '$(ARGOCD_NAMESPACE)' rollout status statefulset/argocd-application-controller --timeout=180s

argocd-password:
	@password_b64="$$(kubectl -n '$(ARGOCD_NAMESPACE)' get secret argocd-initial-admin-secret -o jsonpath="{.data.password}")"; \
	if printf '%s' "$$password_b64" | base64 -d >/dev/null 2>&1; then \
		printf '%s' "$$password_b64" | base64 -d; \
	else \
		printf '%s' "$$password_b64" | base64 -D; \
	fi; \
	printf '\n'

port-forward:
	kubectl -n '$(ARGOCD_NAMESPACE)' port-forward svc/argocd-server 8080:443

check-argocd-cli:
	@if ! command -v argocd >/dev/null 2>&1; then \
		echo "ERROR: argocd CLI is required. Install it first: https://argo-cd.readthedocs.io/en/stable/cli_installation/" >&2; \
		exit 1; \
	fi

login: check-argocd-cli
	password_b64="$$(kubectl -n '$(ARGOCD_NAMESPACE)' get secret argocd-initial-admin-secret -o jsonpath="{.data.password}")"; \
	if printf '%s' "$$password_b64" | base64 -d >/dev/null 2>&1; then \
		password="$$(printf '%s' "$$password_b64" | base64 -d)"; \
	else \
		password="$$(printf '%s' "$$password_b64" | base64 -D)"; \
	fi; \
	argocd login '$(ARGOCD_SERVER)' --username '$(ARGOCD_USERNAME)' --password "$$password" --insecure

check-repo-url:
	@if [ -z "$(REPO_URL)" ]; then \
		echo "ERROR: REPO_URL is required. Example: make app-create REPO_URL=https://github.com/<user>/argocd-kind-lab.git" >&2; \
		exit 1; \
	fi

app-create: check-repo-url
	mkdir -p .tmp
	REPO_URL='$(REPO_URL)' scripts/render-application.sh '$(APPLICATION_TEMPLATE)' '$(APPLICATION_RENDERED)'
	kubectl apply -f '$(APPLICATION_RENDERED)'

app-sync: check-argocd-cli
	argocd app sync '$(APP_NAME)'

app-status: check-argocd-cli
	argocd app get '$(APP_NAME)'

app-delete:
	@if kubectl -n '$(ARGOCD_NAMESPACE)' get application '$(APP_NAME)' >/dev/null 2>&1; then \
		if command -v argocd >/dev/null 2>&1; then \
			argocd app delete '$(APP_NAME)' --yes || kubectl -n '$(ARGOCD_NAMESPACE)' delete application '$(APP_NAME)' --ignore-not-found; \
		else \
			kubectl -n '$(ARGOCD_NAMESPACE)' delete application '$(APP_NAME)' --ignore-not-found; \
		fi; \
	else \
		echo "Argo CD Application '$(APP_NAME)' does not exist"; \
	fi

cleanup: app-delete delete-cluster
