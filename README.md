# Kind Argo

## Overview

Provisions a [Kind] cluster as a playground for [Argo] projects. Argo is a project that creates and supports open source tools for [Kubernetes] to run workflows, manage clusters, and _do GitOps right_.

## Cluster

Provision a kind cluster

```
make cluster
```

## Certificate Manager

Install [cert-manager] to manage [X.509] certificates and provision a self signed certificate issuer

```
make certmanager
```

## Ingress

Install [ingress-nginx] as an [Ingress] controller, using [NGINX] as reverse proxy and load balancer

```
make ingress-nginx
```

## Argo

To install the resources for all Argo tools

```
make argo
```

See below for details on the Argo Tooling and how to install these individually.

### Argo CD

[Argo CD] is a declarative, GitOps continuous delivery tool for Kubernetes.

To install the resources

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

To install the resources, as well as the [argo workflows cli]

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

To install the resources, as well as the [argo rollouts kubectl plugin]

```
make argo_rollouts
```

[kind]: https://kind.sigs.k8s.io/
[argo]: https://argoproj.github.io/
[kubernetes]: https://kubernetes.io/
[cert-manager]: https://cert-manager.io/
[x.509]: https://en.wikipedia.org/wiki/X.509
[ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[ingress-nginx]: https://github.com/kubernetes/ingress-nginx
[nginx]: https://www.nginx.org/
[argo cd]:https://argoproj.github.io/cd/
[argo workflows]:https://argoproj.github.io/workflows
[argo workflows cli]: https://github.com/argoproj/argo-workflows/releases
[argo rollouts]: https://argoproj.github.io/rollouts
[argo rollouts kubectl plugin]: https://github.com/argoproj/argo-rollouts/releases
