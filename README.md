# Eclipse BaSyx Helm Chart Repository

## Use The Repository

Add the repository to Helm:

```bash
helm repo add basyx https://eclipse-basyx.github.io/charts/
helm repo update
```

List available chart versions:

```bash
helm search repo basyx --versions
```

If the latest BaSyx chart is published as a pre-release, for example `3.0.0-rc.1`, include development versions:

```bash
helm search repo basyx --versions --devel
```

Install the current BaSyx chart:

```bash
helm upgrade --install basyx basyx/basyx \
  --namespace basyx \
  --create-namespace
```

When only a pre-release chart is available, add `--devel`:

```bash
helm upgrade --install basyx basyx/basyx \
  --namespace basyx \
  --create-namespace \
  --devel
```

For production deployments, use a custom values file:

```bash
helm upgrade --install basyx basyx/basyx \
  --namespace basyx \
  --create-namespace \
  --values values.yaml
```

## About This Repository

This branch publishes the Helm repository for Eclipse BaSyx charts via GitHub Pages.

The public Helm repository URL is:

```text
https://eclipse-basyx.github.io/charts/
```

## Chart Source And Documentation

The chart source, examples and user-facing documentation live on the `main` branch:

```text
charts/basyx/
values/values.example.yaml
values/values.secured.example.yaml
```

Use `values/values.example.yaml` as a minimal unsecured starting point.

Use `values/values.secured.example.yaml` when you want Keycloak-based authentication and ABAC authorization enabled from the beginning.

## About This Branch

The `gh-pages` branch is a publication branch, not the primary development branch.

Helm reads `index.yaml` from this branch to discover published chart packages. The chart packages themselves are referenced from GitHub release assets.

Older chart versions may remain listed in `index.yaml` for backwards compatibility. New BaSyx Go chart development happens on `main` under `charts/basyx/`.
