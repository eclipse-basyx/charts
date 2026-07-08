# BaSyx Go Helm Charts

This repository contains a Helm chart for deploying an Eclipse BaSyx Go based environment on Kubernetes.

The chart installs the BaSyx Go backend services, a PostgreSQL database, optional Keycloak-based authentication, optional ABAC authorization, ingress resources, certificates, the AAS Web UI and optional supporting runtime tests.

The repository follows the common Helm multi-chart layout:

```text
charts/basyx/           Helm chart for BaSyx Go
values/                 Custom values examples and deployment overlays
```

The main chart is located at `charts/basyx`. All commands below are written from the repository root.

## What Gets Deployed

The `basyx` chart can deploy these components:

| Component | Purpose |
| --- | --- |
| `keycloak` | Identity provider for the Web UI and secured BaSyx services |
| `aasDiscovery` | AAS discovery service |
| `aasRegistry` | AAS registry service |
| `aasRepository` | AAS repository service |
| `aasEnvironment` | Integrated AAS environment service bundling AAS, submodel, concept description, registry and discovery APIs |
| `dppApi` | Digital Product Passport API service |
| `submodelRegistry` | Submodel registry service |
| `submodelRepository` | Submodel repository service |
| `cdRepository` | Concept description repository |
| `companyLookup` | Company endpoint directory for dataspace participants |
| `digitalTwinRegistry` | Digital twin registry |
| `aasWebGui` | Web UI for browsing and uploading AAS data |
| `database` | PostgreSQL cluster managed by CloudNativePG |
| `configurationService` | One-shot BaSyx Go job that initializes and migrates the PostgreSQL schema |

## How The Deployment Works

A deployment is one Helm release, usually named `basyx`, installed into one Kubernetes namespace.

The default chart values live in:

```text
charts/basyx/values.yaml
```

Custom values files live outside the chart, for example:

```text
values/values.catena-x.example.yaml
values/values.example.yaml
values/values.minimal.yaml
values/values.secured.example.yaml
```

A custom values file usually defines the public host, enabled services, image tags, TLS settings, and optional security settings such as Keycloak users or ABAC rules.

## Prerequisites

You need:

- A Kubernetes cluster and a working `kubectl` context
- Helm 3
- An ingress controller, usually nginx ingress
- cert-manager, because the chart renders `cert-manager.io/v1` resources
- CloudNativePG, because the chart renders `postgresql.cnpg.io/v1` database clusters
- Optional: `helm-unittest` for local chart tests

Check the current cluster context before installing:

```bash
kubectl config current-context
kubectl get nodes
```

If you work with multiple clusters, pass the context explicitly:

```bash
--kube-context custom-rke
```

## Install Required Operators

Install CloudNativePG if it is not already installed:

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --create-namespace
```

Install cert-manager if it is not already installed:

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.19.3 \
  --set crds.enabled=true
```

Verify the required CRDs are available:

```bash
kubectl api-resources | grep cert-manager.io
kubectl api-resources | grep postgresql.cnpg.io
```

## Create A Custom Values File

Start by copying one of the provided example values files:

```bash
# Unsecured deployment without Keycloak and ABAC.
cp values/values.example.yaml values/values.my-environment.yaml

# Minimal deployment with only AAS Environment and Web UI.
cp values/values.minimal.yaml values/values.my-minimal-environment.yaml

# Secured deployment with Keycloak and ABAC.
cp values/values.secured.example.yaml values/values.my-secured-environment.yaml

# Catena-X oriented deployment with marker-based DTR and Submodel access.
cp values/values.catena-x.example.yaml values/values.my-catena-x-environment.yaml
```

The unsecured example enables the core BaSyx Go services and the Web UI:

```yaml
instanceName: example
host: basyx.example.com

tls:
  enabled: true
  hosts:
    - basyx.example.com

ingress:
  issuer: internal-issuer

internal:
  certificateIssuer:
    name: internal-issuer
    autocreateCa: true
    autocreateCaSecretName: internal-issuer-ca

keycloak:
  enabled: false

aasDiscovery:
  enabled: true
aasRegistry:
  enabled: true
aasRepository:
  enabled: true
aasEnvironment:
  enabled: false
dppApi:
  enabled: false
submodelRegistry:
  enabled: true
submodelRepository:
  enabled: true
cdRepository:
  enabled: true
companyLookup:
  enabled: false
aasWebGui:
  enabled: true
  infrastructureConfig:
    infrastructures:
      default: main
      main:
        security:
          type: None

abac:
  enabled: false
```

