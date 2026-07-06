{{/*
Expand the name of the chart.
*/}}
{{- define "basyx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "basyx.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "basyx-keycloak.fullname" -}}
{{- printf "%s-keycloak" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-keycloakInit.fullname" -}}
{{- printf "%s-keycloak-init" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-keycloakInit.configName" -}}
{{- printf "%s-config" (include "basyx-keycloakInit.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-keycloakInit.scriptName" -}}
{{- printf "%s-script" (include "basyx-keycloakInit.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-aasRegistry.fullname" -}}
{{- printf "%s-aas-registry" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-digitalTwinRegistry.fullname" -}}
{{- printf "%s-digital-twin-registry" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-aasRepository.fullname" -}}
{{- printf "%s-aas-repository" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-aasEnvironment.fullname" -}}
{{- printf "%s-aas-environment" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-dppApi.fullname" -}}
{{- printf "%s-dpp-api" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-cdRepository.fullname" -}}
{{- printf "%s-cd-repository" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-companyLookup.fullname" -}}
{{- printf "%s-company-lookup" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-submodelRepository.fullname" -}}
{{- printf "%s-submodel-repository" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-submodelRegistry.fullname" -}}
{{- printf "%s-submodel-registry" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "basyx-aasDiscovery.fullname" -}}
{{- printf "%s-aas-discovery" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

 {{- define "basyx-aasWebGui.fullname" -}}
{{- printf "%s-aas-web-ui" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "basyx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Render an image reference, preferring digest over tag when provided.
*/}}
{{- define "basyx.image" -}}
{{- if .image.digest -}}
{{- printf "%s@%s" .image.repository .image.digest -}}
{{- else -}}
{{- printf "%s:%v" .image.repository (.image.tag | default .root.Chart.AppVersion) -}}
{{- end -}}
{{- end }}

{{/*
Render a common config entry unless the raw environment map explicitly overrides it.
*/}}
{{- define "basyx.commonConfig.entry" -}}
{{- if not (hasKey .common .name) }}
{{ .name }}: {{ tpl (print .value) .root | quote }}
{{- end }}
{{- end }}

{{/*
Render a comma-separated common config entry from a list.
*/}}
{{- define "basyx.commonConfig.listEntry" -}}
{{- if not (hasKey .common .name) }}
{{ .name }}: {{ join "," (default (list) .value) | quote }}
{{- end }}
{{- end }}

{{/*
Render a service-local runtime env entry when the structured service config
explicitly sets it. The raw service environment map remains the escape hatch
and takes precedence.
*/}}
{{- define "basyx.serviceRuntimeEnv.entry" -}}
{{- if and (hasKey .config .key) (not (hasKey .environment .name)) }}
- name: {{ .name }}
  value: {{ tpl (print (get .config .key)) .root | quote }}
{{- end }}
{{- end }}

{{/*
Render a service-local runtime env entry from a list.
*/}}
{{- define "basyx.serviceRuntimeEnv.listEntry" -}}
{{- if and (hasKey .config .key) (not (hasKey .environment .name)) }}
- name: {{ .name }}
  value: {{ join "," (default (list) (get .config .key)) | quote }}
{{- end }}
{{- end }}

{{/*
Render structured BaSyx runtime configuration as environment variables.
The environment.common map remains the escape hatch and takes precedence.
*/}}
{{- define "basyx.commonConfig.runtimeEnv" -}}
{{- $root := . -}}
{{- $common := .Values.environment.common | default dict -}}
{{- $general := .Values.general | default dict -}}
{{- $history := .Values.history | default dict -}}
{{- $evidence := dig "evidence" (dict) $history -}}
{{- $signing := dig "signing" (dict) $evidence -}}
{{- $integrityAnchor := dig "integrityAnchor" (dict) $history -}}
{{- $eventing := .Values.eventing | default dict -}}
{{- $abac := .Values.abac | default dict -}}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "GENERAL_ENABLEIMPLICITCASTS" "value" (dig "enableImplicitCasts" true $general)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "GENERAL_ENABLEDESCRIPTORDEBUG" "value" (dig "enableDescriptorDebug" false $general)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "GENERAL_DISCOVERYINTEGRATION" "value" (dig "discoveryIntegration" false $general)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "GENERAL_ENABLECUSTOMMIDDLEWAREHEADERINJECTION" "value" (dig "enableCustomMiddlewareHeaderInjection" false $general)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "GENERAL_SUPPORTSSINGULARSUPPLEMENTALSEMANTICID" "value" (dig "supportsSingularSupplementalSemanticId" false $general)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "GENERAL_AASREGISTRYINTEGRATION" "value" (dig "aasRegistryIntegration" false $general)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "GENERAL_SUBMODELREGISTRYINTEGRATION" "value" (dig "submodelRegistryIntegration" false $general)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "GENERAL_EXTERNALURL" "value" (dig "externalUrl" "" $general)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "GENERAL_TRUSTPROXYHEADERS" "value" (dig "trustProxyHeaders" false $general)) }}
{{- include "basyx.commonConfig.listEntry" (dict "common" $common "name" "GENERAL_TRUSTEDPROXYCIDRS" "value" (dig "trustedProxyCIDRs" (list) $general)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "GENERAL_UPLOADMAXSIZEBYTES" "value" (dig "uploadMaxSizeBytes" 0 $general)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "GENERAL_BULK_BATCH_LIMIT" "value" (dig "bulkBatchLimit" 1000 $general)) }}
{{- include "basyx.commonConfig.listEntry" (dict "common" $common "name" "GENERAL_AAS_PRECONFIG_PATHS" "value" (dig "aasPreconfigPaths" (list) $general)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "ABAC_POLICY_FILE_IMPORT" "value" (dig "policyFileImport" "" $abac)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "ABAC_POLICY_SCOPE" "value" (dig "policyScope" "" $abac)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "ABAC_MANAGEMENT_API_ENABLED" "value" (dig "managementApi" "enabled" false $abac)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_MODE" "value" (dig "mode" "off" $history)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_RETENTION_DAYS" "value" (dig "retentionDays" 0 $history)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_FULL_SNAPSHOT_INTERVAL" "value" (dig "fullSnapshotInterval" 1 $history)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_IMMUTABILITY" "value" (dig "immutability" "none" $history)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_AUDIT_IDENTITY_MODE" "value" (dig "auditIdentityMode" "none" $history)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_ENABLED" "value" (dig "enabled" false $evidence)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_PROVIDER" "value" (dig "provider" "none" $evidence)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_BUCKET" "value" (dig "bucket" "" $evidence)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_PREFIX" "value" (dig "prefix" "basyx-history-evidence" $evidence)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_REGION" "value" (dig "region" "us-east-1" $evidence)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_ENDPOINT" "value" (dig "endpoint" "" $evidence)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_ACCESS_KEY_ID" "value" (dig "accessKeyId" "" $evidence)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_SECRET_ACCESS_KEY" "value" (dig "secretAccessKey" "" $evidence)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_PATH_STYLE" "value" (dig "pathStyle" false $evidence)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_RETENTION_MODE" "value" (dig "retentionMode" "" $evidence)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_RETENTION_DAYS" "value" (dig "retentionDays" 0 $evidence)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_WRITE_TIMEOUT_SECONDS" "value" (dig "writeTimeoutSeconds" 10 $evidence)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_SIGNING_PRIVATE_KEY_PATH" "value" (dig "privateKeyPath" "" $signing)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_SIGNING_PUBLIC_KEY_PATH" "value" (dig "publicKeyPath" "" $signing)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_EVIDENCE_SIGNING_REQUIRED" "value" (dig "required" false $signing)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_HISTORY_INTEGRITY_ANCHOR_PROVIDER" "value" (dig "provider" "none" $integrityAnchor)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_EVENTING_ENABLED" "value" (dig "enabled" false $eventing)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_EVENTING_FORMAT" "value" (dig "format" "cloudevents" $eventing)) }}
{{- include "basyx.commonConfig.listEntry" (dict "common" $common "name" "BASYX_EVENTING_SINKS" "value" (dig "sinks" (list) $eventing)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_EVENTING_OUTBOX_ENABLED" "value" (dig "outboxEnabled" false $eventing)) }}
{{- include "basyx.commonConfig.entry" (dict "root" $root "common" $common "name" "BASYX_EVENTING_TOPIC_PREFIX" "value" (dig "topicPrefix" "basyx" $eventing)) }}
{{- end }}

{{/*
Render service-local BaSyx runtime overrides as explicit container env values.
*/}}
{{- define "basyx.serviceRuntimeEnv" -}}
{{- $root := .root -}}
{{- $values := .values | default dict -}}
{{- $environment := $values.environment | default dict -}}
{{- $general := $values.general | default dict -}}
{{- $history := $values.history | default dict -}}
{{- $evidence := $history.evidence | default dict -}}
{{- $signing := $evidence.signing | default dict -}}
{{- $integrityAnchor := $history.integrityAnchor | default dict -}}
{{- $eventing := $values.eventing | default dict -}}
{{- $abac := $values.abac | default dict -}}
{{- $abacManagementApi := $abac.managementApi | default dict -}}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $general "key" "enableImplicitCasts" "name" "GENERAL_ENABLEIMPLICITCASTS") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $general "key" "enableDescriptorDebug" "name" "GENERAL_ENABLEDESCRIPTORDEBUG") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $general "key" "discoveryIntegration" "name" "GENERAL_DISCOVERYINTEGRATION") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $general "key" "enableCustomMiddlewareHeaderInjection" "name" "GENERAL_ENABLECUSTOMMIDDLEWAREHEADERINJECTION") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $general "key" "supportsSingularSupplementalSemanticId" "name" "GENERAL_SUPPORTSSINGULARSUPPLEMENTALSEMANTICID") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $general "key" "aasRegistryIntegration" "name" "GENERAL_AASREGISTRYINTEGRATION") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $general "key" "submodelRegistryIntegration" "name" "GENERAL_SUBMODELREGISTRYINTEGRATION") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $general "key" "externalUrl" "name" "GENERAL_EXTERNALURL") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $general "key" "trustProxyHeaders" "name" "GENERAL_TRUSTPROXYHEADERS") }}
{{- include "basyx.serviceRuntimeEnv.listEntry" (dict "environment" $environment "config" $general "key" "trustedProxyCIDRs" "name" "GENERAL_TRUSTEDPROXYCIDRS") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $general "key" "uploadMaxSizeBytes" "name" "GENERAL_UPLOADMAXSIZEBYTES") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $general "key" "bulkBatchLimit" "name" "GENERAL_BULK_BATCH_LIMIT") }}
{{- include "basyx.serviceRuntimeEnv.listEntry" (dict "environment" $environment "config" $general "key" "aasPreconfigPaths" "name" "GENERAL_AAS_PRECONFIG_PATHS") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $abac "key" "policyFileImport" "name" "ABAC_POLICY_FILE_IMPORT") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $abac "key" "policyScope" "name" "ABAC_POLICY_SCOPE") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $abacManagementApi "key" "enabled" "name" "ABAC_MANAGEMENT_API_ENABLED") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $history "key" "mode" "name" "BASYX_HISTORY_MODE") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $history "key" "retentionDays" "name" "BASYX_HISTORY_RETENTION_DAYS") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $history "key" "fullSnapshotInterval" "name" "BASYX_HISTORY_FULL_SNAPSHOT_INTERVAL") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $history "key" "immutability" "name" "BASYX_HISTORY_IMMUTABILITY") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $history "key" "auditIdentityMode" "name" "BASYX_AUDIT_IDENTITY_MODE") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $evidence "key" "enabled" "name" "BASYX_HISTORY_EVIDENCE_ENABLED") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $evidence "key" "provider" "name" "BASYX_HISTORY_EVIDENCE_PROVIDER") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $evidence "key" "bucket" "name" "BASYX_HISTORY_EVIDENCE_BUCKET") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $evidence "key" "prefix" "name" "BASYX_HISTORY_EVIDENCE_PREFIX") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $evidence "key" "region" "name" "BASYX_HISTORY_EVIDENCE_REGION") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $evidence "key" "endpoint" "name" "BASYX_HISTORY_EVIDENCE_ENDPOINT") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $evidence "key" "accessKeyId" "name" "BASYX_HISTORY_EVIDENCE_ACCESS_KEY_ID") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $evidence "key" "secretAccessKey" "name" "BASYX_HISTORY_EVIDENCE_SECRET_ACCESS_KEY") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $evidence "key" "pathStyle" "name" "BASYX_HISTORY_EVIDENCE_PATH_STYLE") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $evidence "key" "retentionMode" "name" "BASYX_HISTORY_EVIDENCE_RETENTION_MODE") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $evidence "key" "retentionDays" "name" "BASYX_HISTORY_EVIDENCE_RETENTION_DAYS") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $evidence "key" "writeTimeoutSeconds" "name" "BASYX_HISTORY_EVIDENCE_WRITE_TIMEOUT_SECONDS") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $signing "key" "privateKeyPath" "name" "BASYX_HISTORY_EVIDENCE_SIGNING_PRIVATE_KEY_PATH") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $signing "key" "publicKeyPath" "name" "BASYX_HISTORY_EVIDENCE_SIGNING_PUBLIC_KEY_PATH") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $signing "key" "required" "name" "BASYX_HISTORY_EVIDENCE_SIGNING_REQUIRED") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $integrityAnchor "key" "provider" "name" "BASYX_HISTORY_INTEGRITY_ANCHOR_PROVIDER") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $eventing "key" "enabled" "name" "BASYX_EVENTING_ENABLED") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $eventing "key" "format" "name" "BASYX_EVENTING_FORMAT") }}
{{- include "basyx.serviceRuntimeEnv.listEntry" (dict "environment" $environment "config" $eventing "key" "sinks" "name" "BASYX_EVENTING_SINKS") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $eventing "key" "outboxEnabled" "name" "BASYX_EVENTING_OUTBOX_ENABLED") }}
{{- include "basyx.serviceRuntimeEnv.entry" (dict "root" $root "environment" $environment "config" $eventing "key" "topicPrefix" "name" "BASYX_EVENTING_TOPIC_PREFIX") }}
{{- end }}

