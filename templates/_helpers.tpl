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
Environment Policy Helpers
These functions enforce stricter policies for production environments
*/}}

{{/*
Check if the current environment is production
Recognizes: prod, production, prd
*/}}
{{- define "my-app-chart.isProduction" -}}
{{- $env := default "dev" .Values.environment | lower -}}
{{- if or (eq $env "prod") (eq $env "production") (eq $env "prd") -}}
{{- true -}}
{{- else -}}
{{- false -}}
{{- end -}}
{{- end -}}

{{/*
Enforce minimum replicas based on environment
Production: minimum 2, Dev/Staging: minimum 1
*/}}
{{- define "my-app-chart.enforceReplicas" -}}
{{- $isProd := include "my-app-chart.isProduction" . -}}
{{- $replicas := .Values.app.replicas | int -}}
{{- if $isProd -}}
{{- if lt $replicas 2 -}}
{{- fail (printf "Production environment requires at least 2 replicas, got %d" $replicas) -}}
{{- end -}}
{{- end -}}
{{- $replicas -}}
{{- end -}}

{{/*
Validate image tag - production cannot use 'latest' tag
*/}}
{{- define "my-app-chart.validateImageTag" -}}
{{- $isProd := include "my-app-chart.isProduction" . -}}
{{- $tag := .Values.app.image.tag | default "" -}}
{{- if $isProd -}}
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
{{- if $isProd -}}
{{- if not .Values.app.resources.limits -}}
{{- fail "Production environment requires resource limits to be set" -}}
{{- end -}}
{{- if not .Values.app.resources.limits.cpu -}}
{{- fail "Production environment requires CPU limit to be set" -}}
{{- end -}}
{{- if not .Values.app.resources.limits.memory -}}
{{- fail "Production environment requires memory limit to be set" -}}
{{- end -}}
{{- if not .Values.app.resources.requests -}}
{{- fail "Production environment requires resource requests to be set" -}}
{{- end -}}
{{- if not .Values.app.resources.requests.cpu -}}
{{- fail "Production environment requires CPU request to be set" -}}
{{- end -}}
{{- if not .Values.app.resources.requests.memory -}}
{{- fail "Production environment requires memory request to be set" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get security context for production
Production enforces non-root user and read-only root filesystem
*/}}
{{- define "my-app-chart.getSecurityContext" -}}
{{- $isProd := include "my-app-chart.isProduction" . -}}
{{- if $isProd -}}
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
{{- else if .Values.app.securityContext -}}
securityContext:
{{- toYaml .Values.app.securityContext | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
Get container security context
*/}}
{{- define "my-app-chart.getContainerSecurityContext" -}}
{{- $isProd := include "my-app-chart.isProduction" . -}}
{{- if $isProd -}}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
{{- else if .Values.app.containerSecurityContext -}}
securityContext:
{{- toYaml .Values.app.containerSecurityContext | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
Validate production readiness - ensure probes are configured
*/}}
{{- define "my-app-chart.validateProbes" -}}
{{- $isProd := include "my-app-chart.isProduction" . -}}
{{- if $isProd -}}
{{- if not .Values.app.readinessProbe -}}
{{- fail "Production environment requires readinessProbe to be configured" -}}
{{- end -}}
{{- if not .Values.app.livenessProbe -}}
{{- fail "Production environment requires livenessProbe to be configured" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get namespace with environment suffix
*/}}
{{- define "my-app-chart.namespace" -}}
{{- printf "%s-%s" .Values.namespace.name .Values.environment }}
{{- end -}}

