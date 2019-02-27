{{/*
Below lines from WunderIO
*/}}

{{- define "drupal.release_labels" -}}
app: {{ .Values.app | quote }}
release: {{ .Release.Name }}
{{- end }}

{{- define "drupal.domain" -}}
{{ include "drupal.environmentName" . }}.{{ .Release.Namespace }}.{{ .Values.clusterDomain }}
{{- end -}}

{{- define "drupal.environmentName" -}}
{{ regexReplaceAll "[^[:alnum:]]" (.Values.environmentName | default .Release.Name) "-" | lower | trunc 50 | trimSuffix "-" }}
{{- end -}}

{{- define "drupal.referenceEnvironment" -}}
{{ regexReplaceAll "[^[:alnum:]]" .Values.referenceData.referenceEnvironment "-" | lower | trunc 50 | trimSuffix "-" }}
{{- end -}}

{{- define "drupal.environment.hostname" -}}
{{ regexReplaceAll "[^[:alnum:]]" (.Values.environmentName | default .Release.Name) "-" | lower | trunc 50 | trimSuffix "-" }}
{{- end -}}

{{- define "drupal.php-container" -}}
image: {{ .Values.php.image | quote }}
env: {{ include "drupal.env" . }}
ports:
  - containerPort: 9000
    name: drupal
{{- end }}

{{- define "drupal.volumeMounts" -}}
- name: drupal-public-files
  mountPath: /var/www/html/web/sites/default/files
  subPath: default
{{- if .Values.privateFiles.enabled }}
- name: drupal-private-files
  mountPath: /var/www/html/private
{{- end }}
- name: php-conf
  mountPath: /etc/php7/php.ini
  readOnly: true
  subPath: php_ini
- name: php-conf
  mountPath: /etc/php7/php-fpm.conf
  readOnly: true
  subPath: php-fpm_conf
- name: php-conf
  mountPath: /etc/php7/php-fpm.d/www.conf
  readOnly: true
  subPath: www_conf
- name: idp-conf
  mountPath: /var/www/html/vendor/simplesamlphp/simplesamlphp/config/config.php
  readOnly: true
  subPath: config_php
- name: idp-conf
  mountPath: /var/www/html/vendor/simplesamlphp/simplesamlphp/config/authsources.php
  readOnly: true
  subPath: authsources_php
- name: idp-conf
  mountPath: /var/www/html/vendor/simplesamlphp/simplesamlphp/metadata/saml20-sp-remote.php
  readOnly: true
  subPath: saml20_sp_remote_php
- name: idp-conf
  mountPath: /var/www/html/vendor/simplesamlphp/simplesamlphp/metadata/saml20-idp-hosted.php
  readOnly: true
  subPath: saml20_idp_hosted_php
{{- end }}

{{- define "drupal.volumes" -}}
- name: drupal-public-files
  persistentVolumeClaim:
    claimName: {{ .Release.Name }}-public-files
{{- if .Values.privateFiles.enabled }}
- name: drupal-private-files
  persistentVolumeClaim:
    claimName: {{ .Release.Name }}-private-files
{{- end }}
- name: php-conf
  configMap:
    name: {{ .Release.Name }}-php-conf
    items:
      - key: php_ini
        path: php_ini
      - key: php-fpm_conf
        path: php-fpm_conf
      - key: www_conf
        path: www_conf
- name: idp-conf
  configMap:
    name: {{ .Release.Name }}-idp-conf
    items:
      - key: config_php
        path: config_php
      - key: authsources_php
        path: authsources_php
      - key: saml20_sp_remote_php
        path: saml20_sp_remote_php
      - key: saml20_idp_hosted_php
        path: saml20_idp_hosted_php
{{- end }}

{{- define "drupal.imagePullSecrets" }}
{{- if .Values.imagePullSecrets }}
imagePullSecrets:
{{ .Values.imagePullSecrets | toYaml }}
{{- end }}
{{- end }}

{{- define "drupal.env" }}
- name: SILTA_CLUSTER
  value: "1"
- name: DB_HOST
  value: "{{ .Values.db.host }}"
- name: DB_SIGNET_NAME
  value: "{{ .Values.db.signet.name }}"
- name: DB_SIGNET_USER
  value: "{{ .Values.db.signet.user }}"
- name: DB_SIGNET_PASS
  value: "{{ .Values.db.signet.pass | b64enc }}"
{{- if .Values.memcached.enabled }}
- name: MEMCACHED_HOST
  value: {{ .Release.Name }}-memcached
{{- end }}
{{- if .Values.elasticsearch.enabled }}
- name: ELASTIC_HOST
  value: {{ .Release.Name }}-elastic
{{- end }}
- name: HASH_SALT
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-secrets-drupal
      key: hashsalt
{{- range $key, $val := .Values.php.env }}
- name: {{ $key }}
  value: {{ $val | quote }}
{{- end }}
{{- if .Values.privateFiles.enabled }}
- name: PRIVATE_FILES_PATH
  value: '/var/www/html/private'
{{- end }}
{{- end }}

{{- define "drupal.basicauth" }}
  {{- if .Values.nginx.basicauth.enabled }}
  satisfy any;
  allow 127.0.0.1;
  {{- range .Values.nginx.basicauth.noauthips }}
  allow {{ . }};
  {{- end }}
  deny all;

  auth_basic "Restricted";
  auth_basic_user_file /etc/nginx/.htaccess;
  {{- end }}
{{- end }}

{{- define "drupal.wait-for-db-command" }}
TIME_WAITING=0
  until mysqladmin status --connect_timeout=2 -u $DB_USER -p$DB_PASS -h $DB_HOST --silent; do
  echo "Waiting for database..."; sleep 5
  TIME_WAITING=$((TIME_WAITING+5))

  if [ $TIME_WAITING -gt 90 ]; then
    echo "Database connection timeout"
    exit 1
  fi
done
{{- end }}

{{- define "drupal.wait-for-ref-fs-command" }}
TIME_WAITING=0
until touch /var/www/html/reference-data/_fs-test; do
  echo "Waiting for reference-data fs..."; sleep 2
  TIME_WAITING=$((TIME_WAITING+2))

  if [ $TIME_WAITING -gt 20 ]; then
    echo "Reference data filesystem timeout"
    exit 1
  fi
done
rm /var/www/html/reference-data/_fs-test
{{- end }}

{{- define "drupal.deployment-in-progress-test" -}}
-f /var/www/html/web/sites/default/files/_deployment
{{- end -}}

{{- define "drupal.post-release-command" -}}
set -e

{{- if eq .Values.referenceData.referenceEnvironment .Values.environmentName }}
{{ include "drupal.wait-for-ref-fs-command" . }}
{{- end }}

{{ include "drupal.wait-for-db-command" . }}

{{ if .Release.IsInstall }}
touch /var/www/html/web/sites/default/files/_deployment
{{ .Values.php.postinstall.command}}
rm /var/www/html/web/sites/default/files/_deployment
{{ else }}
{{ .Values.php.postupgrade.command}}
{{ end }}

{{- if and .Values.referenceData.enabled .Values.referenceData.updateAfterDeployment }}
{{- if eq .Values.referenceData.referenceEnvironment .Values.environmentName }}
{{ .Values.referenceData.command }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Below lines from GitLab Auto Devops
*/}}

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