{{/*
Shared deployment template for the BaSyx Go backend services with common database/ABAC wiring.
*/}}
{{- define "basyx.service.deployment" -}}
{{- $root := .root -}}
{{- $values := index $root.Values .component -}}
{{- $abac := dict "root" $root "component" .component "nameSuffix" .nameSuffix -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include .fullnameHelper $root }}
  labels:
    {{- include .labelsHelper $root | nindent 4 }}
spec:
  replicas: {{ $values.replicaCount }}
  selector:
    matchLabels:
      {{- include .selectorLabelsHelper $root | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- with $values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        checksum/common-config: {{ include "common.config.checksum" $root }}
        {{- if eq (include "basyx.abac.enabled" $abac) "true" }}
        checksum/abac-config: {{ include "basyx.abac.checksum" $abac }}
        {{- end }}
      labels:
        {{- include .labelsHelper $root | nindent 8 }}
        {{- with $values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with $values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include .serviceAccountHelper $root }}
      securityContext:
        {{- toYaml $values.podSecurityContext | nindent 8 }}

      containers:
        - name: {{ .containerName }}
          securityContext:
            {{- toYaml $values.securityContext | nindent 12 }}
          image: "{{ include "basyx.image" (dict "root" $root "image" $values.image) }}"
          {{- if $values.command }}
          command:
            {{- toYaml $values.command | nindent 12 }}
          {{- end }}
          {{- if $values.args }}
          args:
            {{- toYaml $values.args | nindent 12 }}
          {{- end }}
          {{- if eq $values.image.tag "SNAPSHOT" }}
          imagePullPolicy: Always
          {{- else }}
          imagePullPolicy: {{ $values.image.pullPolicy }}
          {{- end }}
          ports:
            - name: http
              containerPort: {{ $values.service.port }}
              protocol: TCP
          env:
            {{- include "common-database-config" $root | nindent 12 }}
            - name: SERVER_PORT
              value: {{ $values.service.port | quote }}
            - name: SERVER_CONTEXTPATH
              value: {{ index $root.Values.paths .component | quote }}
            {{- include "basyx.serviceRuntimeEnv" (dict "root" $root "values" $values) | nindent 12 }}
            {{- range $key, $value := $values.environment | default dict }}
            - name: {{ $key }}
              value: {{ tpl (print $value) $root | quote }}
            {{- end }}
            {{- include "basyx.abac.env" $abac | nindent 12 }}
          envFrom:
            - configMapRef:
                name: {{ include .fullnameHelper $root }}-config
            - secretRef:
                name: {{ include "basyx.fullname" $root }}-common-config
          resources:
            {{- toYaml $values.resources | nindent 12 }}
          {{- with $values.livenessProbe }}
          livenessProbe:
            {{- tpl (toYaml .) $root | nindent 12 }}
          {{- end }}
          {{- with $values.readinessProbe }}
          readinessProbe:
            {{- tpl (toYaml .) $root | nindent 12 }}
          {{- end }}
          volumeMounts:
            {{- with $values.volumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
            {{- include "common.certs.volumeMounts" $root | nindent 12 }}
            {{- include "basyx.abac.volumeMounts" $abac | nindent 12 }}
      volumes:
        {{- with $values.volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- include "common.certs.volume" $root | nindent 8 }}
        {{- include "basyx.abac.volume" $abac | nindent 8 }}

      {{- with $values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "basyx.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-keycloak.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-keycloak.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-aasRegistry.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-aasRegistry.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-digitalTwinRegistry.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-digitalTwinRegistry.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-aasRepository.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-aasRepository.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-aasEnvironment.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-aasEnvironment.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-dppApi.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-dppApi.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-cdRepository.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-cdRepository.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-companyLookup.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-companyLookup.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-submodelRepository.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-submodelRepository.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-submodelRegistry.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-submodelRegistry.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-aasDiscovery.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-aasDiscovery.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "basyx-aasWebGui.labels" -}}
helm.sh/chart: {{ include "basyx.chart" . }}
{{ include "basyx-aasWebGui.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "basyx.selectorLabels" -}}
app.kubernetes.io/name: "{{ include "basyx.name" . }}"
app.kubernetes.io/instance: "{{ .Release.Name }}"
{{- end }}

{{- define "basyx-keycloak.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "keycloak"
{{- end }}

{{- define "basyx-aasRegistry.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "aas-registry"
{{- end }}

{{- define "basyx-digitalTwinRegistry.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "digital-twin-registry"
{{- end }}

{{- define "basyx-aasRepository.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "aas-repository"
{{- end }}

{{- define "basyx-aasEnvironment.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "aas-environment"
{{- end }}

{{- define "basyx-dppApi.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "dpp-api"
{{- end }}

{{- define "basyx-cdRepository.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "cd-repository"
{{- end }}

{{- define "basyx-companyLookup.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "company-lookup"
{{- end }}

{{- define "basyx-submodelRepository.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "submodel-repository"
{{- end }}

{{- define "basyx-submodelRegistry.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "submodel-registry"
{{- end }}

{{- define "basyx-aasDiscovery.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "aas-discovery"
{{- end }}

{{- define "basyx-aasWebGui.selectorLabels" -}}
{{ include "basyx.selectorLabels" . }}
app.kubernetes.io/component: "aas-web-ui"
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "basyx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "basyx.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-keycloak.serviceAccountName" -}}
{{- if .Values.keycloak.serviceAccount.create }}
{{- default (include "basyx-keycloak.fullname" .) .Values.keycloak.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.keycloak.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-aasRegistry.serviceAccountName" -}}
{{- if .Values.aasRegistry.serviceAccount.create }}
{{- default (include "basyx-aasRegistry.fullname" .) .Values.aasRegistry.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.aasRegistry.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-digitalTwinRegistry.serviceAccountName" -}}
{{- if .Values.digitalTwinRegistry.serviceAccount.create }}
{{- default (include "basyx-digitalTwinRegistry.fullname" .) .Values.digitalTwinRegistry.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.digitalTwinRegistry.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-aasRepository.serviceAccountName" -}}
{{- if .Values.aasRepository.serviceAccount.create }}
{{- default (include "basyx-aasRepository.fullname" .) .Values.aasRepository.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.aasRepository.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-aasEnvironment.serviceAccountName" -}}
{{- if .Values.aasEnvironment.serviceAccount.create }}
{{- default (include "basyx-aasEnvironment.fullname" .) .Values.aasEnvironment.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.aasEnvironment.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-dppApi.serviceAccountName" -}}
{{- if .Values.dppApi.serviceAccount.create }}
{{- default (include "basyx-dppApi.fullname" .) .Values.dppApi.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.dppApi.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-cdRepository.serviceAccountName" -}}
{{- if .Values.cdRepository.serviceAccount.create }}
{{- default (include "basyx-cdRepository.fullname" .) .Values.cdRepository.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.cdRepository.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-companyLookup.serviceAccountName" -}}
{{- if .Values.companyLookup.serviceAccount.create }}
{{- default (include "basyx-companyLookup.fullname" .) .Values.companyLookup.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.companyLookup.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-submodelRepository.serviceAccountName" -}}
{{- if .Values.submodelRepository.serviceAccount.create }}
{{- default (include "basyx-submodelRepository.fullname" .) .Values.submodelRepository.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.submodelRepository.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-submodelRegistry.serviceAccountName" -}}
{{- if .Values.submodelRegistry.serviceAccount.create }}
{{- default (include "basyx-submodelRegistry.fullname" .) .Values.submodelRegistry.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.submodelRegistry.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-aasDiscovery.serviceAccountName" -}}
{{- if .Values.aasDiscovery.serviceAccount.create }}
{{- default (include "basyx-aasDiscovery.fullname" .) .Values.aasDiscovery.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.aasDiscovery.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "basyx-aasWebGui.serviceAccountName" -}}
{{- if .Values.aasWebGui.serviceAccount.create }}
{{- default (include "basyx-aasWebGui.fullname" .) .Values.aasWebGui.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.aasWebGui.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "database-secret" -}}
{{- printf "%s-app" .Values.database.clusterName  | trunc 63 | trimSuffix "-" }}
{{- end}}

{{/*
Helper to render TLS block if enabled
*/}}
{{- define "common.ingressTLS" -}}
{{- if .Values.tls.enabled }}
tls:
  - hosts:
      {{- range .Values.tls.hosts }}
      - {{ . | quote }}
      {{- end }}
    secretName: {{ .Release.Name }}-tls-secret
{{- end }}
{{- end }}

{{- define "common.ingressTLS.annotations" -}}
  {{- if .Values.tls.enabled }}
  {{- if .Values.ingress.certificateIssuer.enabled }}
  cert-manager.io/issuer: {{ .Values.ingress.certificateIssuer.name | quote }}
  {{- else if .Values.ingress.issuer }}
  cert-manager.io/issuer: {{ .Values.ingress.issuer | quote}}
  {{- else if .Values.ingress.clusterIssuer }}
  cert-manager.io/cluster-issuer: {{ .Values.ingress.clusterIssuer | quote}}
  {{- end }}
  {{- end }}
{{- end }}

{{- define "common.certs.volume" -}}
{{- if $.Values.tls.enabled }}
- name: certs
  secret: 
    secretName: {{ .Values.internal.certificateIssuer.autocreateCaSecretName }}
{{- end }}
{{- if eq (include "common.certs.customEnabled" .) "true" }}
- name: custom-certs
  projected:
    sources:
      {{- if eq (include "common.certs.generatedConfigMapEnabled" .) "true" }}
      - configMap:
          name: {{ include "common.certs.generatedConfigMapName" . }}
      {{- end }}
      {{- range .Values.internal.CACertificates.trustStore.extraSecrets }}
      - secret:
          name: {{ . | quote }}
      {{- end }}
      {{- range .Values.internal.CACertificates.trustStore.extraConfigMaps }}
      - configMap:
          name: {{ . | quote }}
      {{- end }}
{{- end }}
{{- end }}

{{- define "common.certs.volumeMounts" -}} 
{{- if $.Values.tls.enabled }}
- name: certs
  mountPath: /etc/ssl/certs/ca.crt
  subPath: ca.crt
  readOnly: true
{{- end }}
{{- if eq (include "common.certs.customEnabled" .) "true" }}
- name: custom-certs
  mountPath: {{ include "common.certs.customMountPath" . | quote }}
  readOnly: true
{{- end }}
{{- end }}

{{- define "common.certs.customMountPath" -}}
{{- .Values.internal.CACertificates.trustStore.mountPath | default "/etc/ssl/certs/custom" -}}
{{- end }}

{{- define "common.certs.generatedConfigMapName" -}}
{{- printf "%s-custom-ca-certs" (include "basyx.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "common.certs.chartFilesPattern" -}}
{{- $directory := .Values.internal.CACertificates.trustStore.chartFileDirectory | default "" -}}
{{- if $directory -}}
{{- $directory = tpl ($directory | toString) . | trim | trimPrefix "./" | trimPrefix "/" -}}
{{- end -}}
{{- if $directory -}}
{{- printf "%s/*" ($directory | trimSuffix "/") -}}
{{- end -}}
{{- end }}

{{- define "common.certs.generatedConfigMapEnabled" -}}
{{- $inline := .Values.internal.CACertificates.trustStore.additionalCACertificates | default "" -}}
{{- $pattern := include "common.certs.chartFilesPattern" . -}}
{{- $hasFiles := false -}}
{{- if $pattern -}}
{{- $hasFiles = gt (len (.Files.Glob $pattern)) 0 -}}
{{- end -}}
{{- if or $inline $hasFiles -}}true{{- end -}}
{{- end }}

{{- define "common.certs.customEnabled" -}}
{{- $extraSecrets := .Values.internal.CACertificates.trustStore.extraSecrets | default list -}}
{{- $extraConfigMaps := .Values.internal.CACertificates.trustStore.extraConfigMaps | default list -}}
{{- if or (eq (include "common.certs.generatedConfigMapEnabled" .) "true") (gt (len $extraSecrets) 0) (gt (len $extraConfigMaps) 0) -}}true{{- end -}}
{{- end }}

{{- define "common.certs.sslCertDir" -}}
{{- $dirs := list -}}
{{- if .Values.internal.CACertificates.trustStore.useDefaultCAs | default true -}}
{{- $dirs = append $dirs "/etc/ssl/certs" -}}
{{- end -}}
{{- if eq (include "common.certs.customEnabled" .) "true" -}}
{{- $dirs = append $dirs (include "common.certs.customMountPath" .) -}}
{{- end -}}
{{- if eq (len $dirs) 0 -}}
{{- $dirs = append $dirs "/etc/ssl/certs" -}}
{{- end -}}
{{- join ":" $dirs -}}
{{- end }}

{{- define "common.config.checksum" -}}
{{- printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n" (printf "https://%s%s/realms/%s" .Values.host .Values.paths.keycloak .Values.keycloak.realm) (include "common.certs.sslCertDir" .) (toYaml .Values.environment.common) (toYaml .Values.general) (toYaml .Values.history) (toYaml .Values.eventing) (toYaml .Values.abac) | sha256sum -}}
{{- end }}

{{- define "common-database-config" -}}
- name: POSTGRES_PORT
  valueFrom:
    secretKeyRef:
      name: {{ include "database-secret" . }}
      key: port    
- name: POSTGRES_HOST
  valueFrom:
    secretKeyRef:
      name: {{ include "database-secret" . }}
      key: host
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "database-secret" . }}
      key: password
- name: POSTGRES_DBNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "database-secret" . }}
      key: dbname
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "database-secret" . }}
      key: user
{{- end }}

{{- define "basyx.abac.enabled" -}}
{{- $root := .root -}}
{{- $componentValues := get $root.Values .component | default dict -}}
{{- $serviceConfig := get $componentValues "abac" | default dict -}}
{{- $legacyOverrides := $root.Values.abac.services | default dict -}}
{{- $legacyConfig := get $legacyOverrides .component | default dict -}}
{{- if hasKey $serviceConfig "enabled" -}}
{{- $serviceConfig.enabled -}}
{{- else if hasKey $legacyConfig "enabled" -}}
{{- $legacyConfig.enabled -}}
{{- else -}}
{{- $root.Values.abac.enabled | default false -}}
{{- end -}}
{{- end }}

{{- define "basyx.abac.mountPath" -}}
{{- $root := .root -}}
{{- $componentValues := get $root.Values .component | default dict -}}
{{- $serviceConfig := get $componentValues "abac" | default dict -}}
{{- $legacyOverrides := $root.Values.abac.services | default dict -}}
{{- $legacyConfig := get $legacyOverrides .component | default dict -}}
{{- if hasKey $serviceConfig "mountPath" -}}
{{- $serviceConfig.mountPath -}}
{{- else if hasKey $legacyConfig "mountPath" -}}
{{- $legacyConfig.mountPath -}}
{{- else -}}
{{- $root.Values.abac.mountPath | default "/security_env" -}}
{{- end -}}
{{- end }}

{{- define "basyx.abac.accessRulesFileName" -}}
{{- $root := .root -}}
{{- $componentValues := get $root.Values .component | default dict -}}
{{- $serviceConfig := get $componentValues "abac" | default dict -}}
{{- $legacyOverrides := $root.Values.abac.services | default dict -}}
{{- $legacyConfig := get $legacyOverrides .component | default dict -}}
{{- if hasKey $serviceConfig "accessRulesFileName" -}}
{{- $serviceConfig.accessRulesFileName -}}
{{- else if hasKey $legacyConfig "accessRulesFileName" -}}
{{- $legacyConfig.accessRulesFileName -}}
{{- else -}}
{{- $root.Values.abac.accessRulesFileName | default "access-rules.json" -}}
{{- end -}}
{{- end }}

{{- define "basyx.abac.trustListFileName" -}}
{{- $root := .root -}}
{{- $componentValues := get $root.Values .component | default dict -}}
{{- $serviceConfig := get $componentValues "abac" | default dict -}}
{{- $legacyOverrides := $root.Values.abac.services | default dict -}}
{{- $legacyConfig := get $legacyOverrides .component | default dict -}}
{{- if hasKey $serviceConfig "trustListFileName" -}}
{{- $serviceConfig.trustListFileName -}}
{{- else if hasKey $legacyConfig "trustListFileName" -}}
{{- $legacyConfig.trustListFileName -}}
{{- else -}}
{{- $root.Values.abac.trustListFileName | default "trustlist.json" -}}
{{- end -}}
{{- end }}

{{- define "basyx.abac.accessRules" -}}
{{- $root := .root -}}
{{- $componentValues := get $root.Values .component | default dict -}}
{{- $serviceConfig := get $componentValues "abac" | default dict -}}
{{- $legacyOverrides := $root.Values.abac.services | default dict -}}
{{- $legacyConfig := get $legacyOverrides .component | default dict -}}
{{- if hasKey $serviceConfig "accessRules" -}}
{{- tpl ($serviceConfig.accessRules | toString) $root -}}
{{- else if hasKey $legacyConfig "accessRules" -}}
{{- tpl ($legacyConfig.accessRules | toString) $root -}}
{{- else -}}
{{- tpl (($root.Values.abac.accessRules | default "{}") | toString) $root -}}
{{- end -}}
{{- end }}

{{- define "basyx.abac.trustList" -}}
{{- $root := .root -}}
{{- $componentValues := get $root.Values .component | default dict -}}
{{- $serviceConfig := get $componentValues "abac" | default dict -}}
{{- $legacyOverrides := $root.Values.abac.services | default dict -}}
{{- $legacyConfig := get $legacyOverrides .component | default dict -}}
{{- if hasKey $serviceConfig "trustList" -}}
{{- tpl ($serviceConfig.trustList | toString) $root -}}
{{- else if hasKey $legacyConfig "trustList" -}}
{{- tpl ($legacyConfig.trustList | toString) $root -}}
{{- else -}}
{{- tpl (($root.Values.abac.trustList | default "[]") | toString) $root -}}
{{- end -}}
{{- end }}

{{- define "basyx.abac.configMapName" -}}
{{- printf "%s-%s-abac-config" (include "basyx.fullname" .root) .nameSuffix | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "basyx.abac.checksum" -}}
{{- if eq (include "basyx.abac.enabled" .) "true" -}}
{{- printf "%s\n%s\n%s\n%s\n" (include "basyx.abac.mountPath" .) (include "basyx.abac.accessRulesFileName" .) (include "basyx.abac.accessRules" .) (include "basyx.abac.trustList" .) | sha256sum -}}
{{- end -}}
{{- end }}

{{- define "basyx.abac.env" -}}
{{- if eq (include "basyx.abac.enabled" .) "true" }}
- name: ABAC_ENABLED
  value: "true"
- name: ABAC_MODELPATH
  value: {{ printf "%s/%s" (include "basyx.abac.mountPath" .) (include "basyx.abac.accessRulesFileName" .) | quote }}
- name: OIDC_TRUSTLISTPATH
  value: {{ printf "%s/%s" (include "basyx.abac.mountPath" .) (include "basyx.abac.trustListFileName" .) | quote }}
{{- end }}
{{- end }}

{{- define "basyx.abac.volumeMounts" -}}
{{- if eq (include "basyx.abac.enabled" .) "true" }}
- name: abac-config
  mountPath: {{ include "basyx.abac.mountPath" . | quote }}
  readOnly: true
{{- end }}
{{- end }}

{{- define "basyx.abac.volume" -}}
{{- if eq (include "basyx.abac.enabled" .) "true" }}
- name: abac-config
  configMap:
    name: {{ include "basyx.abac.configMapName" . }}
{{- end }}
{{- end }}