The `aasWebGui.infrastructureConfig...security.type: None` override is intentional for unsecured deployments. Without it, the Web UI would inherit the chart's secured default configuration.

Use `values/values.secured.example.yaml` when you want authentication and authorization enabled from the start. It enables Keycloak, initializes an example admin user and enables ABAC with the chart default rule that grants full access to users with token claim `role=admin`.

Use `values/values.minimal.yaml` when you want the BaSyx Go MinimalExample style deployment. It enables only `aasEnvironment` and `aasWebGui`; the individual AAS/Submodel registries and repositories stay disabled because the AAS Environment exposes those APIs through one component.

For DPP API deployments, enable `dppApi` in your own values file. DPP commonly runs together with `aasEnvironment` and `aasWebGui`, but it is configured through the same service block pattern as the other optional BaSyx Go services.

Use `values/values.catena-x.example.yaml` when you want a Catena-X oriented setup. It enables Keycloak, ABAC, Digital Twin Registry and Submodel Repository with BPN-based marker access rules.

Do not publish production passwords or client secrets. For public examples, use placeholders and inject real credentials through your deployment pipeline or an external secret management solution.

## Render Before Installing

Always render the chart before the first install. This catches schema errors and missing CRDs early:

```bash
helm lint charts/basyx -f values/values.example.yaml
helm lint charts/basyx -f values/values.minimal.yaml
helm lint charts/basyx -f values/values.secured.example.yaml
helm lint charts/basyx -f values/values.catena-x.example.yaml

helm template basyx charts/basyx \
  -n basyx-custom \
  -f values/values.example.yaml
```

If you use chart-local custom certificates, render from the repository root so the chart can read files under `charts/basyx/config-files/`.

## Install BaSyx Go

Install the release:

```bash
helm upgrade --install basyx charts/basyx \
  --kube-context custom-rke \
  -n basyx-custom \
  --create-namespace \
  -f values/values.example.yaml
```

If you are already on the correct Kubernetes context, `--kube-context` is optional:

```bash
helm upgrade --install basyx charts/basyx \
  -n basyx-custom \
  --create-namespace \
  -f values/values.example.yaml
```

## Check The Deployment

Check the Helm release:

```bash
helm --kube-context custom-rke status basyx -n basyx-custom
helm --kube-context custom-rke history basyx -n basyx-custom
```

Check Kubernetes resources:

```bash
kubectl --context custom-rke get pods,svc,ingress \
  -n basyx-custom
```

Wait for a service rollout:

```bash
kubectl --context custom-rke rollout status \
  deployment/basyx-aas-registry \
  -n basyx-custom
```

Check logs:

```bash
kubectl --context custom-rke logs \
  -n basyx-custom \
  deploy/basyx-aas-registry \
  -c aas-registry
```

Run runtime Helm tests:

```bash
helm --kube-context custom-rke test basyx \
  -n basyx-custom \
  --logs
```

## Access The Services

With the default paths, services are exposed below one host:

| Service | URL pattern |
| --- | --- |
| AAS Web UI | `https://<host>/aas-gui/` |
| Keycloak | `https://<host>/identity-management` |
| AAS Discovery | `https://<host>/aas-discovery` |
| AAS Registry | `https://<host>/aas-registry` |
| AAS Repository | `https://<host>/aas-repository` |
| AAS Environment | `https://<host>/aas-environment` |
| DPP API | `https://<host>/dpp-api/v1/dpps` |
| Submodel Registry | `https://<host>/submodel-registry` |
| Submodel Repository | `https://<host>/submodel-repo` or your custom override |
| Concept Description Repository | `https://<host>/cd-repository` |
| Company Lookup | `https://<host>/company-lookup/companies` |
| Digital Twin Registry | `https://<host>/digital-twin-registry` |

Company Lookup intentionally has no resource at the bare `/company-lookup` path. Use `/company-lookup/companies`, `/company-lookup/description`, `/company-lookup/swagger` or `/company-lookup/health`.

DPP API exposes its main API below `/dpp-api/v1/dpps`, Swagger UI below `/dpp-api/swagger`, OpenAPI below `/dpp-api/api-docs/openapi.yaml` and health below `/dpp-api/health` when using the default path.

## Upgrade A Deployment

Change the custom values and run:

```bash
helm upgrade basyx charts/basyx \
  --kube-context custom-rke \
  -n basyx-custom \
  -f values/values.example.yaml
```

For safer upgrades, render first and optionally use the Helm diff plugin:

```bash
helm diff upgrade basyx charts/basyx \
  --kube-context custom-rke \
  -n basyx-custom \
  -f values/values.example.yaml
```

