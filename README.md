<p align="center">
  <img width="100" src="https://avatars.githubusercontent.com/u/234249415?s=200&v=4" style="vertical-align: middle; margin: 0 1.5rem" />
  <img src="https://github.com/kubernetes/kubernetes/raw/master/logo/logo.png" width="60" style="vertical-align: middle;" />
</p>

> Currently testing on a k3s cluster with nginx ingress
> PRs welcome. We all want the best possible solution for this.

Inspired also by [baptisterajaut](https://github.com/baptisterajaut/stoatchat-platform)

# Stoat Helm Chart

This chart provides a means of deploying Stoat to kubernetes.

---

# Minimal Setup

To use the minimal setup, you will require

- A working kubernetes cluster
- Persistent storage for MongoDB, Redis, MinIO, and RabbitMQ
- A valid hostname and the ability to access it via HTTPS (such as [cert-manager](https://cert-manager.io/docs/))
- **For voice/video calls**: Node firewall rules allowing UDP port 7882 and TCP port 7881 (or custom ports if configured)

1. Generate VAPID keys for push notifications:
   ```shell
   docker run --entrypoint /bin/ash -v ./:/data alpine/openssl /data/generate_keys.sh
   ```
   **Note**: File encryption and infrastructure passwords are auto-derived. Only VAPID keys need manual generation.

2. Fill out required config:
    ```yaml
    global:
      namespace: 'stoatchat'
      domain: 'stoat.example.com'
      
      # Optional: Master seed for reproducible passwords
      # Generate with: openssl rand -hex 24
      # If empty, passwords are randomly generated on each install
      secretSeed: ''
      
      ingress:
        enabled: true
        className: nginx
        annotations:
          nginx.ingress.kubernetes.io/rewrite-target: /$2
          nginx.ingress.kubernetes.io/force-ssl-redirect: 'true'
          nginx.ingress.kubernetes.io/proxy-body-size: '0'
      
      secret:
        # Required: VAPID keys from generate_keys.sh
        vapid_key: ''
        vapid_public_key: ''
        # Optional: Base64 key decoding to 32 bytes. Leave empty to auto-derive.
        # Legacy 32-char values are auto-converted during config render.
        encryption_key: ''
      
      livekit:
        servers:
        - name: 'worldwide'
          # Optional: Leave empty to auto-derive from secretSeed  
          secret: ''
          subdomain: 'livekit'
    ```

3. Install from the published chart repository:
  ```shell
  helm repo add stoat https://thisguyStan.github.io/helm-stoat
  helm repo update
  helm install stoatchat stoat/stoatchat -f my_values.yaml
  ```
4. Access your instance at your external URL. It may take a few minutes to spin up from scratch.
    
## Secret Management

This chart uses deterministic secret derivation from a single `secretSeed`:

- **Auto-derived secrets** (from `secretSeed`):
  - MongoDB password
  - Redis password  
  - RabbitMQ password
  - MinIO credentials
  - LiveKit API secrets (per instance)
  - File encryption key (if not provided)

- **Must be generated** (cannot be derived):
  - VAPID keypair (requires valid EC keys)

**Benefits:**
- Single seed reproduces all passwords (useful for disaster recovery)
- No credential sprawl
- Easy to rotate (change seed, redeploy)

**Security Note:** Keep `secretSeed` secure. If compromised, all infrastructure passwords are exposed.

### Using External Secrets

**Option 1: Direct value** (simple, less secure)
```yaml
global:
  secretSeed: "a1b2c3d4e5f6..."  # In values.yaml
```

**Option 2: Kubernetes Secret** (recommended for production)
```bash
# Create the secret
kubectl create secret generic stoatchat-master-seed \
  --from-literal=secretSeed="$(openssl rand -hex 24)"

# Optional: add other keys that should override values.yaml
# --from-literal=smtp.username="smtp-user" \
# --from-literal=smtp.password="smtp-pass"

# Reference in values.yaml
global:
  existingSecret:
    name: "stoatchat-master-seed"
    # namespace: "stoatchat"  # optional, must match global.namespace
```

**Option 3: External Secret Operators** (best for production)
```yaml
# Using External Secrets Operator, Sealed Secrets, or Vault
# Create a Secret via your operator, then reference it:
global:
  existingSecret:
    name: "stoatchat-seed-from-vault"
```

Supported key examples in this single secret include `secretSeed`, `smtp.username`, `smtp.password`, `rabbitmq.password`, `minio.access_key_id`, `minio.secret_access_key`, and others used in `Revolt.toml`.
If a key is missing, the pre-install/pre-upgrade render job falls back to `values.yaml` (or derived defaults where applicable) on a per-key basis.

## Production Readiness

The minimal setup is **NOT production ready**:
- No persistence enabled by default (everything lost on restart)
- Infrastructure passwords derived from seed (secure but simple)

## Persistence

Persistence is handled by the subcharts.  Consult the subcharts for more information.

- [MongoDB](https://github.com/bitnami/charts/tree/main/bitnami/mongodb#persistence)
- [Redis](https://github.com/bitnami/charts/tree/main/bitnami/redis#persistence)
- [MinIO](https://github.com/bitnami/charts/tree/main/bitnami/minio#persistence)
- [RabbitMQ](https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq#persistence)

## External Subcharts

The subcharts all support external connections, with the option to disable the built-in chart.
```yaml
global:
  subcharts:
    # All but rabbitmq are full connection+auth strings.
    mongodb:
      enabled: true  # Set to false to use external MongoDB
      connection_url: ''
    redis:
      enabled: true  # Set to false to use external Redis
      connection_url: ''
    minio:
      enabled: true  # Set to false to use external MinIO
      connection_url: ''
    rabbitmq:
      enabled: true  # Set to false to use external RabbitMQ
      host: ''
      port: 5672
```


---


# Full Configuration

This section documents chart values currently used by `charts/stoatchat/values.yaml` and chart templates.

## Global Values

| Chart Option | Description | Default |
|---|---|---|
| `global.namespace` | Namespace for chart resources | `'stoatchat'` |
| `global.domain` | Public base domain (required for ingress/routes) | `'stoat.example.com'` |
| `global.secretSeed` | Master seed used to derive deterministic secrets | `''` |
| `global.existingSecret.name` | Existing Secret name used as first-priority source for supported keys | `''` |
| `global.existingSecret.namespace` | Namespace override for `global.existingSecret` lookup | _(unset)_ |
| `global.secret.vapid_key` | VAPID private key (if empty, generated by job when possible) | `''` |
| `global.secret.vapid_public_key` | VAPID public key (if empty, generated by job when possible) | `''` |
| `global.secret.encryption_key` | File encryption key override (auto-derived when empty) | `''` |

### Service Ports

| Chart Option | Default |
|---|---|
| `global.web.port` | `5000` |
| `global.api.port` | `14702` |
| `global.bonfire.port` | `14703` |
| `global.autumn.port` | `14704` |
| `global.january.port` | `14705` |
| `global.gifbox.port` | `14706` |

### LiveKit Instances (`global.livekit.servers[]`)

| Chart Option | Description | Default |
|---|---|---|
| `name` | Instance name (also used as API key) | `'worldwide'` |
| `secret` | API secret (auto-derived if empty) | `''` |
| `subdomain` | Host prefix for this instance (`<subdomain>.<global.domain>`) | `''` |
| `log_level` | LiveKit log level | `warn` |
| `http_port` | LiveKit HTTP API port | `7880` |
| `rtc_tcp_port` | LiveKit RTC TCP port | `7881` |
| `rtc_udp_port` | LiveKit RTC UDP port | `7882` |
| `existingSecret` | Existing Secret name containing `keys.yaml` (`<instance>: <secret>`) | _(optional)_ |
| `host` | Host mapping key used with external secret formats | _(optional)_ |
| `lat` / `lon` | Geo-routing metadata | _(optional)_ |
| `affinity` | Per-instance affinity (merged with top-level `livekit.affinity`) | `{}` |
| `tolerations` | Per-instance tolerations (concatenated with `livekit.tolerations`) | `[]` |
| `turn.udp_port` | TURN UDP port | `3478` |
| `turn.tls_port` | TURN TLS port (`0` disables) | `0` |
| `turn.external_tls` | TLS terminated upstream of LiveKit | `false` |
| `turn.cert_file` | TURN TLS cert path (when LiveKit terminates TLS) | `''` |
| `turn.key_file` | TURN TLS key path (when LiveKit terminates TLS) | `''` |

## Application Config (`global.config.*`)

`Revolt.toml` is rendered by chart jobs and stored in the chart-managed config Secret.

### Core / Registration / SMTP

| Chart Option | Description | Default |
|---|---|---|
| `global.config.production` | Production mode | `false` |
| `global.config.registration.invite_only` | Restrict registration to invite codes | `false` |
| `global.config.smtp.host` | SMTP host (empty disables email) | `''` |
| `global.config.smtp.username` | SMTP username | `''` |
| `global.config.smtp.password` | SMTP password | `''` |
| `global.config.smtp.from_address` | SMTP sender address | `'noreply@example.com'` |
| `global.config.smtp.port` | SMTP port override | _(commented out)_ |
| `global.config.smtp.use_tls` | SMTP TLS toggle | _(commented out)_ |
| `global.config.smtp.use_starttls` | SMTP STARTTLS toggle | _(commented out)_ |
| `global.config.smtp.reply_to` | SMTP reply-to override | _(commented out)_ |

### Security / Features / Files

| Chart Option | Description | Default |
|---|---|---|
| `global.config.security.trust_cloudflare` | Trust Cloudflare forwarding headers | `false` |
| `global.config.security.authifier_shield_key` | Authifier Shield key | `''` |
| `global.config.security.tenor_key` | Tenor API key | `''` |
| `global.config.security.captcha.hcaptcha_key` | hCaptcha secret | `''` |
| `global.config.security.captcha.hcaptcha_sitekey` | hCaptcha site key | `''` |
| `global.config.features.webhooks_enabled` | Webhooks feature flag | `false` |
| `global.config.features.mass_mentions_send_notifications` | Notify on mass mentions | `true` |
| `global.config.features.mass_mentions_enabled` | Enable mass mentions | `true` |
| `global.config.files.webp_quality` | WebP preview quality | `80.0` |
| `global.config.files.blocked_mime_types` | Blocked MIME list | `[]` |
| `global.config.files.clamd_host` | ClamAV `host:port` | `''` |
| `global.config.files.s3.path_style_buckets` | S3 path-style flag override | _(optional)_ |
| `global.config.files.s3.default_bucket` | Primary upload bucket name | `''` (render fallback: `revolt-upload`) |

### Voice / Push / Sentry

| Chart Option | Description | Default |
|---|---|---|
| `global.config.livekit.call_ring_duration` | Ring duration in seconds | `30` |
| `global.config.pushd.fcm.*` | Firebase service account fields (`key_type`, `project_id`, `private_key_id`, `private_key`, `client_email`, `client_id`, `auth_uri`, `token_uri`, `auth_provider_x509_cert_url`, `client_x509_cert_url`) | all `''` |
| `global.config.pushd.apn.sandbox` | APN sandbox mode | `false` |
| `global.config.pushd.apn.pkcs8` | APN PKCS8 private key | `''` |
| `global.config.pushd.apn.key_id` | APN key id | `''` |
| `global.config.pushd.apn.team_id` | Apple team id | `''` |
| `global.config.sentry.api` | API DSN | `''` |
| `global.config.sentry.events` | Events DSN | `''` |
| `global.config.sentry.voice_ingress` | Voice ingress DSN | `''` |
| `global.config.sentry.files` | File server DSN | `''` |
| `global.config.sentry.proxy` | Proxy DSN | `''` |
| `global.config.sentry.pushd` | Push daemon DSN | `''` |
| `global.config.sentry.crond` | Cron daemon DSN | `''` |
| `global.config.sentry.gifbox` | Gifbox DSN | `''` |

### Limits

`global.config.limits` has three blocks:
- `global` (system-wide caps)
- `new_user`
- `default`

The `new_user` and `default` blocks share this schema:
- `outgoing_friend_requests`
- `bots`
- `message_length`
- `message_attachments`
- `servers`
- `voice_quality`
- `video`
- `video_resolution`
- `video_aspect_ratio`
- `file_upload_size_limit.attachments`
- `file_upload_size_limit.avatars`
- `file_upload_size_limit.backgrounds`
- `file_upload_size_limit.icons`
- `file_upload_size_limit.banners`
- `file_upload_size_limit.emojis`

## Ingress / Service Account / External Backends

| Chart Option | Description | Default |
|---|---|---|
| `global.ingress.enabled` | Enable chart ingress objects | `false` |
| `global.ingress.className` | Ingress class name | `''` |
| `global.ingress.annotations` | Extra ingress annotations | `{}` |
| `global.ingress.extra_hosts` | Reserved extra host list | `[]` |
| `global.serviceAccount.create` | Create dedicated ServiceAccount | `true` |
| `global.serviceAccount.automount` | Automount service account token | `true` |
| `global.serviceAccount.annotations` | ServiceAccount annotations | `{}` |
| `global.serviceAccount.name` | Existing/custom ServiceAccount name | `''` |
| `global.subcharts.mongodb.enabled` | Deploy in-cluster MongoDB | `true` |
| `global.subcharts.mongodb.connection_url` | External MongoDB URL override | `''` |
| `global.subcharts.redis.enabled` | Deploy in-cluster Redis | `true` |
| `global.subcharts.redis.connection_url` | External Redis URL override | `''` |
| `global.subcharts.minio.enabled` | Deploy in-cluster MinIO | `true` |
| `global.subcharts.minio.connection_url` | External S3/MinIO endpoint override | `''` |
| `global.subcharts.minio.access_key_id` | S3 access key override | `''` |
| `global.subcharts.minio.secret_access_key` | S3 secret key override | `''` |
| `global.subcharts.rabbitmq.enabled` | Deploy in-cluster RabbitMQ | `true` |
| `global.subcharts.rabbitmq.host` | External RabbitMQ host override | `''` |
| `global.subcharts.rabbitmq.port` | External RabbitMQ port | `5672` |
| `nameOverride` | Helm name override | _(optional)_ |
| `fullnameOverride` | Helm full name override | _(optional)_ |

## Component Values

### Shared deployment schema

These components share the same deployment schema:
- `web`
- `api`
- `bonfire`
- `autumn`
- `january`
- `crond`
- `pushd`
- `voiceIngress`
- `gifbox`

Common keys:
- `<component>.image.repository`
- `<component>.image.tag`
- `<component>.image.pullPolicy`
- `<component>.replicaCount`
- `<component>.annotations`
- `<component>.labels`
- `<component>.nodeSelector`
- `<component>.tolerations`
- `<component>.affinity`
- `<component>.resources`
- `<component>.livenessProbe`
- `<component>.readinessProbe`
- `<component>.extra_volumes`
- `<component>.extra_volumeMounts`

The template set currently references these expansions directly:
- `web.*`, `api.*`, `bonfire.*`, `autumn.*`, `january.*`, `crond.*`, `pushd.*`, `gifbox.*`

Additional per-component keys:
- `web.service.type`, `web.extraEnv`
- `api.service.type`, `api.configMountPath`
- `bonfire.service.type`, `bonfire.configMountPath`
- `autumn.service.type`, `autumn.configMountPath`
- `january.service.type`, `january.configMountPath`
- `crond.configMountPath`
- `pushd.configMountPath`
- `voiceIngress.service.type`, `voiceIngress.configMountPath`
- `gifbox.enabled`, `gifbox.service.type`, `gifbox.configMountPath`

### LiveKit top-level deployment block (`livekit.*`)

| Chart Option | Description | Default |
|---|---|---|
| `livekit.image.repository` | Image repository | `livekit/livekit-server` |
| `livekit.image.tag` | Image tag | `v1.9.9` |
| `livekit.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `livekit.strategy` | Deployment strategy | `{ type: Recreate }` |
| `livekit.service.type` | Service type | `ClusterIP` |
| `livekit.annotations` / `livekit.labels` | Pod metadata overrides | `{}` |
| `livekit.nodeSelector` / `livekit.tolerations` / `livekit.affinity` | Scheduling controls | `{}` / `[]` / `{}` |
| `livekit.resources` | Resource requests/limits | `{}` |
| `livekit.extra_volumes` / `livekit.extra_volumeMounts` | Extra pod storage config | `[]` / `[]` |

### Pre-install jobs / helpers

| Chart Option | Description | Default |
|---|---|---|
| `createBuckets.enabled` | Run pre-install bucket creation job | `true` |
| `createBuckets.extra_volumes` | Extra volumes for bucket job | `[]` |
| `createBuckets.extra_volumeMounts` | Extra volume mounts for bucket job | `[]` |

## Subchart passthrough defaults

This chart includes MongoDB, Redis, RabbitMQ, and MinIO as dependencies. Most dependency values are passed through unchanged.

Dependency docs:
- MongoDB: https://github.com/bitnami/charts/tree/main/bitnami/mongodb#parameters
- Redis: https://github.com/bitnami/charts/tree/main/bitnami/redis#parameters
- MinIO: https://github.com/bitnami/charts/tree/main/bitnami/minio#parameters
- RabbitMQ: https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq#parameters

Defaults set directly in this chart:

| Config | Default |
|---|---|
| `mongodb.architecture` | `standalone` |
| `mongodb.auth.enabled` | `true` |
| `mongodb.auth.existingSecret` | `''` |
| `mongodb.auth.secretKeys.rootPasswordKey` | `mongodb-root-password` (fallback) |
| `mongodb.persistence.enabled` | `false` |
| `redis.architecture` | `standalone` |
| `redis.auth.enabled` | `true` |
| `redis.auth.existingSecret` | `''` |
| `redis.auth.existingSecretPasswordKey` | `redis-password` |
| `redis.master.persistence.enabled` | `false` |
| `rabbitmq.replicaCount` | `1` |
| `rabbitmq.auth.username` | `rabbituser` |
| `rabbitmq.auth.existingPasswordSecret` | `''` |
| `rabbitmq.persistence.enabled` | `false` |
| `minio.mode` | `standalone` |
| `minio.rootUser` | _(chart default if unset; used as fallback for bucket job)_ |
| `minio.rootPassword` | _(chart default if unset)_ |
| `minio.auth.existingSecret` | `''` |
| `minio.persistence.enabled` | `false` |

## Default Images

| Service | Image | Default Tag |
|---|---|---|
| Web App | `ghcr.io/thisguystan/stoat-for-web` | `video-test` |
| API Server | `ghcr.io/stoatchat/api` | `v0.11.1` |
| LiveKit Server | `livekit/livekit-server` | `v1.9.9` |
| Bonfire | `ghcr.io/stoatchat/events` | `v0.11.1` |
| Autumn | `ghcr.io/stoatchat/file-server` | `v0.11.1` |
| January | `ghcr.io/stoatchat/proxy` | `v0.11.1` |
| Crond | `ghcr.io/stoatchat/crond` | `v0.11.1` |
| Pushd | `ghcr.io/stoatchat/pushd` | `v0.11.1` |
| Voice Ingress | `ghcr.io/stoatchat/voice-ingress` | `v0.11.1` |
| Gifbox | `ghcr.io/stoatchat/gifbox` | `v0.11.1` |


