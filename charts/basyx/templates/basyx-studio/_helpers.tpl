{{/*
Helpers of the BaSyx Studio component (basyxStudio).
*/}}

{{- define "basyx-studio.fullname" -}}
{{- printf "%s-studio" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-studio.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-studio.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-studio.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "basyx-studio"
{{- end }}

{{- define "basyx-studio.serviceAccountName" -}}
{{- if .Values.basyxStudio.serviceAccount.create }}
{{- default (include "basyx-studio.fullname" .) .Values.basyxStudio.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.basyxStudio.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-studio.secretName" -}}
{{- include "basyx-studio.fullname" . -}}
{{- end }}

{{- define "basyx-studio.infrastructuresConfigMapName" -}}
{{- printf "%s-infrastructures" (include "basyx-studio.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "basyx-studio.secretsMountPath" -}}
/run/secrets/basyx-studio
{{- end }}

{{- define "basyx-studio.infrastructuresMountPath" -}}
/etc/basyx-studio
{{- end }}

{{/* Whether the release has an identity provider: the chart-managed Keycloak or an external issuer. */}}
{{- define "basyx-studio.identityProvider" -}}
{{- if or .Values.keycloak.enabled .Values.keycloak.issuer -}}
true
{{- end -}}
{{- end }}

{{/* STUDIO_AUTH_MODE: the configured mode, else oidc with an identity provider and none without. */}}
{{- define "basyx-studio.authMode" -}}
{{- if .Values.basyxStudio.auth.mode -}}
{{- .Values.basyxStudio.auth.mode -}}
{{- else if include "basyx-studio.identityProvider" . -}}
oidc
{{- else -}}
none
{{- end -}}
{{- end }}

{{/* STUDIO_OIDC_ISSUER: the configured issuer, else the issuer of the BaSyx services. */}}
{{- define "basyx-studio.oidcIssuer" -}}
{{- if .Values.basyxStudio.auth.oidc.issuer -}}
{{- tpl (toString .Values.basyxStudio.auth.oidc.issuer) . -}}
{{- else -}}
{{- include "basyx.oidcIssuer" . -}}
{{- end -}}
{{- end }}

{{/*
paths.basyxStudio normalized like the image's launcher does: "/" or "/a/b/".
studio, /studio and /studio/ are the same.
*/}}
{{- define "basyx-studio.basePath" -}}
{{- $segments := list -}}
{{- range splitList "/" (toString (.Values.paths.basyxStudio | default "/")) -}}
{{- if . -}}
{{- if or (not (regexMatch "^[A-Za-z0-9_.~-]+$" .)) (eq . ".") (eq . "..") -}}
{{- fail (printf "paths.basyxStudio must be a plain URL path such as /studio, got %q" $.Values.paths.basyxStudio) -}}
{{- end -}}
{{- $segments = append $segments . -}}
{{- end -}}
{{- end -}}
{{- if $segments -}}
{{- printf "/%s/" (join "/" $segments) -}}
{{- else -}}
/
{{- end -}}
{{- end }}

{{/* The base path without its trailing slash, as in STUDIO_BASE_PATH: "/" or "/a/b". */}}
{{- define "basyx-studio.basePathPrefix" -}}
{{- $basePath := include "basyx-studio.basePath" . -}}
{{- if eq $basePath "/" -}}
/
{{- else -}}
{{- trimSuffix "/" $basePath -}}
{{- end -}}
{{- end }}

{{/*
STUDIO_PUBLIC_URL without a trailing slash: basyxStudio.publicUrl, whose path
must equal the base path, or https://<host><paths.basyxStudio>.
*/}}
{{- define "basyx-studio.publicUrl" -}}
{{- $prefix := include "basyx-studio.basePathPrefix" . -}}
{{- $suffix := ternary "" $prefix (eq $prefix "/") -}}
{{- if .Values.basyxStudio.publicUrl -}}
{{- $url := tpl (toString .Values.basyxStudio.publicUrl) . | trimSuffix "/" -}}
{{- $parsed := urlParse $url -}}
{{- if not (has $parsed.scheme (list "http" "https")) -}}
{{- fail (printf "basyxStudio.publicUrl must be an http(s) URL, got %q" .Values.basyxStudio.publicUrl) -}}
{{- end -}}
{{- if ne (trimSuffix "/" (default "" $parsed.path)) $suffix -}}
{{- fail (printf "the path of basyxStudio.publicUrl (%q) must equal paths.basyxStudio (%q)" .Values.basyxStudio.publicUrl $prefix) -}}
{{- end -}}
{{- $url -}}
{{- else -}}
{{- printf "https://%s%s" (tpl (toString .Values.host) .) $suffix -}}
{{- end -}}
{{- end }}

{{/*
STUDIO_APPS_URL: basyxStudio.apps.url without a trailing slash, or nothing.
One shared origin (https://apps.example.org) or one origin per installation
with {installation} as the first label of the host
(https://{installation}.apps.example.org).
*/}}
{{- define "basyx-studio.appsUrl" -}}
{{- with .Values.basyxStudio.apps.url -}}
{{- $url := tpl (toString .) $ | trimSuffix "/" -}}
{{- $example := "use an http(s) origin such as https://apps.example.org, or https://{installation}.apps.example.org for one origin per installation" -}}
{{- if and (contains "{" $url) (not (regexMatch "^https?://\\{installation\\}\\.[^/{}]+(/[^{}]*)?$" $url)) -}}
{{- fail (printf "basyxStudio.apps.url may name {installation} only as the first label of its host, got %q; %s" $url $example) -}}
{{- end -}}
{{- $parsed := urlParse (replace "{installation}" "installation" $url) -}}
{{- if or (not (has $parsed.scheme (list "http" "https"))) (not $parsed.hostname) -}}
{{- fail (printf "basyxStudio.apps.url must be an http(s) origin, got %q; %s" $url $example) -}}
{{- end -}}
{{- $url -}}
{{- end -}}
{{- end }}

{{/*
Host the Ingress and HTTPRoute route to Studio for apps: the host of
basyxStudio.apps.url, or the wildcard *.apps.example.org for
https://{installation}.apps.example.org.
*/}}
{{- define "basyx-studio.appsHost" -}}
{{- with include "basyx-studio.appsUrl" . -}}
{{- $hostname := (urlParse (replace "{installation}" "installation" .)).hostname -}}
{{- if contains "{installation}" . -}}
{{- printf "*.%s" (trimPrefix "installation." $hostname) -}}
{{- else -}}
{{- $hostname -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
The suffix is kept for long release names, so the name never collides with
the infrastructures ConfigMap: 44 characters of the fullname and
"-trusted-publishers" fit into 63.
*/}}
{{- define "basyx-studio.trustedPublishersConfigMapName" -}}
{{- printf "%s-trusted-publishers" (include "basyx-studio.fullname" . | trunc 44 | trimSuffix "-") -}}
{{- end }}

{{- define "basyx-studio.trustedPublishersMountPath" -}}
/etc/basyx-studio-trust
{{- end }}

{{/* The trust store of basyxStudio.apps.trustedPublishers.publishers, or nothing. */}}
{{- define "basyx-studio.trustedPublishersFile" -}}
{{- with .Values.basyxStudio.apps.trustedPublishers.publishers -}}
{{- toYaml (dict "version" 1 "publishers" (fromYamlArray (tpl (toYaml .) $))) -}}
{{- end -}}
{{- end }}

{{/* Whether a trust store is mounted (STUDIO_APPS_TRUSTED_PUBLISHERS). */}}
{{- define "basyx-studio.trustedPublishersEnabled" -}}
{{- $trust := .Values.basyxStudio.apps.trustedPublishers -}}
{{- if or $trust.existingConfigMap $trust.publishers -}}
true
{{- end -}}
{{- end }}

{{- define "basyx-studio.downloadedPackagesPath" -}}
/opt/basyx-studio/downloaded-packages
{{- end }}

{{- define "basyx-studio.mountedPackagesPath" -}}
/opt/basyx-studio/packages
{{- end }}

{{- define "basyx-studio.packageHeadersPath" -}}
/run/secrets/basyx-studio-packages
{{- end }}

{{/* Whether a download sends request headers from a Secret. */}}
{{- define "basyx-studio.packageHeadersEnabled" -}}
{{- range .Values.basyxStudio.apps.packages.download -}}
{{- if .headersSecret -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{/* Whether packages are mounted from an existing claim or volume. */}}
{{- define "basyx-studio.mountedPackagesEnabled" -}}
{{- $packages := .Values.basyxStudio.apps.packages -}}
{{- if or $packages.existingClaim $packages.volume -}}
true
{{- end -}}
{{- end }}

{{/*
STUDIO_APP_PACKAGES: the downloaded packages and the directory of mounted
ones, comma-separated, or nothing.
*/}}
{{- define "basyx-studio.appPackages" -}}
{{- $root := . -}}
{{- $paths := list -}}
{{- range .Values.basyxStudio.apps.packages.download -}}
{{- $paths = append $paths (printf "%s/%s.zip" (include "basyx-studio.downloadedPackagesPath" $root) .name) -}}
{{- end -}}
{{- if include "basyx-studio.mountedPackagesEnabled" . -}}
{{- $paths = append $paths (include "basyx-studio.mountedPackagesPath" .) -}}
{{- end -}}
{{- join "," $paths -}}
{{- end }}

{{/*
Script of the init container that downloads basyxStudio.apps.packages.download
into an emptyDir. URLs, files, header files and digests come from the
container's environment, so no value becomes part of the script. A failed
download or a wrong digest stops the pod from starting; Studio would
otherwise uninstall the managed app.
*/}}
{{- define "basyx-studio.downloadPackagesScript" -}}
set -eu
# fetch <url> <file> <header file or ""> <sha256 or "">
fetch() {
  url=$1 target=$2 headers=$3 sha256=$4
  set -- --fail --silent --show-error --location --proto =http,https --proto-redir =https --retry 3 --connect-timeout 30 --output "$target.part"
  if [ -n "$headers" ]; then
    set -- "$@" --header "@$headers"
  fi
  curl -q "$@" "$url"
  if [ -n "$sha256" ] && ! echo "$sha256  $target.part" | sha256sum -c - >/dev/null; then
    echo "$target: the SHA-256 digest is not $sha256" >&2
    exit 1
  fi
  mv "$target.part" "$target"
  echo "downloaded $target"
}
{{- range $index, $package := .Values.basyxStudio.apps.packages.download }}
fetch "$PACKAGE_{{ $index }}_URL" "$PACKAGE_{{ $index }}_FILE" "$PACKAGE_{{ $index }}_HEADERS" "$PACKAGE_{{ $index }}_SHA256"
{{- if $package.signatureUrl }}
fetch "$PACKAGE_{{ $index }}_SIGNATURE_URL" "$PACKAGE_{{ $index }}_FILE.sig" "$PACKAGE_{{ $index }}_HEADERS" ""
{{- end }}
{{- end }}
{{- end }}

{{/*
Whether the chart renders the Studio Secret: the data key, unless an existing
Secret holds it, or an inline value. A key without dataKey.value or
dataKey.existingSecret is generated once and reused through lookup, which
needs Helm's access to the cluster; renders without it (Argo CD, helm
template) produce a new key each time, so validate rejects them with
argocd.enabled.
*/}}
{{- define "basyx-studio.createSecret" -}}
{{- $studio := .Values.basyxStudio -}}
{{- if or (not $studio.dataKey.existingSecret) (include "basyx-studio.inlineOidcClientSecret" .) (and $studio.database.url (not $studio.database.existingSecret)) -}}
true
{{- end -}}
{{- end }}

{{/* Whether an OIDC client secret is mounted. */}}
{{- define "basyx-studio.oidcClientSecretEnabled" -}}
{{- $secret := .Values.basyxStudio.auth.oidc.clientSecret -}}
{{- if and (eq (include "basyx-studio.authMode" .) "oidc") (or $secret.existingSecret $secret.value) -}}
true
{{- end -}}
{{- end }}

{{/* Whether the OIDC client secret is stored in the Studio Secret. */}}
{{- define "basyx-studio.inlineOidcClientSecret" -}}
{{- $secret := .Values.basyxStudio.auth.oidc.clientSecret -}}
{{- if and (eq (include "basyx-studio.authMode" .) "oidc") $secret.value (not $secret.existingSecret) -}}
true
{{- end -}}
{{- end }}

{{/* Whether a database URL is configured. */}}
{{- define "basyx-studio.databaseEnabled" -}}
{{- if or .Values.basyxStudio.database.existingSecret .Values.basyxStudio.database.url -}}
true
{{- end -}}
{{- end }}

{{/*
The infrastructure for the services of this release, as a YAML map, or
nothing when it is disabled or the enabled services fit no Studio template.
Endpoints use the public URLs https://<host><paths.*> the chart routes, like
the Web UI's infrastructure. The Digital Twin Registry stands in for the AAS
registry and discovery when those are disabled. Separate repositories or
registries give "full"; otherwise the AAS Environment gives "mono-repo" with
registries or discovery and "mono-all" without.
*/}}
{{- define "basyx-studio.derivedInfrastructure" -}}
{{- $root := . -}}
{{- $derived := .Values.basyxStudio.infrastructures.derived -}}
{{- if $derived.enabled -}}
{{- $services := dict "aasRegistry" "aasRegistry" "submodelRegistry" "submodelRegistry" "aasDiscovery" "aasDiscovery" "aasRepository" "aasRepository" "submodelRepository" "submodelRepository" "conceptDescriptionRepository" "cdRepository" -}}
{{- $urls := dict -}}
{{- range $type, $service := $services -}}
{{- if (index $root.Values $service).enabled -}}
{{- $_ := set $urls $type (printf "https://%s%s" $root.Values.host (index $root.Values.paths $service) | trimSuffix "/") -}}
{{- end -}}
{{- end -}}
{{- /* The Digital Twin Registry serves the AAS registry and discovery APIs where the release has none of its own. */ -}}
{{- if .Values.digitalTwinRegistry.enabled -}}
{{- $dtr := printf "https://%s%s" .Values.host .Values.paths.digitalTwinRegistry | trimSuffix "/" -}}
{{- range $type := list "aasRegistry" "aasDiscovery" -}}
{{- if not (hasKey $urls $type) -}}
{{- $_ := set $urls $type $dtr -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $template := "" -}}
{{- $types := list -}}
{{- $repositories := or (hasKey $urls "aasRepository") (hasKey $urls "submodelRepository") (hasKey $urls "conceptDescriptionRepository") -}}
{{- $full := and (or (hasKey $urls "aasRepository") (hasKey $urls "aasRegistry")) (or (hasKey $urls "submodelRepository") (hasKey $urls "submodelRegistry")) -}}
{{- if and $full (or $repositories (not .Values.aasEnvironment.enabled)) -}}
{{- $template = "full" -}}
{{- $types = list "aasRegistry" "submodelRegistry" "aasDiscovery" "aasRepository" "submodelRepository" "conceptDescriptionRepository" -}}
{{- else if .Values.aasEnvironment.enabled -}}
{{- $_ := set $urls "aasEnvironment" (printf "https://%s%s" .Values.host .Values.paths.aasEnvironment | trimSuffix "/") -}}
{{- if or (hasKey $urls "aasRegistry") (hasKey $urls "submodelRegistry") (hasKey $urls "aasDiscovery") -}}
{{- $template = "mono-repo" -}}
{{- $types = list "aasEnvironment" "aasRegistry" "submodelRegistry" "aasDiscovery" -}}
{{- else -}}
{{- $template = "mono-all" -}}
{{- $types = list "aasEnvironment" -}}
{{- end -}}
{{- end -}}
{{- if $template -}}
{{- $endpoints := list -}}
{{- range $type := $types -}}
{{- if hasKey $urls $type -}}
{{- $endpoints = append $endpoints (dict "type" $type "url" (get $urls $type)) -}}
{{- end -}}
{{- end -}}
{{- /* The shell list comes from the AAS registry where one serves it. */ -}}
{{- $listSource := ternary "registry" "repository" (or (hasKey $urls "aasRegistry") (eq $template "mono-all")) -}}
{{- $securityMode := $derived.securityMode | default (ternary "delegated_user" "unsecured" (eq (include "basyx-studio.identityProvider" .) "true")) -}}
{{- $security := dict "mode" $securityMode -}}
{{- if eq $securityMode "delegated_user" -}}
{{- $security = dict "mode" $securityMode "issuer" (include "basyx.oidcIssuer" .) "clientId" .Values.basyxStudio.auth.oidc.clientId "scopes" (list "openid" "profile") -}}
{{- end -}}
{{- $entry := dict "key" $derived.key "name" (tpl (toString $derived.name) .) "template" $template "endpoints" $endpoints "listSource" $listSource "security" $security "allowPrivateNetwork" true -}}
{{- with $derived.connections -}}
{{- $_ := set $entry "connections" (fromYamlArray (tpl (toYaml .) $root)) -}}
{{- end -}}
{{- with $derived.apps -}}
{{- $_ := set $entry "apps" (fromYamlArray (tpl (toYaml .) $root)) -}}
{{- end -}}
{{- toYaml $entry -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/* The infrastructure file: the derived entry and basyxStudio.infrastructures.declared, or nothing. */}}
{{- define "basyx-studio.infrastructuresFile" -}}
{{- $entries := list -}}
{{- with include "basyx-studio.derivedInfrastructure" . -}}
{{- $entries = append $entries (fromYaml .) -}}
{{- end -}}
{{- with .Values.basyxStudio.infrastructures.declared -}}
{{- $entries = concat $entries (fromYamlArray (tpl (toYaml .) $)) -}}
{{- end -}}
{{- if $entries -}}
{{- toYaml (dict "version" 1 "infrastructures" $entries) -}}
{{- end -}}
{{- end }}

{{/* Whether an infrastructure file is mounted. */}}
{{- define "basyx-studio.infrastructuresEnabled" -}}
{{- if or .Values.basyxStudio.infrastructures.existingConfigMap (include "basyx-studio.infrastructuresFile" .) -}}
true
{{- end -}}
{{- end }}

{{/* Whether the chart adds the Studio client to the chart-managed Keycloak realm. */}}
{{- define "basyx-studio.keycloakClientEnabled" -}}
{{- $studio := .Values.basyxStudio -}}
{{- if and $studio.enabled .Values.keycloak.enabled $studio.keycloakClient.create $studio.auth.oidc.clientId -}}
true
{{- end -}}
{{- end }}

{{/*
The Studio client of the chart-managed realm, as JSON: a public client with
PKCE and the Studio redirect URIs, a mapper of the realm roles to the "roles"
ID token claim, and the protocol mappers of the Web UI client, so the tokens
Studio sends to the BaSyx services carry the same claims as the Web UI's.
*/}}
{{- define "basyx-studio.keycloakClient" -}}
{{- $root := . -}}
{{- $publicUrl := include "basyx-studio.publicUrl" . -}}
{{- $mappers := list (dict
  "name" "Studio Realm Roles"
  "protocol" "openid-connect"
  "protocolMapper" "oidc-usermodel-realm-role-mapper"
  "consentRequired" false
  "config" (dict
    "multivalued" "true"
    "claim.name" "roles"
    "jsonType.label" "String"
    "id.token.claim" "true"
    "access.token.claim" "false"
    "userinfo.token.claim" "true"
    "introspection.token.claim" "false")) -}}
{{- $webUiClientId := include "basyx.webUiClientId" . -}}
{{- range (.Values.keycloak.initialization.clients | default list) -}}
{{- if eq (tpl (toString .clientId) $root) $webUiClientId -}}
{{- $mappers = concat $mappers (.protocolMappers | default list) -}}
{{- end -}}
{{- end -}}
{{- toJson (dict
  "clientId" .Values.basyxStudio.auth.oidc.clientId
  "name" "BaSyx Studio"
  "publicClient" true
  "standardFlowEnabled" true
  "implicitFlowEnabled" false
  "directAccessGrantsEnabled" false
  "redirectUris" (list (printf "%s/api/studio/v1/auth/callback" $publicUrl))
  "attributes" (dict
    "post.logout.redirect.uris" (printf "%s/" $publicUrl)
    "pkce.code.challenge.method" "S256")
  "protocolMappers" $mappers) -}}
{{- end }}

{{/*
Render a container env entry, indented for the deployment, when the value is
set. Large numbers may arrive as float64; render them without an exponent.
*/}}
{{- define "basyx-studio.env" -}}
{{- if or (kindIs "bool" .value) (not (empty .value)) -}}
{{- $value := ternary (printf "%.0f" .value) (toString .value) (kindIs "float64" .value) -}}
{{- printf "- name: %s\n  value: %s" .name ($value | quote) | nindent 12 -}}
{{- end -}}
{{- end }}

{{/* Fail early on settings Studio would reject at startup. */}}
{{- define "basyx-studio.validate" -}}
{{- $studio := .Values.basyxStudio -}}
{{- $mode := include "basyx-studio.authMode" . -}}
{{- if and (eq $mode "oidc") (not $studio.auth.oidc.clientId) -}}
{{- fail "basyxStudio.auth.mode \"oidc\" requires basyxStudio.auth.oidc.clientId; use basyxStudio.auth.mode \"none\" to run without login" -}}
{{- end -}}
{{- if and (eq $mode "oidc") (not $studio.auth.oidc.issuer) (not (include "basyx-studio.identityProvider" .)) -}}
{{- fail "basyxStudio.auth.mode \"oidc\" requires basyxStudio.auth.oidc.issuer, keycloak.issuer or keycloak.enabled" -}}
{{- end -}}
{{- if and (eq ($studio.infrastructures.derived.securityMode | default "") "delegated_user") (not (include "basyx-studio.identityProvider" .)) -}}
{{- fail "basyxStudio.infrastructures.derived.securityMode \"delegated_user\" requires keycloak.issuer or keycloak.enabled" -}}
{{- end -}}
{{- with include "basyx-studio.appsHost" . -}}
{{- $publicHost := (urlParse (include "basyx-studio.publicUrl" $)).hostname -}}
{{- if eq . $publicHost -}}
{{- fail "basyxStudio.apps.url must have another host than the Studio URL" -}}
{{- end -}}
{{- /* The wildcard covers one label, as in the Ingress. */ -}}
{{- if and (hasPrefix "*." .) (eq (trimPrefix "*." .) (join "." (rest (splitList "." $publicHost)))) -}}
{{- fail (printf "basyxStudio.apps.url must not match the Studio host: %s covers %s. Serve apps from another domain, e.g. https://{installation}.apps.example.org next to studio.example.org." . $publicHost) -}}
{{- end -}}
{{- end -}}
{{- $apps := $studio.apps -}}
{{- if and (not $apps.url) (or (include "basyx-studio.trustedPublishersEnabled" .) (include "basyx-studio.appPackages" .)) -}}
{{- fail "basyxStudio.apps.trustedPublishers and basyxStudio.apps.packages need basyxStudio.apps.url: without it, apps are off" -}}
{{- end -}}
{{- if and $apps.trustedPublishers.existingConfigMap $apps.trustedPublishers.publishers -}}
{{- fail "set either basyxStudio.apps.trustedPublishers.publishers or basyxStudio.apps.trustedPublishers.existingConfigMap, not both" -}}
{{- end -}}
{{- if and $apps.packages.existingClaim $apps.packages.volume -}}
{{- fail "set either basyxStudio.apps.packages.existingClaim or basyxStudio.apps.packages.volume, not both" -}}
{{- end -}}
{{- $packageNames := list -}}
{{- range $apps.packages.download -}}
{{- if has .name $packageNames -}}
{{- fail (printf "basyxStudio.apps.packages.download names %q twice; every package needs a name of its own" .name) -}}
{{- end -}}
{{- $packageNames = append $packageNames .name -}}
{{- end -}}
{{- if and .Values.argocd.enabled (not $studio.dataKey.existingSecret) (not $studio.dataKey.value) -}}
{{- fail "basyxStudio with argocd.enabled needs a stable data key: set basyxStudio.dataKey.existingSecret to a Secret provisioned outside the chart, for example with External Secrets or Sealed Secrets. Argo CD renders without access to the cluster, so the chart cannot reuse a generated key and would replace it on every sync." -}}
{{- end -}}
{{- if and $studio.dataKey.existingSecret (eq $studio.dataKey.existingSecret (include "basyx-studio.secretName" .)) (include "basyx-studio.createSecret" .) -}}
{{- fail (printf "basyxStudio.dataKey.existingSecret must not be %q: the chart renders that Secret for the inline OIDC client secret or database URL and would drop the key from it. Store the key in a Secret of another name." (include "basyx-studio.secretName" .)) -}}
{{- end -}}
{{- $derived := $studio.infrastructures.derived -}}
{{- if and (or $derived.connections $derived.apps) (not (include "basyx-studio.derivedInfrastructure" .)) -}}
{{- fail "basyxStudio.infrastructures.derived.connections and .apps need the derived infrastructure: set derived.enabled and enable the BaSyx services it is built from, or declare the infrastructure in basyxStudio.infrastructures.declared" -}}
{{- end -}}
{{- if and $studio.infrastructures.existingConfigMap (or $derived.connections $derived.apps) -}}
{{- fail "basyxStudio.infrastructures.existingConfigMap replaces the derived infrastructure, so derived.connections and derived.apps would be ignored; put them into the ConfigMap instead" -}}
{{- end -}}
{{- if and $studio.infrastructures.existingConfigMap $studio.infrastructures.declared -}}
{{- fail "set either basyxStudio.infrastructures.declared or basyxStudio.infrastructures.existingConfigMap, not both" -}}
{{- end -}}
{{- end }}