## Uninstall

Uninstall the Helm release:

```bash
helm uninstall basyx \
  --kube-context custom-rke \
  -n basyx-custom
```

CloudNativePG database PVCs and manually created secrets may need separate cleanup, depending on your cluster retention policy.

## Configuration Overview

### Global Values

| Value | Description |
| --- | --- |
| `instanceName` | Logical deployment name. Useful for templated certificate paths and UI labels. |
| `host` | Public DNS host used by ingress, Keycloak issuer URLs and Web UI URLs. |
| `nameOverride` | Overrides the chart name used in generated resource names. |
| `fullnameOverride` | Overrides the generated release name. |
| `paths.*` | Public URL paths for the services. All paths should start with `/`. |
| `environment.common.*` | Shared environment variables loaded by BaSyx backend services. |

### TLS And Certificates

| Value | Description |
| --- | --- |
| `tls.enabled` | Enables TLS-related mounts and ingress TLS rendering. |
| `tls.hosts` | Hosts included in rendered TLS resources. |
| `ingress.issuer` | Existing namespaced cert-manager issuer for ingress certificates. |
| `ingress.clusterIssuer` | Existing cluster issuer for ingress certificates. |
| `internal.certificateIssuer.autocreateCa` | Creates an internal self-signed CA and issuer. |
| `internal.certificateIssuer.name` | Internal issuer name used by generated certificates. |

The chart sets `spec.privateKey.rotationPolicy: Always` on the generated CA certificate to avoid cert-manager v1.18+ default-change warnings.

### Additional CA Certificates

BaSyx services sometimes need to call HTTPS endpoints that use private CAs. Add those CAs with `internal.CACertificates.trustStore`.

Inline certificate bundle:

```yaml
internal:
  CACertificates:
    trustStore:
      additionalCACertificates: |-
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
```

Chart-local certificate directory:

```yaml
instanceName: custom

internal:
  CACertificates:
    trustStore:
      chartFileDirectory: /config-files/certs/{{ .Values.instanceName }}
```

Expected directory inside the chart:

```text
charts/basyx/config-files/certs/custom/
  partner-root-ca.crt
  external-service-ca.crt
```

The chart projects configured certificate sources into the pods and updates `SSL_CERT_DIR` automatically.

### Database

The chart creates a CloudNativePG cluster:

```yaml
database:
  clusterName: basyx-database
  database: basyx
  owner: basyx
  instances: 3
  storage:
    size: 10Gi
```

For smaller development deployments, reduce the number of database instances and storage size:

```yaml
database:
  instances: 1
  storage:
    size: 5Gi
```

### BaSyx Configuration Service

BaSyx Go requires the database schema to be prepared before DB-backed services start. The chart enables `configurationService` by default for this. It renders a Kubernetes `Job` using `eclipsebasyx/basyxconfigurationservice-go` and the same CloudNativePG application secret as the runtime services.

The Configuration Service image is versioned independently from the BaSyx runtime service images. Set `configurationService.image.tag` or, preferably for reproducible deployments, `configurationService.image.digest` explicitly when a schema migration image changes.

The default job runs as a Helm hook:

```yaml
configurationService:
  enabled: true
  image:
    tag: "1.0.1"
  waitForDatabase:
    enabled: true
  hook:
    enabled: true
    events:
      - post-install
      - pre-upgrade
```

`pre-upgrade` runs schema migrations before updated runtime pods are rolled out. `post-install` is used for fresh installs because the PostgreSQL cluster is created by the same chart and must exist before the job can connect.

On fresh installs, CloudNativePG may need some time before the database accepts connections. The chart therefore adds a `wait-for-database` init container that polls PostgreSQL with `pg_isready` before starting the Configuration Service. This avoids slow Kubernetes Job backoff loops when the database is simply not ready yet.

After deployment, verify the job and logs with:

```bash
kubectl -n basyx-custom get job basyx-configuration
kubectl -n basyx-custom logs job/basyx-configuration
```

The successful database state is stored in the `basyxsystem` table with `state=clean`.

### Keycloak

Keycloak is disabled in the unsecured example and enabled in `values/values.secured.example.yaml`. When enabling it, configure at least admin and client credentials:

```yaml
keycloak:
  enabled: true
  realm: basyx
  secrets:
    admin:
      username: admin
      password: change-me
    client:
      name: basyx-ui
      clientPassword: change-me
```

The chart can also create roles, clients, protocol mappers and users through `keycloak.initialization.*`.
The default chart values initialize a generic admin user named `basyx.admin` with the password `changeit`.
Override `keycloak.initialization.users` and `keycloak.secrets.*` before using Keycloak in any shared or production environment.

