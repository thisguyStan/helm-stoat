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
Get secret seed from values or existing secret
Returns empty string if neither is provided (causes random generation)
*/}}
{{- define "stoatchat.getSecretSeed" -}}
{{- if .Values.global.secretSeed -}}
  {{- .Values.global.secretSeed -}}
{{- else if .Values.global.existingSecretSeed -}}
  {{- $secret := lookup "v1" "Secret" (default .Release.Namespace .Values.global.existingSecretSeed.namespace) .Values.global.existingSecretSeed.name -}}
  {{- if $secret -}}
    {{- $key := .Values.global.existingSecretSeed.key | default "secretSeed" -}}
    {{- index $secret.data $key | b64dec -}}
  {{- else -}}
    {{- fail (printf "Secret %s not found in namespace %s. Create the secret or provide global.secretSeed directly." .Values.global.existingSecretSeed.name (default .Release.Namespace .Values.global.existingSecretSeed.namespace)) -}}
  {{- end -}}
{{- else -}}
  {{- "" -}}
{{- end -}}
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
  {{- randAlphaNum $length -}}
{{- end -}}
{{- end -}}

{{/*
Get or derive file encryption key
*/}}
{{- define "stoatchat.fileEncryptionKey" -}}
{{- if .Values.global.secret.encryption_key -}}
  {{- .Values.global.secret.encryption_key -}}
{{- else -}}
  {{- include "stoatchat.deriveSecret" (dict "root" . "id" "file-encryption" "length" 32) -}}
{{- end -}}
{{- end -}}

{{/*
Get VAPID private key from user input or from secret
*/}}
{{- define "stoatchat.vapidPrivateKey" -}}
{{- if .Values.global.secret.vapid_key -}}
  {{- .Values.global.secret.vapid_key -}}
{{- else -}}
  {{- $fullName := include "stoatchat.fullname" . -}}
  {{- $secret := lookup "v1" "Secret" .Release.Namespace (printf "%s-vapid" $fullName) -}}
  {{- if $secret -}}
    {{- index $secret.data "private_key" | b64dec -}}
  {{- else -}}
    {{- fail "VAPID keys not found. They will be auto-generated on first install. If upgrading, check the vapid Secret exists." -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get VAPID public key from user input or from secret
*/}}
{{- define "stoatchat.vapidPublicKey" -}}
{{- if .Values.global.secret.vapid_public_key -}}
  {{- .Values.global.secret.vapid_public_key -}}
{{- else -}}
  {{- $fullName := include "stoatchat.fullname" . -}}
  {{- $secret := lookup "v1" "Secret" .Release.Namespace (printf "%s-vapid" $fullName) -}}
  {{- if $secret -}}
    {{- index $secret.data "public_key" | b64dec -}}
  {{- else -}}
    {{- fail "VAPID keys not found. They will be auto-generated on first install. If upgrading, check the vapid Secret exists." -}}
  {{- end -}}
{{- end -}}
{{- end -}}
