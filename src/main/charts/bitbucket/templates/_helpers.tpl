{{/*This file contains template snippets used by the other files in this directory.*/}}
{{/*Most of them were generated by the "helm chart create" tool, and then some others added.*/}}

{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "bitbucket.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "bitbucket.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "bitbucket.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
The name of the service account to be used.
If the name is defined in the chart values, then use that,
else if we're creating a new service account then use the name of the Helm release,
else just use the "default" service account.
*/}}
{{- define "bitbucket.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- if .Values.serviceAccount.create -}}
{{- include "bitbucket.fullname" . -}}
{{- else -}}
default
{{- end -}}
{{- end -}}
{{- end }}

{{/*
The name of the ClusterRole that will be created.
If the name is defined in the chart values, then use that,
else use the name of the Helm release.
*/}}
{{- define "bitbucket.clusterRoleName" -}}
{{- if .Values.serviceAccount.clusterRole.name }}
{{- .Values.serviceAccount.clusterRole.name }}
{{- else }}
{{- include "bitbucket.fullname" . -}}
{{- end }}
{{- end }}

{{/*
The name of the ClusterRoleBinding that will be created.
If the name is defined in the chart values, then use that,
else use the name of the ClusterRole.
*/}}
{{- define "bitbucket.clusterRoleBindingName" -}}
{{- if .Values.serviceAccount.clusterRoleBinding.name }}
{{- .Values.serviceAccount.clusterRoleBinding.name }}
{{- else }}
{{- include "bitbucket.clusterRoleName" . -}}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "bitbucket.labels" -}}
helm.sh/chart: {{ include "bitbucket.chart" . }}
{{ include "bitbucket.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ with .Values.additionalLabels }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bitbucket.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bitbucket.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "bitbucket.baseUrl" -}}
{{ $httpPortMismatch := (and (eq .Values.bitbucket.proxy.scheme "http") (ne (int .Values.bitbucket.proxy.port) 80) ) -}}
{{ $httpsPortMismatch := (and (eq .Values.bitbucket.proxy.scheme "https") (ne (int .Values.bitbucket.proxy.port) 443) ) -}}
{{ .Values.bitbucket.proxy.scheme }}://{{ .Values.bitbucket.proxy.fqdn -}}
{{ if or $httpPortMismatch $httpsPortMismatch }}:{{ .Values.bitbucket.proxy.port }}{{ end }}
{{- end }}

{{/*
The command that should be run by the nfs-fixer init container to correct the permissions of the shared-home root directory.
*/}}
{{- define "sharedHome.permissionFix.command" -}}
{{- if .Values.volumes.sharedHome.nfsPermissionFixer.command }}
{{ .Values.volumes.sharedHome.nfsPermissionFixer.command }}
{{- else }}
{{- printf "(chgrp %s %s; chmod g+w %s)" .Values.bitbucket.gid .Values.volumes.sharedHome.nfsPermissionFixer.mountPath .Values.volumes.sharedHome.nfsPermissionFixer.mountPath }}
{{- end }}
{{- end }}

{{- define "bitbucket.image" -}}
{{- if .Values.image.registry -}}
{{ .Values.image.registry}}/{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- else -}}
{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- end }}
{{- end }}

{{/*
For each additional library declared, generate a volume mount that injects that library into the Bitbucket lib directory
*/}}
{{- define "bitbucket.additionalLibraries" -}}
{{- range .Values.bitbucket.additionalLibraries -}}
- name: {{ .volumeName }}
  mountPath: "/opt/atlassian/bitbucket/app/WEB-INF/lib/{{ .fileName }}"
  {{- if .subDirectory }}
  subPath: {{ printf "%s/%s" .subDirectory .fileName | quote }}
  {{- else }}
  subPath: {{ .fileName | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
For each additional plugin declared, generate a volume mount that injects that library into the Bitbucket plugins directory
*/}}
{{- define "bitbucket.additionalBundledPlugins" -}}
{{- range .Values.bitbucket.additionalBundledPlugins -}}
- name: {{ .volumeName }}
  mountPath: "/opt/atlassian/bitbucket/app/WEB-INF/atlassian-bundled-plugins/{{ .fileName }}"
  {{- if .subDirectory }}
  subPath: {{ printf "%s/%s" .subDirectory .fileName | quote }}
  {{- else }}
  subPath: {{ .fileName | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "bitbucket.volumes" -}}
{{ if not .Values.volumes.localHome.persistentVolumeClaim.create }}
{{ include "bitbucket.volumes.localHome" . }}
{{- end }}
{{ include "bitbucket.volumes.sharedHome" . }}
{{- with .Values.volumes.additional }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{- define "bitbucket.volumes.localHome" -}}
- name: local-home
{{- if .Values.volumes.localHome.customVolume }}
{{- toYaml .Values.volumes.localHome.customVolume | nindent 2 }}
{{ else }}
  emptyDir: {}
{{- end }}
{{- end }}

{{- define "bitbucket.volumes.sharedHome" -}}
- name: shared-home
{{- if .Values.volumes.sharedHome.customVolume }}
{{- toYaml .Values.volumes.sharedHome.customVolume | nindent 2 }}
{{ else }}
  emptyDir: {}
{{- end }}
{{- end }}

{{- define "bitbucket.volumeClaimTemplates" -}}
{{ if .Values.volumes.localHome.persistentVolumeClaim.create }}
volumeClaimTemplates:
- metadata:
    name: local-home
  spec:
    accessModes: [ "ReadWriteOnce" ]
    {{- if .Values.volumes.localHome.persistentVolumeClaim.storageClassName }}
    storageClassName: {{ .Values.volumes.localHome.persistentVolumeClaim.storageClassName | quote }}
    {{- end }}
    {{- with .Values.volumes.localHome.persistentVolumeClaim.resources }}
    resources:
      {{- toYaml . | nindent 6 }}
    {{- end }}
{{- end }}
{{- end }}