### BaSyx Services

Each backend service has a similar values structure:

```yaml
aasRepository:
  enabled: true
  replicaCount: 1
  image:
    repository: eclipsebasyx/aasrepository-go
    tag: "1.0.1"
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: "8080"
  ingress:
    enabled: true
```

Supported service blocks:

- `aasDiscovery`
- `aasRegistry`
- `aasRepository`
- `aasEnvironment`
- `dppApi`
- `submodelRegistry`
- `submodelRepository`
- `cdRepository`
- `companyLookup`
- `digitalTwinRegistry`

Most service blocks support `enabled`, `replicaCount`, `image.*`, `imagePullSecrets`, `service.*`, `ingress.*`, `resources`, `nodeSelector`, `tolerations`, `affinity`, `podAnnotations`, `podLabels`, `podSecurityContext`, `securityContext`, `volumes`, `volumeMounts` and optional service-local `abac` overrides.

`aasEnvironment` uses the `eclipsebasyx/aasenvironment-go` image and defaults to service port `8082`. It can be deployed as a single BaSyx Go API endpoint backed by the chart's PostgreSQL database and Configuration Service. It enables AAS Registry, Submodel Registry and Discovery integration by default:

```yaml
aasEnvironment:
  enabled: true
  environment:
    GENERAL_AASREGISTRYINTEGRATION: true
    GENERAL_SUBMODELREGISTRYINTEGRATION: true
    GENERAL_DISCOVERYINTEGRATION: true
```

To import preconfigured AAS files, mount the files into the pod and point BaSyx Go to the mount path:

```yaml
aasEnvironment:
  enabled: true
  general:
    aasPreconfigPaths:
      - /app/preconfiguration
  volumeMounts:
    - name: aas-preconfiguration
      mountPath: /app/preconfiguration
      readOnly: true
  volumes:
    - name: aas-preconfiguration
      configMap:
        name: aas-preconfiguration
```

`dppApi` uses the `eclipsebasyx/dppapi-go` image and defaults to service port `8080`. It stores DPP data in the shared BaSyx database and defaults to audit history settings matching the BaSyx DPP API Docker Compose example:

```yaml
dppApi:
  enabled: true
  history:
    mode: audit
    auditIdentityMode: extended
```

For a DPP-oriented setup similar to the BaSyx DPP API Docker Compose example, enable DPP API together with AAS Environment and Web UI:

```yaml
dppApi:
  enabled: true

aasEnvironment:
  enabled: true

aasWebGui:
  enabled: true
  infrastructureConfig:
    infrastructures:
      default: dpp
      dpp:
        name: "DPP Shared AAS Environment"
        components:
          aasDiscovery:
            baseUrl: "https://{{ .Values.host }}{{ .Values.paths.aasEnvironment }}/lookup/shells"
          aasRegistry:
            baseUrl: "https://{{ .Values.host }}{{ .Values.paths.aasEnvironment }}/shell-descriptors"
            hasDiscoveryIntegration: true
          submodelRegistry:
            baseUrl: "https://{{ .Values.host }}{{ .Values.paths.aasEnvironment }}/submodel-descriptors"
          aasRepository:
            baseUrl: "https://{{ .Values.host }}{{ .Values.paths.aasEnvironment }}/shells"
            hasRegistryIntegration: true
          submodelRepository:
            baseUrl: "https://{{ .Values.host }}{{ .Values.paths.aasEnvironment }}/submodels"
            hasRegistryIntegration: true
          conceptDescriptionRepository:
            baseUrl: "https://{{ .Values.host }}{{ .Values.paths.aasEnvironment }}/concept-descriptions"
        security:
          type: None
          config: null
```

### BaSyx Runtime Configuration

BaSyx Go runtime options can be configured globally and overridden per backend service. Global values are rendered into the shared `<fullname>-common-config` Secret, for example `basyx-common-config` when installing the chart as release `basyx`, and are loaded by all backend services. Service-local values are rendered as explicit container environment variables and therefore override the global defaults.

This applies to:

- `aasDiscovery`
- `aasRegistry`
- `aasRepository`
- `aasEnvironment`
- `dppApi`
- `submodelRegistry`
- `submodelRepository`
- `cdRepository`
- `companyLookup`
- `digitalTwinRegistry`

Global runtime defaults:

