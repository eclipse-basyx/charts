Install the Helm unittest plugin once:

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest --verify=false
```

Run the chart tests with:

```bash
helm unittest .
```

The suites cover stable chart contracts such as:

- default ABAC config and derived trust list
- ABAC enablement, disablement and legacy override compatibility
- precedence of service-local ABAC overrides over global defaults
- ABAC mounts and rollout checksum annotations in backend deployments
- optional AAS Environment deployment, ingress and ABAC wiring
- optional DPP API deployment, ingress and ABAC wiring
- Catena-X example values and marker-based ABAC wiring
- common OIDC and ingress configuration
- additional custom CA certificate mounts and trust-store wiring
- runtime `helm test` hook for custom CA mount checks
- service account helper behavior
- digest-aware image rendering
- schema validation for required values and basic formats
- keycloak init resources and a runtime `helm test` realm check
