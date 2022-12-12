# Kind Playground

## Overview

Provisions a [Kind] cluster as a playground for [Kubernetes] concepts, controllers, operators and tooling.

## TLDR

Provision a kind cluster and install the _all the things_

```
make up
```

## Cluster

Provision a kind cluster

```
make cluster
```

To select the cluster

```
; kubectl config use-context kind-playground
```

## Certificate Manager

Install [cert-manager] to manage [X.509] certificates in the `cert-manager` namespace and provision a self signed certificate issuer

```
make certmanager
```

To create a a self signed certificate -

```
make certificate
```

This will create a Certificate resources that represents the [certificate request], and the Secret resource that

```
; kubectl -n default get certificate my-certificate-tls
NAME                 READY   SECRET               AGE
my-certificate-tls   True    my-certificate-tls   9m8s

; kubectl -n default get secret my-certificate-tls
NAME                 TYPE                DATA   AGE
my-certificate-tls   kubernetes.io/tls   3      9m14s

; kubectl -n default get secret my-certificate-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
...
        Issuer: O=my-org
        Validity
            Not Before: Dec 12 11:19:19 2022 GMT
            Not After : Mar 12 11:19:19 2023 GMT
        Subject: O=my-org
...
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Alternative Name: critical
                DNS:my-certificate.svc
...
```

## Ingress

Install [ingress-nginx] as an [Ingress] controller, using [NGINX] as reverse proxy and load balancer in the `ingress-nginx` namespace

```
make ingress-nginx
```

## Argo

Argo is a project that creates and supports open source tools for Kubernetes to run workflows, manage clusters, and _do GitOps right_.

Install the resources for all Argo tools

```
make argo
```

See below for details on the Argo Tooling and how to install these individually.

### Argo CD

[Argo CD] is a declarative, GitOps continuous delivery tool for Kubernetes.

Install the resources in the `argo` namespace and installs the [argo cd cli]

```
make argo_cd
```

To access the UI modify `/etc/hosts` to include:

```
127.0.0.1       localhost argocd.local
```

Go to https://argocd.local and use the credentials found in

```
make argo_workflows_info
```

### Argo Workflows

[Argo Workflows] is an open source container-native workflow engine for orchestrating parallel jobs on Kubernetes.

Install the resources in the `argo` namespace and installs the [argo workflows cli]

```
make argo_workflows
```

To access the UI modify `/etc/hosts` to include:

```
127.0.0.1       localhost argo-workflows.local
```

Go to https://argo-workflows.local, bypassing the UI login.

### Argo Rollouts

[Argo Rollouts]  is a Kubernetes controller and set of CRDs which provide advanced deployment capabilities such as blue-green, canary, canary analysis, experimentation, and progressive delivery features to Kubernetes.

Install the resources in the `argo-rollouts` namespace and installs the [argo rollouts kubectl plugin]

```
make argo_rollouts
```

#### Demos

A demo of [canary] and [bluegreen] strategies is included in the `manifests/rollouts` directory, taken from the [Argo Rollouts Getting Started] documentation.

Install the resources

```
kubectl apply -f manifests/rollouts/canary.yaml
kubectl apply -f manifests/rollouts/canary-service.yaml
kubectl apply -f manifests/rollouts/bluegreen.yaml
kubectl apply -f manifests/rollouts/bluegreen-service.yaml
```


```
rollout.argoproj.io/canary created
service/canary created
rollout.argoproj.io/bluegreen created
service/bluegreen created

; kubectl get rollouts
NAME        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
bluegreen   5         5         5            5           57s
canary      5         5         5            5           57s
```

#### Canary

A canary rollout is a deployment strategy where the operator releases a new version of their application to a small percentage of the production traffic.

Modify the `.spec.template` to trigger a rollout and watch the Rollout

```
; kubectl argo rollouts set image canary canary=argoproj/rollouts-demo:yellow
rollout "canary" image updated

; kubectl argo rollouts get rollout canary --watch
```

```
kubectl argo rollouts promote canary
```

#### BlueGreen

A Blue Green Deployment allows users to reduce the amount of time multiple versions running at the same time.

Modify the `.spec.template` to trigger a rollout and watch the Rollout

```
; kubectl argo rollouts set image bluegreen bluegreen=argoproj/rollouts-demo:yellow
rollout "bluegreen" image updated

; kubectl argo rollouts get rollout bluegreen --watch
```

```
kubectl argo rollouts promote bluegreen
```

## Horizontal Pod Autoscaler

### Kubernetes Metrics Server

The Kubernetes Metrics Server is an aggregator of resource usage data in your cluster -

> Metrics Server collects resource metrics from Kubelets and exposes them in Kubernetes apiserver
> through Metrics API for use by Horizontal Pod Autoscaler and Vertical Pod Autoscaler. Metrics API
> can also be accessed by kubectl top, making it easier to debug autoscaling pipelines.
>
> Metrics Server is not meant for non-autoscaling purposes. For example, don't use it to forward
> metrics to monitoring solutions, or as a source of monitoring solution metrics. In such cases
> please collect metrics from Kubelet /metrics/resource endpoint directly.

Install the [metrics server]

```
make metrics-server
```

The `metrics-server` is deployed to the `kube-system` namespace.

```
; kubectl -n kube-system get pods -l k8s-app=metrics-server
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-55dd79d7bf-2d9mv   1/1     Running   0          16m
```

### Horizontal Pod Autoscaler

Next, install the the Resources to demonstrate the [HorizontalAutoscaler].

```
make hpa
```

This will create a Deployment, in the `hpa-demo` namespace with a single Pod, as well as a HorizontalPodAutoscaler configured to [scale the deployment] at 50% average utilisation.

