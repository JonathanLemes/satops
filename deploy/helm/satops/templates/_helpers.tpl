{{- define "satops.labels" -}}
app.kubernetes.io/part-of: satops
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "satops.secretName" -}}
{{- if .Values.existingSecret -}}{{ .Values.existingSecret }}{{- else -}}{{ .Release.Name }}-secrets{{- end -}}
{{- end -}}

{{- define "satops.sandboxHosts" -}}
{{- $ns := .Values.sandbox.namespace -}}
{{- $hosts := list -}}
{{- range $i, $_ := until (int .Values.sandbox.bitcoin.replicas) -}}
{{- $hosts = append $hosts (printf "bitcoin-%d.bitcoin.%s.svc.cluster.local" $i $ns) -}}
{{- end -}}
{{- $hosts = append $hosts (printf "demo-fintech.%s.svc.cluster.local" $ns) -}}
{{- join "," $hosts -}}
{{- end -}}

{{- define "satops.apiEnv" -}}
- name: DATABASE_URL
  value: "ecto://satops:$(SATOPS_DB_PASSWORD)@{{ .Release.Name }}-postgres:5432/satops"
- name: SATOPS_DB_PASSWORD
  valueFrom: { secretKeyRef: { name: {{ include "satops.secretName" . }}, key: satopsDbPassword } }
- name: SECRET_KEY_BASE
  valueFrom: { secretKeyRef: { name: {{ include "satops.secretName" . }}, key: secretKeyBase } }
- name: SATOPS_SECRET_KEY
  valueFrom: { secretKeyRef: { name: {{ include "satops.secretName" . }}, key: satopsSecretKey } }
- name: BITCOIN_RPC_PASSWORD
  valueFrom: { secretKeyRef: { name: {{ include "satops.secretName" . }}, key: bitcoinRpcPassword } }
- name: DEMO_FINTECH_API_TOKEN
  valueFrom: { secretKeyRef: { name: {{ include "satops.secretName" . }}, key: demoFintechApiToken } }
- name: DEMO_FINTECH_WEBHOOK_SECRET
  valueFrom: { secretKeyRef: { name: {{ include "satops.secretName" . }}, key: demoFintechWebhookSecret } }
- name: SATOPS_BOOTSTRAP_SECRETS
  value: "bitcoin-rpc=satops:$(BITCOIN_RPC_PASSWORD);demo-fintech-token=$(DEMO_FINTECH_API_TOKEN);demo-fintech-webhook=$(DEMO_FINTECH_WEBHOOK_SECRET)"
- name: SATOPS_ALLOWED_INTEGRATION_HOSTS
  value: {{ include "satops.sandboxHosts" . | quote }}
- name: SATOPS_K8S_SANDBOX_NAMESPACES
  value: {{ .Values.sandbox.namespace | quote }}
- name: SATOPS_RUNTIME
  value: kubernetes
- name: SATOPS_BOOTSTRAP_DIR
  value: /etc/satops/bootstrap
- name: SATOPS_COOKIE_SECURE
  value: {{ .Values.cookieSecure | quote }}
- name: SATOPS_LOG_FORMAT
  value: {{ .Values.logFormat | quote }}
- name: PHX_HOST
  value: localhost
- name: PORT
  value: "4000"
{{- end -}}