```yaml
general:
  trustProxyHeaders: false
  trustedProxyCIDRs: []
  bulkBatchLimit: 1000
  aasPreconfigPaths: []

history:
  mode: "off"
  immutability: "none"
  auditIdentityMode: "none"
  evidence:
    enabled: false
    provider: "none"

eventing:
  enabled: false
  topicPrefix: basyx

abac:
  policyFileImport: ""
  policyScope: ""
  managementApi:
    enabled: false
```

Service-local override example:

```yaml
history:
  mode: "off"

aasRepository:
  history:
    mode: audit
    immutability: postgres_guarded
    auditIdentityMode: extended
    evidence:
      enabled: true
      provider: s3
      bucket: basyx-history-evidence
      endpoint: http://minio:9000
      pathStyle: true
  eventing:
    topicPrefix: aas-repository-events
  general:
    bulkBatchLimit: 500
    aasPreconfigPaths:
      - /aas/preconfigured
  abac:
    policyFileImport: if_missing
    policyScope: aas-repository
    managementApi:
      enabled: true
```

History settings can be overridden independently for each backend service. Use the
global `history` block as the default for all services, then add a service-local
`history` block where a component needs different history or audit behavior:

```yaml
history:
  mode: "off"

aasRepository:
  history:
    mode: api
    fullSnapshotInterval: 1

submodelRepository:
  history:
    mode: audit
    immutability: postgres_guarded
    auditIdentityMode: extended
```

In this example, history stays disabled globally, the AAS Repository records API
history, and the Submodel Repository uses audit-oriented history settings. The
same pattern can be used for `aasDiscovery`, `aasRegistry`, `aasEnvironment`,
`dppApi`, `submodelRegistry`, `cdRepository`, `companyLookup` and `digitalTwinRegistry`.

If you need a parameter that is not modeled as a structured value yet, use the raw environment maps:

```yaml
environment:
  common:
    BASYX_HISTORY_MODE: api

aasRepository:
  environment:
    BASYX_HISTORY_MODE: audit
```

Raw environment maps are the escape hatch and take precedence over structured values. In the example above, `aasRepository.environment.BASYX_HISTORY_MODE` wins over `aasRepository.history.mode`.

#### General Runtime Values

| Value | Rendered environment variable | Description |
| --- | --- | --- |
| `general.enableImplicitCasts` | `GENERAL_ENABLEIMPLICITCASTS` | Enables implicit value casts. |
| `general.enableDescriptorDebug` | `GENERAL_ENABLEDESCRIPTORDEBUG` | Enables descriptor debug behavior. |
| `general.discoveryIntegration` | `GENERAL_DISCOVERYINTEGRATION` | Enables AAS Discovery integration where supported. |
| `general.enableCustomMiddlewareHeaderInjection` | `GENERAL_ENABLECUSTOMMIDDLEWAREHEADERINJECTION` | Enables custom middleware header injection. |
| `general.supportsSingularSupplementalSemanticId` | `GENERAL_SUPPORTSSINGULARSUPPLEMENTALSEMANTICID` | Enables compatibility for singular supplemental semantic IDs. |
| `general.aasRegistryIntegration` | `GENERAL_AASREGISTRYINTEGRATION` | Enables AAS Registry synchronization. |
| `general.submodelRegistryIntegration` | `GENERAL_SUBMODELREGISTRYINTEGRATION` | Enables Submodel Registry synchronization. |
| `general.externalUrl` | `GENERAL_EXTERNALURL` | Public external URL used by registry synchronization. |
| `general.trustProxyHeaders` | `GENERAL_TRUSTPROXYHEADERS` | Trusts forwarded proxy headers. Only enable behind trusted reverse proxies. |
| `general.trustedProxyCIDRs` | `GENERAL_TRUSTEDPROXYCIDRS` | Comma-separated trusted proxy CIDR list. |
| `general.uploadMaxSizeBytes` | `GENERAL_UPLOADMAXSIZEBYTES` | Maximum upload size in bytes. `0` keeps the service default. |
| `general.bulkBatchLimit` | `GENERAL_BULK_BATCH_LIMIT` | Maximum row count per generated bulk SQL statement. Must be greater than `0`. |
| `general.aasPreconfigPaths` | `GENERAL_AAS_PRECONFIG_PATHS` | Comma-separated paths for preconfigured AAS input. Mount matching files or directories with service-specific `volumes` and `volumeMounts`. |

`aasRepository` and `submodelRepository` already set registry integration related values in their service-local `environment` maps by default. Override these service-local values only when you intentionally want different registry synchronization behavior.

#### History, Audit And Evidence Values

