{{- define "satis.release_labels" -}}
app: {{ .Values.app | quote }}
release: {{ .Release.Name }}
{{- end }}

{{- define "satis.domain" -}}
{{ include "satis.environmentName" . }}.{{ .Release.Namespace }}.{{ .Values.clusterDomain }}
{{- end -}}

{{- define "satis.environmentName" -}}
{{ regexReplaceAll "[^[:alnum:]]" (.Values.environmentName | default .Release.Name) "-" | lower | trunc 50 | trimSuffix "-" }}
{{- end -}}

{{- define "satis.referenceEnvironment" -}}
{{ regexReplaceAll "[^[:alnum:]]" .Values.referenceData.referenceEnvironment "-" | lower | trunc 50 | trimSuffix "-" }}
{{- end -}}

{{- define "satis.environment.hostname" -}}
{{ regexReplaceAll "[^[:alnum:]]" (.Values.environmentName | default .Release.Name) "-" | lower | trunc 50 | trimSuffix "-" }}
{{- end -}}

{{- define "satis.satis-container" -}}
image: {{ .Values.satis.image | quote }}
env: {{ include "satis.env" . }}
ports:
  - containerPort: 9000
    name: satis
{{- end }}

{{- define "satis.volumeMounts" -}}
- name: satis-working-dir
  mountPath: /var/satis-server
  subPath: default
- name: satis-server-conf
  mountPath: /etc/satis-server/satis-server.conf
  readOnly: true
  subPath: satis_server_conf
- name: satis-server-conf
  mountPath: /etc/satis/satis.json
  readOnly: true
  subPath: satis_json
{{- end }}

{{- define "satis.volumes" -}}
- name: satis-working-dir
  persistentVolumeClaim:
    claimName: {{ .Release.Name }}-working-dir
- name: satis-server-conf
  configMap:
    name: {{ .Release.Name }}-satis-server-conf
    items:
      - key: satis_server_conf
        path: satis_server_conf
      - key: satis_json
        path: satis_json
{{- end }}

{{- define "satis.env" }}
- name: SILTA_CLUSTER
  value: "1"
- name: DB_HOST
  value: "{{ .Values.composer.gitlab_token }}"
{{- end }}

{{- define "name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 24 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trimSuffix "-app" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "appname" -}}
{{- $releaseName := default .Release.Name .Values.releaseOverride -}}
{{- printf "%s" $releaseName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "trackableappname" -}}
{{- $trackableName := printf "%s-%s" (include "appname" .) .Values.application.track -}}
{{- $trackableName | trimSuffix "-stable" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get a hostname from URL
*/}}
{{- define "hostname" -}}
{{- . | trimPrefix "http://" |  trimPrefix "https://" | trimSuffix "/" | quote -}}
{{- end -}}
