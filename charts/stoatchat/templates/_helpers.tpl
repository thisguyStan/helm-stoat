{{/*
Expand the name of the chart.
*/}}
{{- define "stoatchat.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "stoatchat.fullname" -}}
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
{{- define "stoatchat.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "stoatchat.labels" -}}
helm.sh/chart: {{ include "stoatchat.chart" . }}
{{ include "stoatchat.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "stoatchat.selectorLabels" -}}
app.kubernetes.io/name: {{ include "stoatchat.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "stoatchat.serviceAccountName" -}}
{{- if .Values.global.serviceAccount.create }}
{{- default (include "stoatchat.fullname" .) .Values.global.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.global.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Read a key from global.existingSecret if present, otherwise return fallback.
Usage: {{ include "stoatchat.secretValue" (dict "root" . "key" "smtp.password" "default" .Values.global.config.smtp.password) }}
*/}}
{{- define "stoatchat.secretValue" -}}
{{- $root := .root -}}
{{- $fallback := .default | default "" -}}
{{- if and $root.Values.global.existingSecret $root.Values.global.existingSecret.name -}}
  {{- $namespace := default $root.Values.global.namespace $root.Values.global.existingSecret.namespace -}}
  {{- $secret := lookup "v1" "Secret" $namespace $root.Values.global.existingSecret.name -}}
  {{- if and $secret (hasKey $secret.data .key) -}}
    {{- index $secret.data .key | b64dec -}}
  {{- else -}}
    {{- $fallback -}}
  {{- end -}}
{{- else -}}
  {{- $fallback -}}
{{- end -}}
{{- end -}}

{{/*
Get secret seed from values or existing secret key
Returns empty string if neither is provided (causes random generation)
*/}}
{{- define "stoatchat.getSecretSeed" -}}
{{- include "stoatchat.secretValue" (dict "root" . "key" "secretSeed" "default" .Values.global.secretSeed) -}}
{{- end -}}

{{/*
Derive secret from seed and identifier
Usage: {{ include "stoatchat.deriveSecret" (dict "root" . "id" "identifier" "length" 32) }}
*/}}
{{- define "stoatchat.deriveSecret" -}}
{{- $length := .length | default 32 -}}
{{- $seed := include "stoatchat.getSecretSeed" .root -}}
{{- if $seed -}}
  {{- printf "%s:%s" $seed .id | sha256sum | trunc $length -}}
{{- else -}}
  {{- $namespace := default .root.Release.Namespace .root.Values.global.namespace -}}
  {{- $fullName := include "stoatchat.fullname" .root -}}
  {{- $existing := "" -}}
  {{- if eq .id "mongodb" -}}
    {{- $secret := lookup "v1" "Secret" $namespace (printf "%s-mongodb" $fullName) -}}
    {{- if and $secret (hasKey $secret.data "mongodb-root-password") -}}
      {{- $existing = index $secret.data "mongodb-root-password" | b64dec -}}
    {{- end -}}
  {{- else if eq .id "redis" -}}
    {{- $secret := lookup "v1" "Secret" $namespace (printf "%s-redis" $fullName) -}}
    {{- if and $secret (hasKey $secret.data "redis-password") -}}
      {{- $existing = index $secret.data "redis-password" | b64dec -}}
    {{- end -}}
  {{- else if eq .id "rabbitmq" -}}
    {{- $secret := lookup "v1" "Secret" $namespace (printf "%s-rabbitmq" $fullName) -}}
    {{- if and $secret (hasKey $secret.data "rabbitmq-password") -}}
      {{- $existing = index $secret.data "rabbitmq-password" | b64dec -}}
    {{- end -}}
  {{- else if eq .id "minio-user" -}}
    {{- $secret := lookup "v1" "Secret" $namespace (printf "%s-minio" $fullName) -}}
    {{- if and $secret (hasKey $secret.data "root-user") -}}
      {{- $existing = index $secret.data "root-user" | b64dec -}}
    {{- end -}}
  {{- else if eq .id "minio-pass" -}}
    {{- $secret := lookup "v1" "Secret" $namespace (printf "%s-minio" $fullName) -}}
    {{- if and $secret (hasKey $secret.data "root-password") -}}
      {{- $existing = index $secret.data "root-password" | b64dec -}}
    {{- end -}}
  {{- end -}}

  {{- if $existing -}}
    {{- $existing | trunc $length -}}
  {{- else -}}
    {{- $ns := lookup "v1" "Namespace" "" $namespace -}}
    {{- if $ns -}}
      {{- printf "%s:%s" $ns.metadata.uid .id | sha256sum | trunc $length -}}
    {{- else -}}
      {{- printf "%s:%s:%s" .root.Release.Name $namespace .id | sha256sum | trunc $length -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get or derive file encryption key
*/}}
{{- define "stoatchat.fileEncryptionKey" -}}
{{- $value := include "stoatchat.secretValue" (dict "root" . "key" "encryption_key" "default" .Values.global.secret.encryption_key) -}}
{{- if $value -}}
  {{- $value -}}
{{- else -}}
  {{- include "stoatchat.deriveSecret" (dict "root" . "id" "file-encryption" "length" 32) | b64enc -}}
{{- end -}}
{{- end -}}

{{/*
Get VAPID private key from user input or from secret
*/}}
{{- define "stoatchat.vapidPrivateKey" -}}
{{- $key := include "stoatchat.secretValue" (dict "root" . "key" "vapid_key" "default" .Values.global.secret.vapid_key) -}}
{{- if $key -}}
  {{- $key -}}
{{- else -}}
  {{- $fullName := include "stoatchat.fullname" . -}}
  {{- $namespace := default .Release.Namespace .Values.global.namespace -}}
  {{- $secret := lookup "v1" "Secret" $namespace (printf "%s-vapid" $fullName) -}}
  {{- if $secret -}}
    {{- index $secret.data "private_key" | b64dec -}}
  {{- else -}}
    {{- "" -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get VAPID public key from user input or from secret
*/}}
{{- define "stoatchat.vapidPublicKey" -}}
{{- $key := include "stoatchat.secretValue" (dict "root" . "key" "vapid_public_key" "default" .Values.global.secret.vapid_public_key) -}}
{{- if $key -}}
  {{- $key -}}
{{- else -}}
  {{- $fullName := include "stoatchat.fullname" . -}}
  {{- $namespace := default .Release.Namespace .Values.global.namespace -}}
  {{- $secret := lookup "v1" "Secret" $namespace (printf "%s-vapid" $fullName) -}}
  {{- if $secret -}}
    {{- index $secret.data "public_key" | b64dec -}}
  {{- else -}}
    {{- "" -}}
  {{- end -}}
{{- end -}}
{{- end -}}