| Value | Rendered environment variable | Description |
| --- | --- | --- |
| `history.mode` | `BASYX_HISTORY_MODE` | History mode. Typical values are `off`, `api` or `audit`. |
| `history.retentionDays` | `BASYX_HISTORY_RETENTION_DAYS` | Retention period in days. `0` keeps the service default. |
| `history.fullSnapshotInterval` | `BASYX_HISTORY_FULL_SNAPSHOT_INTERVAL` | Interval for full history snapshots. |
| `history.immutability` | `BASYX_HISTORY_IMMUTABILITY` | Immutability mode, e.g. `none`, `postgres_guarded` or `external_anchor`. |
| `history.auditIdentityMode` | `BASYX_AUDIT_IDENTITY_MODE` | Audit identity mode, e.g. `none`, `minimal` or `extended`. |
| `history.evidence.enabled` | `BASYX_HISTORY_EVIDENCE_ENABLED` | Enables external evidence writing. |
| `history.evidence.provider` | `BASYX_HISTORY_EVIDENCE_PROVIDER` | Evidence provider, e.g. `none` or `s3`. |
| `history.evidence.bucket` | `BASYX_HISTORY_EVIDENCE_BUCKET` | Evidence storage bucket. |
| `history.evidence.prefix` | `BASYX_HISTORY_EVIDENCE_PREFIX` | Object prefix for evidence storage. |
| `history.evidence.region` | `BASYX_HISTORY_EVIDENCE_REGION` | S3-compatible region. |
| `history.evidence.endpoint` | `BASYX_HISTORY_EVIDENCE_ENDPOINT` | S3-compatible endpoint URL. |
| `history.evidence.accessKeyId` | `BASYX_HISTORY_EVIDENCE_ACCESS_KEY_ID` | Evidence storage access key ID. Prefer external secret handling for real credentials. |
| `history.evidence.secretAccessKey` | `BASYX_HISTORY_EVIDENCE_SECRET_ACCESS_KEY` | Evidence storage secret access key. Prefer external secret handling for real credentials. |
| `history.evidence.pathStyle` | `BASYX_HISTORY_EVIDENCE_PATH_STYLE` | Enables path-style S3 access. |
| `history.evidence.retentionMode` | `BASYX_HISTORY_EVIDENCE_RETENTION_MODE` | Object lock retention mode, if supported by the backend. |
| `history.evidence.retentionDays` | `BASYX_HISTORY_EVIDENCE_RETENTION_DAYS` | Object lock retention period in days. |
| `history.evidence.writeTimeoutSeconds` | `BASYX_HISTORY_EVIDENCE_WRITE_TIMEOUT_SECONDS` | Evidence write timeout in seconds. |
| `history.evidence.signing.privateKeyPath` | `BASYX_HISTORY_EVIDENCE_SIGNING_PRIVATE_KEY_PATH` | Private key path for evidence signing. Mount the key separately. |
| `history.evidence.signing.publicKeyPath` | `BASYX_HISTORY_EVIDENCE_SIGNING_PUBLIC_KEY_PATH` | Public key path for evidence verification. Mount the key separately. |
| `history.evidence.signing.required` | `BASYX_HISTORY_EVIDENCE_SIGNING_REQUIRED` | Requires signing for evidence records. |
| `history.integrityAnchor.provider` | `BASYX_HISTORY_INTEGRITY_ANCHOR_PROVIDER` | Integrity anchor provider. |

#### Eventing Values

| Value | Rendered environment variable | Description |
| --- | --- | --- |
| `eventing.enabled` | `BASYX_EVENTING_ENABLED` | Enables event publishing. |
| `eventing.format` | `BASYX_EVENTING_FORMAT` | Event payload format, default `cloudevents`. |
| `eventing.sinks` | `BASYX_EVENTING_SINKS` | Comma-separated sink list. |
| `eventing.outboxEnabled` | `BASYX_EVENTING_OUTBOX_ENABLED` | Enables outbox processing. |
| `eventing.topicPrefix` | `BASYX_EVENTING_TOPIC_PREFIX` | Event topic prefix. |

The current BaSyx Go implementation may fail fast when event publishing or outbox processing is enabled before a matching implementation is available. Keep `eventing.enabled: false` unless you intentionally deploy a compatible eventing setup.

#### ABAC Runtime Values

| Value | Rendered environment variable | Description |
| --- | --- | --- |
| `abac.policyFileImport` | `ABAC_POLICY_FILE_IMPORT` | Controls startup import behavior for ABAC policy files, e.g. `always`, `if_missing` or `never`. Empty value keeps the service default. |
| `abac.policyScope` | `ABAC_POLICY_SCOPE` | Optional database namespace for stored ABAC policies. Empty value keeps the service default scope. Use different scopes to isolate deployments that share a database. |
| `abac.managementApi.enabled` | `ABAC_MANAGEMENT_API_ENABLED` | Enables the ABAC management API where supported. |

