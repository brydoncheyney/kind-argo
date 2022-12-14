all: lint cluster certmanager ingress argo hpa gatekeeper

.PHONY: up
up: all

K8S_TIMEOUT:=60s

define header
#####################################################################
# Target: $@ |$(1)
#####################################################################
endef
export header

.PHONY: lint
lint:
	@type yamllint &>/dev/null || brew install yamllint
	yamllint -d relaxed manifests

.PHONY:cluster
cluster:
	$(call header, Creating KIND Cluster)
	@type kind &>/dev/null || brew install kind
	kubectl cluster-info --context kind-playground &>/dev/null || kind create cluster --config manifests/config.yaml
	kubectl wait --for=condition=ready node -l kubernetes.io/hostname=playground-control-plane --timeout $(K8S_TIMEOUT)

.PHONY: kind
kind: cluster

.PHONY: destroy
destroy:
	$(call header, Destroying KIND Cluster!)
	kind delete cluster --name playground

.PHONY: delete
delete: destroy

.PHONY: certmanager
certmanager:
	$(call header, Certificate Manager)
	kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.10.0/cert-manager.yaml
	kubectl -n cert-manager wait --for=condition=ready pod -l app.kubernetes.io/name=webhook --timeout $(K8S_TIMEOUT)
	kubectl apply -f manifests/cert-issuer.yaml

.PHONY: certmanager
cert-manager: certmanager

.PHONY: certificate
certificate:
	kubectl apply -f manifests/certificate.yaml

.PHONY: ingress-nginx
ingress-nginx:
	$(call header, Ingress - NGINX)
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
	kubectl -n ingress-nginx wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx,app.kubernetes.io/component=controller --timeout $(K8S_TIMEOUT)
	kubectl apply -f manifests/ingress.yaml

.PHONY: ingress
ingress: ingress-nginx

.PHONY: ingress-nginx-examples
ingress-nginx-examples:
	$(call header, Ingress - NGINX - examples)
	kubectl -n ingress-nginx apply -f manifests/ingress-usage.yaml
	kubectl -n ingress-nginx wait --for condition=ready pods -l app=foo --timeout $(K8S_TIMEOUT)
	kubectl -n ingress-nginx wait --for condition=ready pods -l app=bar --timeout $(K8S_TIMEOUT)
	$(call header, Validate that the ingress works - try)
	@echo "curl localhost/foo"
	@echo "curl localhost/bar"

define cd_hostfile
#####################################################################
#
# Modify /etc/hosts to include:
#
# 127.0.0.1       localhost argocd.local
#
# https://argocd.local - admin:$(CD_PASSWORD)
#
#####################################################################
endef
export cd_hostfile

.PHONY: cd_info
cd_info:
	@$(eval CD_PASSWORD=$(shell kubectl -n argo get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d))
	$(call cd_hostfile)

.PHONY: cd
cd:
	$(call header, Argo CD)
	kubectl create namespace argo 2>/dev/null || true
	kubectl apply -n argo -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl apply -f manifests/argocd-ingress.yaml
	kubectl -n argo wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout $(K8S_TIMEOUT)
	@type argocd &>/dev/null || brew install argocd

.PHONY: argo_cd
argo_cd: cd cd_info

define workflows_hostfile
#####################################################################
#
# Modify /etc/hosts to include:
#
# 127.0.0.1       localhost argo-workflows.local
#
# go to https://argo-workflows.local
#
#####################################################################
endef
export workflows_hostfile

.PHONY: workflows_info
workflows_info:
	$(call workflows_hostfile)

.PHONY: workflows
workflows:
	$(call header, Argo Workflows)
	kubectl create namespace argo 2>/dev/null || true
	kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.4.3/install.yaml
	kubectl apply -f manifests/argo-workflows-ingress.yaml
	@type argo &>/dev/null || brew install argo
	kubectl patch deployment \
    argo-server \
    --namespace argo \
    --type='json' \
    -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["server", --auth-mode=server ]}]'

.PHONY: argo_workflows
argo_workflows: workflows workflows_info

.PHONY: rollouts
rollouts:
	$(call header, Argo Rollouts)
	kubectl create namespace argo-rollouts 2>/dev/null || true
	kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
	@type kubectl-argo-rollouts &>/dev/null || brew install argoproj/tap/kubectl-argo-rollouts

.PHONY: argo_rollouts
argo_rollouts: rollouts

.PHONY: argo
argo: argo_cd argo_workflows argo_rollouts

.PHONY: metrics-server
metrics-server:
	$(call header, Metrics Server)
	kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
	kubectl patch \
	-n kube-system deployment metrics-server \
	--type=json \
	-p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

.PHONY: hpa
hpa: metrics-server
	$(call header, Horizontal Pod Autoscaler)
	kubectl create namespace hpa-demo 2>/dev/null || true
	kubectl apply -n hpa-demo -f manifests/hpa.yaml

.PHONY: hpa-load-generator
hpa-load-generator:
	$(call header, HPA Load Generator)
	@bash -c 'trap "exit 0" EXIT ; \
			kubectl run \
			-i \
			--tty load-generator \
			--rm \
			--image=busybox:1.34.1 \
			--restart=Never \
			-- /bin/sh -c "while sleep 0.01; do wget -q -O- http://horizontal; done"'

.PHONY: gatekeeper-controller
gatekeeper-controller:
	$(call header, OPA Gatekeeper Controller Manager)
	kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
	kubectl -n gatekeeper-system wait --for condition=ready pod -l control-plane=controller-manager --timeout ${K8S_TIMEOUT}

.PHONY: gatekeeper-constraint-templates
gatekeeper-constraint-templates:
	$(call header, OPA Gatekeeper ConstraintTemplates)
	kubectl -n gatekeeper-system apply --kustomize manifests/opa

.PHONY: gatekeeper
gatekeeper: gatekeeper-controller gatekeeper-constraint-templates

.PHONY: gatekeeper-contraints
gatekeeper-constraints:
	$(call header, OPA Gatekeeper Contraints)
	kubectl -n gatekeeper-system apply -f manifests/opa/constraints

.PHONY: gatekeeper-examples
gatekeeper-examples:
	$(call header, OPA Gatekeeper Examples)
	kubectl -n gatekeeper-system apply -f manifests/opa/examples
