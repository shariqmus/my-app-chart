{{/*
Expand the name of the chart.
*/}}
{{- define "my-app-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "my-app-chart.fullname" -}}
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

{{/*
Get namespace - uses app.environment if namespace not explicitly set
*/}}
{{- define "my-app-chart.namespace" -}}
{{- if .Values.namespace }}
{{- .Values.namespace.name }}
{{- else }}
{{- printf "%s-%s" .Values.app.name .Values.app.environment }}
{{- end }}
{{- end }}

{{/*
Environment Policy Helpers
These functions enforce stricter policies for production environments
*/}}

{{/*
Check if the current environment is production
Recognizes: prod, production, prd
*/}}
{{- define "my-app-chart.isProduction" -}}
{{- $env := default "dev" .Values.app.environment | lower -}}
{{- if or (eq $env "prod") (eq $env "production") (eq $env "prd") -}}
{{- true -}}
{{- else -}}
{{- false -}}
{{- end -}}
{{- end -}}

{{/*
Enforce minimum replicas based on environment and policies
*/}}
{{- define "my-app-chart.enforceReplicas" -}}
{{- $isProd := include "my-app-chart.isProduction" . -}}
{{- $replicas := .Values.workload.replicas | int -}}
{{- if eq $isProd "true" -}}
{{- $minReplicas := .Values.policies.production.enforceMinReplicas | default 2 | int -}}
{{- if lt $replicas $minReplicas -}}
{{- fail (printf "Production environment requires at least %d replicas, got %d" $minReplicas $replicas) -}}
{{- end -}}
{{- end -}}
{{- $replicas -}}
{{- end -}}

{{/*
Validate image tag - production cannot use 'latest' tag
*/}}
{{- define "my-app-chart.validateImageTag" -}}
{{- $isProd := include "my-app-chart.isProduction" . -}}
{{- $forbidLatest := .Values.policies.production.forbidLatestTag | default true -}}
{{- if and (eq $isProd "true") $forbidLatest -}}
{{- $tag := .Values.image.tag | default "" -}}
{{- if or (eq $tag "latest") (eq $tag "") -}}
{{- fail "Production environment cannot use 'latest' or empty image tag. Please specify a specific version tag." -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Enforce resource limits in production
*/}}
{{- define "my-app-chart.enforceResourceLimits" -}}
{{- $isProd := include "my-app-chart.isProduction" . -}}
{{- $requireResources := .Values.policies.production.requireResources | default true -}}
{{- if and (eq $isProd "true") $requireResources -}}
{{- if not .Values.containers.main.resources.limits -}}
{{- fail "Production environment requires resource limits to be set" -}}
{{- end -}}
{{- if not .Values.containers.main.resources.limits.cpu -}}
{{- fail "Production environment requires CPU limit to be set" -}}
{{- end -}}
{{- if not .Values.containers.main.resources.limits.memory -}}
{{- fail "Production environment requires memory limit to be set" -}}
{{- end -}}
{{- if not .Values.containers.main.resources.requests -}}
{{- fail "Production environment requires resource requests to be set" -}}
{{- end -}}
{{- if not .Values.containers.main.resources.requests.cpu -}}
{{- fail "Production environment requires CPU request to be set" -}}
{{- end -}}
{{- if not .Values.containers.main.resources.requests.memory -}}
{{- fail "Production environment requires memory request to be set" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get pod security context
*/}}
{{- define "my-app-chart.getPodSecurityContext" -}}
{{- $isProd := include "my-app-chart.isProduction" . -}}
{{- $enforceSecurity := .Values.policies.production.enforceSecurityContext | default true -}}
{{- if and (eq $isProd "true") $enforceSecurity -}}
{{- if not .Values.workload.pod.securityContext -}}
securityContext:
  runAsNonRoot: true
  fsGroup: 1000
{{- else }}
securityContext:
{{- toYaml .Values.workload.pod.securityContext | nindent 2 }}
{{- end -}}
{{- else if .Values.workload.pod.securityContext }}
securityContext:
{{- toYaml .Values.workload.pod.securityContext | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
Get container security context
*/}}
{{- define "my-app-chart.getContainerSecurityContext" -}}
{{- $isProd := include "my-app-chart.isProduction" . -}}
{{- $enforceSecurity := .Values.policies.production.enforceSecurityContext | default true -}}
{{- if and (eq $isProd "true") $enforceSecurity -}}
{{- if not .Values.containers.main.securityContext -}}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
{{- else }}
securityContext:
{{- toYaml .Values.containers.main.securityContext | nindent 2 }}
{{- end -}}
{{- else if .Values.containers.main.securityContext }}
securityContext:
{{- toYaml .Values.containers.main.securityContext | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
Validate production readiness - ensure probes are configured
*/}}
{{- define "my-app-chart.validateProbes" -}}
{{- $isProd := include "my-app-chart.isProduction" . -}}
{{- $requireProbes := .Values.policies.production.requireProbes | default true -}}
{{- if and (eq $isProd "true") $requireProbes -}}
{{- if not .Values.containers.main.probes.readiness -}}
{{- fail "Production environment requires readinessProbe to be configured" -}}
{{- end -}}
{{- if not .Values.containers.main.probes.liveness -}}
{{- fail "Production environment requires livenessProbe to be configured" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get service account name
*/}}
{{- define "my-app-chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.enabled -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-sa" .Values.app.name -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get labels for resources
*/}}
{{- define "my-app-chart.labels" -}}
{{- $labels := dict "app" .Values.app.name -}}
{{- $_ := set $labels "app.kubernetes.io/name" .Values.app.name -}}
{{- $_ := set $labels "app.kubernetes.io/instance" .Release.Name -}}
{{- $_ := set $labels "app.kubernetes.io/version" (.Values.app.version | default .Chart.AppVersion) -}}
{{- $_ := set $labels "app.kubernetes.io/managed-by" .Release.Service -}}
{{- $_ := set $labels "app.kubernetes.io/environment" .Values.app.environment -}}
{{- with .Values.app.labels -}}
{{- range $key, $value := . -}}
{{- $_ := set $labels $key $value -}}
{{- end -}}
{{- end -}}
{{- toYaml $labels -}}
{{- end -}}

{{/*
Get selector labels
*/}}
{{- define "my-app-chart.selectorLabels" -}}
app: {{ .Values.app.name }}
app.kubernetes.io/name: {{ .Values.app.name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