### AAS Web UI

Enable the Web UI with:

```yaml
aasWebGui:
  enabled: true
  image:
    tag: 0db02d0
```

The Web UI infrastructure is rendered from `aasWebGui.infrastructureConfig`. The defaults derive service URLs from `host` and `paths.*`.

Logo files are read from the chart-local `config-files/logos` directory.

### ABAC Authorization

ABAC is controlled globally with:

```yaml
abac:
  enabled: true
```

The default rule grants full access to users with token claim `role=admin`.

You can override rules globally:

```yaml
abac:
  accessRules: |
    {
      "AllAccessPermissionRules": {
        "DEFATTRIBUTES": [],
        "DEFOBJECTS": [],
        "DEFACLS": [],
        "DEFFORMULAS": [],
        "rules": []
      }
    }
```

Or per service:

```yaml
aasRepository:
  abac:
    enabled: true
    accessRules: |
      { }
    trustList: |
      [ ]
```

The default trust list is derived from `host`, `paths.keycloak`, `keycloak.realm` and `environment.common.OIDC_AUDIENCE`.

## Network Policies

Network Policies are not included in this chart. For production deployments, restrict
east-west traffic between pods by deploying NetworkPolicy resources separately. Your
cluster must have a Network Policy controller installed (e.g. Calico, Cilium, or Weave).
Standard managed Kubernetes offerings (GKE, EKS, AKS) support this natively.

Recommended rules:

- Allow ingress controller → all BaSyx services (HTTP)
- Allow all BaSyx services → PostgreSQL (port 5432)
- Allow all BaSyx services → Keycloak (port 8080, when enabled)
- Deny all other ingress by default

Example policy restricting ingress to the AAS Registry:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-aas-registry
  namespace: basyx-custom
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: aas-registry
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
      ports:
        - port: 8080
```

## Development And Testing

Install the Helm unittest plugin once:

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest --verify=false
```

Run local chart checks:

```bash
helm lint charts/basyx
helm unittest charts/basyx
```

Run lint with custom values:

```bash
helm lint charts/basyx -f values/values.example.yaml
helm lint charts/basyx -f values/values.minimal.yaml
helm lint charts/basyx -f values/values.secured.example.yaml
helm lint charts/basyx -f values/values.catena-x.example.yaml
```

Runtime smoke tests after deployment:

```bash
helm test basyx -n <namespace> --logs
```

## Debugging

Many BaSyx images are intentionally slim. Prefer ephemeral debug containers:

```bash
kubectl -n <namespace> debug -it pod/<pod-name> \
  --image=nicolaka/netshoot \
  --target=<container-name>
```

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| `no matches for kind "Certificate"` | cert-manager CRDs are missing. Install cert-manager with CRDs enabled. |
| `no matches for kind "Cluster" in version "postgresql.cnpg.io/v1"` | CloudNativePG CRDs are missing. Install CloudNativePG. |
| Ingress returns 404 | Check `host`, `paths.*`, ingress class and whether the service itself has a route for that path. |
| Pods cannot verify Keycloak TLS | Check the internal CA secret, custom CA mounts and `SSL_CERT_DIR`. |
| `Token verification failed: expected audience ...` | Check Keycloak protocol mappers and `environment.common.OIDC_AUDIENCE`. |
| `ABAC(model): NO_MATCH` | Check token claims, ABAC object definitions, route patterns and whether pods rolled after config changes. |
| Custom CA not visible in pod | Run `helm test <release> -n <namespace> --logs` and inspect `/etc/ssl/certs/custom`. |
| Upgrade targets the wrong cluster | Pass `--kube-context <context>` explicitly. |

## Repository Layout

```text
charts/basyx/                       Helm chart
charts/basyx/Chart.yaml             Chart metadata
charts/basyx/values.yaml            Default chart values
charts/basyx/templates/             Kubernetes templates
charts/basyx/tests/                 helm-unittest suites
charts/basyx/config-files/          Chart-local files such as logos and optional certs
values/                             Custom values overlays
```

## Open Source Notes

Before publishing publicly:

- Keep real deployment values, passwords, client secrets and private certificates out of the public repository.
- Provide sanitized example values instead of production overlays.
- Prefer fixed image tags or digests over mutable `SNAPSHOT` tags for reproducible deployments.
- Review ABAC defaults and document deployment-specific rule sets outside the public chart when needed.

## Catena-X Quick Start