```
; kubectl get pods
NAME                          READY   STATUS    RESTARTS   AGE
horizontal-5cc466c47f-7t64z   1/1     Running   0          67s

; kubectl get hpa
NAME         REFERENCE               TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
horizontal   Deployment/horizontal   0%/50%    1         6         1          25s
```

To increase the load, we can run a [busybox] container that repeatedly hits an endpoint of the Service. In a new terminal window, kick off the load generator.

```
make hpa-load-generator
```

Now run:

```
; kubectl get hpa horizontal --watch
NAME         REFERENCE               TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
horizontal   Deployment/horizontal   24%/50%    1         6         2          8m8s
horizontal   Deployment/horizontal   169%/50%   1         6         2          8m15s
horizontal   Deployment/horizontal   108%/50%   1         6         4          8m30s
horizontal   Deployment/horizontal   72%/50%    1         6         6          8m45s
horizontal   Deployment/horizontal   52%/50%    1         6         6          9m
horizontal   Deployment/horizontal   38%/50%    1         6         6          9m15s
^C

; k get deployment horizontal
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
horizontal   6/6     6            6           10m
```

The increased CPU load exceeds the target threshold of 50% and new Pods are provisioned in response.

To stop the load, press `Ctrl+C` in the terminal you created the `busybox` Pod.

```
; make hpa-load-generator
If you don't see a command prompt, try pressing enter.
OK!OK!OK!^Cpod "load-generator" deleted
pod hpa-demo/load-generator terminated (Error)
```

Again, you can watch the HorizontalPodAutoscaler and see that the drop in CPU load triggers a scale down of Pods.

```
; kubectl get hpa horizontal --watch
horizontal   Deployment/horizontal   0%/50%     1         6         6          24m
horizontal   Deployment/horizontal   0%/50%     1         6         5          24m
horizontal   Deployment/horizontal   0%/50%     1         6         5          25m
horizontal   Deployment/horizontal   0%/50%     1         6         3          26m
horizontal   Deployment/horizontal   0%/50%     1         6         3          26m
horizontal   Deployment/horizontal   0%/50%     1         6         1          26m
horizontal   Deployment/horizontal   68%/50%    1         6         1          27m

; k get deployment
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
horizontal   2/2     1            1           39m
```

## OPA Gatekeeper

The [Open Policy Agent] (OPA) is _an open source, general-purpose policy engine that unifies policy enforcement across the stack_. The [admission controller webhooks] are executed whenever a resource is created, updated or deleted. Policy decisions are executed by OPA by evaluating against policies and data. For example,

- allow only images from an official source to be pulled
- ensure all Deployment resources describe expected labels
- enforce consistent naming conventions for resources

[Gatekeeper] uses native Kubernetes [Custom Resource Definition] (CRD)-based policies executed by OPA. Constraints are defined by reusable [Constraint Templates], which define the schema of Constraints, as well as the policy definitions.

Install the Gatekeeper admissions controller and the [Gatekeeper Library] Constraint Templates -

```
make gatekeeper
```

Install the Constaints -

```
make gatekeeper-constraints
```

This creates two Constaints -

- enforce all Namespaces to use an `owner` label
- enforce all Namespaces to use an `registry` annotation

To see the Constraints in action,

```
make gatekeeper-examples
```

This provides

- a Namespace definition _with_ the required label and annotations
- a Namespace definition _without_ the required label
- a Namespace definition _without_ the required annotation


The first definition will create the resource, as expected, while the remaining definitions will be rejected.

```
kubectl -n gatekeeper-system apply -f manifests/opa/examples
namespace/namespace-satisfies-constraints created
Error from server (Forbidden): error when creating "manifests/opa/examples/namespace-fails-annotation-constraint.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [ns-must-have-registry] you must provide annotation(s): {"registry"}
Error from server (Forbidden): error when creating "manifests/opa/examples/namespace-fails-label-constraint.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [ns-must-have-owner] you must provide labels: {"owner"}
```

[kind]: https://kind.sigs.k8s.io/
[kubernetes]: https://kubernetes.io/
[argo]: https://argoproj.github.io/
[cert-manager]: https://cert-manager.io/
[x.509]: https://en.wikipedia.org/wiki/X.509
[certificate request]: https://cert-manager.io/docs/concepts/certificate/
[ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[ingress-nginx]: https://github.com/kubernetes/ingress-nginx
[nginx]: https://www.nginx.org/
[argo cd]: https://argoproj.github.io/cd/
[argo cd cli]: https://github.com/argoproj/argo-cd/releases
[argo workflows]:https://argoproj.github.io/workflows
[argo workflows cli]: https://github.com/argoproj/argo-workflows/releases
[argo rollouts]: https://argoproj.github.io/rollouts
[argo rollouts kubectl plugin]: https://github.com/argoproj/argo-rollouts/releases
[canary]: https://argoproj.github.io/argo-rollouts/features/canary/
[bluegreen]: https://argoproj.github.io/argo-rollouts/features/bluegreen/
[argo rollouts getting started]: https://github.com/argoproj/argo-rollouts/blob/master/docs/getting-started.md
[metrics server]: https://github.com/kubernetes-sigs/metrics-server
[horizontalautoscaler]: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale
[busybox]: https://busybox.net/
[scale the deployment]: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#algorithm-details
[open policy agent]: https://www.openpolicyagent.org/
[admission controller webhooks]: https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/
[gatekeeper]: https://open-policy-agent.github.io/gatekeeper/
[gatekeeper library]: https://github.com/open-policy-agent/gatekeeper-library
[custom resource definition]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/
[constraint templates]: https://open-policy-agent.github.io/gatekeeper/website/docs/constrainttemplates/
