{{/*
Expand the name of the chart.
*/}}
{{- define "axelar-node.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "axelar-node.fullname" -}}
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
{{- define "axelar-node.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "axelar-node.labels" -}}
helm.sh/chart: {{ include "axelar-node.chart" . }}
{{ include "axelar-node.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: axelar
{{- end }}

{{/*
Selector labels
*/}}
{{- define "axelar-node.selectorLabels" -}}
app.kubernetes.io/name: {{ include "axelar-node.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "axelar-node.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "axelar-node.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "axelar-node.secretName" -}}
{{- if .Values.secrets.existingSecret }}
{{- .Values.secrets.existingSecret }}
{{- else }}
{{- include "axelar-node.fullname" . }}-secrets
{{- end }}
{{- end }}

{{/*
Get the chain ID based on network
*/}}
{{- define "axelar-node.chainId" -}}
{{- if eq .Values.network.name "mainnet" }}
{{- "axelar-dojo-1" }}
{{- else if eq .Values.network.name "testnet" }}
{{- "axelar-testnet-lisbon-3" }}
{{- else }}
{{- .Values.network.chainId }}
{{- end }}
{{- end }}

{{/*
Get the namespace based on network
*/}}
{{- define "axelar-node.namespace" -}}
{{- if eq .Values.network.name "mainnet" }}
{{- "axelar-mainnet" }}
{{- else }}
{{- "axelar-testnet" }}
{{- end }}
{{- end }}

{{/*
Create storage class name
*/}}
{{- define "axelar-node.storageClass" -}}
{{- if .Values.global.storageClass }}
{{- .Values.global.storageClass }}
{{- else if .Values.node.storage.storageClass }}
{{- .Values.node.storage.storageClass }}
{{- else }}
{{- "standard" }}
{{- end }}
{{- end }}

{{/*
Create image pull policy
*/}}
{{- define "axelar-node.imagePullPolicy" -}}
{{- .Values.image.pullPolicy | default "IfNotPresent" }}
{{- end }}

{{/*
Create full image name
*/}}
{{- define "axelar-node.image" -}}
{{- if .Values.global.imageRegistry }}
{{- printf "%s/%s/%s:%s" .Values.global.imageRegistry .Values.image.registry .Values.image.repository .Values.image.tag }}
{{- else }}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository .Values.image.tag }}
{{- end }}
{{- end }}

{{/*
Create tofnd image name
*/}}
{{- define "axelar-node.tofndImage" -}}
{{- if .Values.global.imageRegistry }}
{{- printf "%s/%s/%s:%s" .Values.global.imageRegistry .Values.tofndImage.registry .Values.tofndImage.repository .Values.tofndImage.tag }}
{{- else }}
{{- printf "%s/%s:%s" .Values.tofndImage.registry .Values.tofndImage.repository .Values.tofndImage.tag }}
{{- end }}
{{- end }}