The Catena-X example values deploy the parts needed for marker-based Digital Twin access:

- `digitalTwinRegistry` stores shell descriptors and filters them through AAS descriptor markers.
- `submodelRepository` stores submodels and filters them through submodel and submodel-element markers.
- `aasWebGui` is enabled with the `catena-x` infrastructure template, which uses `digitalTwinRegistry` and `submodelService` endpoints instead of the separate `Full` component set.
- `keycloak` is enabled for a self-contained quick start and initializes demo users and token mappers.
- `abac` is enabled globally, with service-local rules for Digital Twin Registry and Submodel Repository.

Start from the example values:

```bash
cp values/values.catena-x.example.yaml values/values.my-catena-x-environment.yaml
```

Edit at least these values before installing:

```yaml
host: basyx.example.com

tls:
  hosts:
    - basyx.example.com

keycloak:
  secrets:
    admin:
      password: change-me
    client:
      clientPassword: change-me
```

Also replace the demo user passwords before using the file outside a throwaway test namespace.

Then render and install:

```bash
helm lint charts/basyx -f values/values.my-catena-x-environment.yaml

helm upgrade --install basyx charts/basyx \
  -n basyx-catena-x \
  --create-namespace \
  -f values/values.my-catena-x-environment.yaml
```

The example initializes these demo users. All example passwords are `change-me`. The passwords are intentionally non-temporary in this example so the upstream Postman collection and command-line data loading examples can fetch OAuth2 password-grant tokens. Change the passwords and disable direct access grants before using this setup beyond a disposable demo namespace.

| User | Initial password | Purpose |
| --- | --- | --- |
| `catena-x.provider` | `change-me` | Data provider with `view_digital_twin`, `add_digital_twin`, `update_digital_twin` and `delete_digital_twin` role claims. |
| `catena-x.partner-a` | `change-me` | Consumer with `Edc-Bpn=BPN_COMPANY_001` for marker-based read access tests. |
| `catena-x.partner-b` | `change-me` | Consumer with `Edc-Bpn=BPN_COMPANY_002` for marker-based read access tests. |

The upstream BaSyx Go marker example also contains demo data:

- [shell-descriptor.json](https://raw.githubusercontent.com/eclipse-basyx/basyx-go-components/main/examples/BaSyxMarkerAccessExample/data/shell-descriptor.json)
- [public-submodel.json](https://raw.githubusercontent.com/eclipse-basyx/basyx-go-components/main/examples/BaSyxMarkerAccessExample/data/public-submodel.json)
- [restricted-submodel.json](https://raw.githubusercontent.com/eclipse-basyx/basyx-go-components/main/examples/BaSyxMarkerAccessExample/data/restricted-submodel.json)
- [BaSyx-Marker-Access.postman_collection.json](https://raw.githubusercontent.com/eclipse-basyx/basyx-go-components/main/examples/BaSyxMarkerAccessExample/BaSyx-Marker-Access.postman_collection.json)

Helm does not load those objects automatically. Download the files from the upstream example and load them explicitly after deployment, for example with the provided Postman collection.

Do not upload these files through the generic Web UI JSON/UML import. That import expects AAS or AAS Environment payloads and will reject `shell-descriptor.json` with `no AAS imported`. The marker example files must be written to their component APIs instead: `shell-descriptor.json` to Digital Twin Registry and the submodel JSON files to Submodel Repository. If you use the example data outside localhost, adjust embedded endpoint URLs in the descriptor to match your ingress host and paths.

The marker rules follow the BaSyx Go marker access example:

- `PUBLIC_READABLE` marks descriptors or submodels that can be read publicly.
- Partner-specific visibility is based on the `Edc-Bpn` token claim.
- Digital Twin Registry checks `specificAssetIds[].externalSubjectId.keys[].value` and `submodelDescriptors[].supplementalSemanticIds[].keys[].value`.
- Submodel Repository checks `supplementalSemanticIds[].keys[].value` on submodels and submodel elements.

For production Catena-X environments, prefer an external IAM or connector flow that issues a trustworthy `Edc-Bpn` token claim. Do not allow arbitrary external clients to set this claim through request headers. Header-to-claim injection should only be enabled behind a trusted ingress or connector mapping.

## References

This README follows the deployment-oriented structure of the Eclipse BaSyx Helm chart documentation while adapting it for the BaSyx Go chart and its current dependencies.

- Eclipse BaSyx charts: https://github.com/eclipse-basyx/charts
- Helm documentation: https://helm.sh/docs/
- CloudNativePG: https://cloudnative-pg.io/
- cert-manager: https://cert-manager.io/
