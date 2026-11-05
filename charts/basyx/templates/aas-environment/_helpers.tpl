{{/*
Helpers of the experimental MCP endpoint of the AAS Environment.
*/}}

{{/*
Effective MCP setting of the AAS Environment with the precedence of its
rendered environment.
*/}}
{{- define "basyx-aasEnvironment.mcpSetting" -}}
{{- include "basyx.runtimeEnv.effectiveValue" (dict "root" .root "values" .root.Values.aasEnvironment "path" (list "mcp") "key" .key "name" .name) -}}
{{- end }}

{{/*
Return "true" when the AAS Environment serves MCP.
*/}}
{{- define "basyx-aasEnvironment.mcpEnabled" -}}
{{- if .Values.aasEnvironment.enabled -}}
{{- include "basyx.runtimeEnv.isTrue" (include "basyx-aasEnvironment.mcpSetting" (dict "root" . "key" "enabled" "name" "MCP_ENABLED")) -}}
{{- end -}}
{{- end }}

{{/*
Return "true" when the MCP endpoint requires tokens: with ABAC, BaSyx Go
verifies them and serves the protected resource metadata.
*/}}
{{- define "basyx-aasEnvironment.mcpAuthEnabled" -}}
{{- if and (include "basyx-aasEnvironment.mcpEnabled" .) (include "basyx.abac.effectiveEnabled" (dict "root" . "component" "aasEnvironment" "values" .Values.aasEnvironment)) -}}
true
{{- end -}}
{{- end }}

{{/*
Path of the MCP endpoint, <context path><MCP path>.
*/}}
{{- define "basyx-aasEnvironment.mcpEndpointPath" -}}
{{- $mcpPath := include "basyx-aasEnvironment.mcpSetting" (dict "root" . "key" "path" "name" "MCP_PATH") | default "/mcp" -}}
{{- printf "%s%s" (regexReplaceAll "/+$" .Values.paths.aasEnvironment "") $mcpPath -}}
{{- end }}

{{/*
Path of the RFC 9728 protected resource metadata that BaSyx Go serves for the
MCP endpoint, /.well-known/oauth-protected-resource<context path><MCP path>.
Empty unless the endpoint requires tokens.
*/}}
{{- define "basyx-aasEnvironment.mcpMetadataPath" -}}
{{- if include "basyx-aasEnvironment.mcpAuthEnabled" . -}}
{{- printf "/.well-known/oauth-protected-resource%s" (include "basyx-aasEnvironment.mcpEndpointPath" .) -}}
{{- end -}}
{{- end }}

{{/*
The issuers of the AAS Environment trust list, as a JSON list.
*/}}
{{- define "basyx-aasEnvironment.trustListEntries" -}}
{{- $entries := list -}}
{{- range (include "basyx.abac.trustList" (dict "root" . "component" "aasEnvironment") | fromJsonArray) -}}
{{- if kindIs "map" . -}}
{{- $entries = append $entries . -}}
{{- end -}}
{{- end -}}
{{- toJson $entries -}}
{{- end }}

{{/*
BaSyx Go does not start MCP with ABAC unless every issuer of the trust list has
an audience. Fail at render time instead when the chart mounts the trust list.
*/}}
{{- define "basyx-aasEnvironment.mcpValidate" -}}
{{- if and (include "basyx-aasEnvironment.mcpEnabled" .) (eq (include "basyx.abac.enabled" (dict "root" . "component" "aasEnvironment")) "true") -}}
{{- range (include "basyx-aasEnvironment.trustListEntries" . | fromJsonArray) -}}
{{- if not (trim (toString (.audience | default ""))) -}}
{{- fail (printf "aasEnvironment.mcp: issuer %q of the AAS Environment trust list has no audience; MCP with ABAC requires one for every issuer" (toString .issuer)) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Audience that the MCP client scope of the chart-managed Keycloak adds to access
tokens. Empty unless the AAS Environment trust list contains the issuer of the
chart-managed realm with an audience; keycloak.issuer is not considered, because
the initialization Job always configures the chart-managed realm. The audience
is keycloak.initialization.mcp.audience when set, otherwise the audience of that
trust list entry.
*/}}
{{- define "basyx-aasEnvironment.mcpKeycloakAudience" -}}
{{- $issuer := include "basyx.keycloakManagedIssuer" . | trimSuffix "/" -}}
{{- $trusted := "" -}}
{{- range (include "basyx-aasEnvironment.trustListEntries" . | fromJsonArray) -}}
{{- if eq (toString .issuer | trimSuffix "/") $issuer -}}
{{- $trusted = trim (toString (.audience | default "")) -}}
{{- end -}}
{{- end -}}
{{- if $trusted -}}
{{- trim (dig "mcp" "audience" "" $.Values.keycloak.initialization) | default $trusted -}}
{{- end -}}
{{- end }}

{{/*
MCP settings of the chart-managed Keycloak realm, as JSON for the
initialization Job; {} unless the MCP endpoint requires tokens and an audience
for Keycloak tokens is known. The client scope gives clients that register
themselves the protocol mappers of the Web UI client and the audience of the
AAS Environment. The registration policies replace the config of the anonymous
policies of the same provider.
*/}}
{{- define "basyx-aasEnvironment.mcpKeycloakConfig" -}}
{{- $audience := "" -}}
{{- if and .Values.keycloak.enabled (include "basyx-aasEnvironment.mcpAuthEnabled" .) -}}
{{- $audience = include "basyx-aasEnvironment.mcpKeycloakAudience" . -}}
{{- end -}}
{{- if $audience -}}
{{- $mcp := .Values.keycloak.initialization.mcp -}}
{{- $audienceMapper := dict
  "name" "aas-environment-audience"
  "protocol" "openid-connect"
  "protocolMapper" "oidc-audience-mapper"
  "consentRequired" false
  "config" (dict
    "included.custom.audience" $audience
    "access.token.claim" "true"
    "introspection.token.claim" "true"
    "id.token.claim" "false"
    "lightweight.claim" "false"
    "userinfo.token.claim" "false") -}}
{{- $trustedHosts := dict
  "name" "Trusted Hosts"
  "providerId" "trusted-hosts"
  "config" (dict
    "trusted-hosts" ($mcp.trustedHosts | default list)
    "host-sending-registration-request-must-match" (list "false")
    "client-uris-must-match" (list "true")) -}}
{{- $allowedClientScopes := dict
  "name" "Allowed Client Scopes"
  "providerId" "allowed-client-templates"
  "config" (dict
    "allow-default-scopes" (list "true")
    "allowed-client-scopes" ($mcp.allowedClientScopes | default list)) -}}
{{- toJson (dict
  "clientScope" (dict
    "name" $mcp.clientScope
    "protocol" "openid-connect"
    "attributes" (dict
      "include.in.token.scope" "true"
      "display.on.consent.screen" "true"
      "consent.screen.text" "Access the BaSyx AAS Environment")
    "protocolMappers" (append (include "basyx.webUiClientProtocolMappers" . | fromJsonArray) $audienceMapper))
  "registrationPolicies" (list $trustedHosts $allowedClientScopes)) -}}
{{- else -}}
{}
{{- end -}}
{{- end }}
