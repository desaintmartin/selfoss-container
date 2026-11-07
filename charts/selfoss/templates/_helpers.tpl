{{- define "selfoss.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "selfoss.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if contains (include "selfoss.name" .) .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "selfoss.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "selfoss.selectorLabels" -}}
app.kubernetes.io/name: {{ include "selfoss.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "selfoss.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "selfoss.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "selfoss.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- end }}

{{/* Environment shared by the web and updater containers. */}}
{{- define "selfoss.env" -}}
{{- range $key, $value := .Values.config }}
- name: SELFOSS_{{ $key | upper }}
  value: {{ $value | toString | quote }}
{{- end }}
{{- with .Values.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "selfoss.envFrom" -}}
{{- if .Values.existingSecret }}
envFrom:
  - secretRef:
      name: {{ .Values.existingSecret }}
{{- end }}
{{- end }}
