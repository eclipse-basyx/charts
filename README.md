# Eclipse BaSyx Helm Chart Repository

## Usage

Add the Helm repository:

```bash
helm repo add basyx https://eclipse-basyx.github.io/charts/
helm repo update
```

List available BaSyx charts:

```bash
helm search repo basyx --versions
```

If the latest BaSyx chart is published as a pre-release, for example
`3.0.0-rc.1`, include development versions:

```bash
helm search repo basyx --versions --devel
```

Install the BaSyx Go chart:

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

## About This Repository

This site hosts the Helm repository for Eclipse BaSyx charts.

```text
https://eclipse-basyx.github.io/charts/
```

## Chart Sources

Chart source code, example values and documentation are maintained on the
`main` branch:

```text
https://github.com/eclipse-basyx/charts
```

The Helm repository index is maintained in `index.yaml` by the chart release
workflow.

Older chart versions may still be listed for backwards compatibility with
existing installations.
