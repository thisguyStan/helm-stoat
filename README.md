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
        # Optional: Leave empty to auto-derive from secretSeed
        encryption_key: ''
      
      livekit:
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
    # namespace: "default"  # optional, defaults to release namespace
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
If a key is missing, Helm falls back to `values.yaml` (or existing derived defaults where applicable).

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
    mongo:  # mongodb
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
      username: 'rabbituser'
      password: 'rabbitpass'
```


---


# Full Configuration

## Global Settings

| Chart Option                                  | Description                                              | Default        |
|-----------------------------------------------|----------------------------------------------------------|----------------|
| `global.namespace`                            | Namespace for the chart services                         | `'stoatchat'`  |
| `global.domain`  **REQUIRED**                 | Domain name used for access (e.g. `stoat.example.com`)   | `''`           |
| `global.secret.vapid_key` **REQUIRED**        | VAPID private key for push notifications                 | `''`           |
| `global.secret.vapid_public_key` **REQUIRED** | VAPID public key for push notifications                  | `''`           |
| `global.secret.encryption_key` **REQUIRED**   | Encryption key for sensitive data                        | `''`           |

### Ports

| Chart Option                                  | Description                                              | Default        |
|-----------------------------------------------|----------------------------------------------------------|----------------|
| `global.web.port`                             | Port for the web frontend                                | `5000`         |
| `global.api.port`                             | Port for the API server                                  | `14702`        |
| `global.bonfire.port`                         | Port for the bonfire events service                      | `14703`        |
| `global.autumn.port`                          | Port for the autumn file server                          | `14704`        |
| `global.january.port`                         | Port for the january metadata proxy                      | `14705`        |
| `global.gifbox.port`                          | Port for the gifbox GIF service                          | `14706`        |

### LiveKit Instances

LiveKit is configured as a list under `global.livekit`. Each entry represents a LiveKit node.

| Chart Option                                  | Description                                              | Default        |
|-----------------------------------------------|----------------------------------------------------------|----------------|
| `global.livekit[].name` **REQUIRED**          | Instance name, also used as the API key                  | `''`           |
| `global.livekit[].secret` **REQUIRED***       | API secret for this instance                             | `''`           |
| `global.livekit[].subdomain` **REQUIRED**     | Subdomain in format `<subdomain>.<global.domain>`        | `''`           |
| `global.livekit[].existingSecret`             | Name of an existing Secret containing `keys.yaml` (e.g. CSI-backed). When set, Helm does not create a secret for this instance. | |
| `global.livekit[].lat`                        | Latitude for geo-routing                                 | `0.0`          |
| `global.livekit[].lon`                        | Longitude for geo-routing                                | `0.0`          |
| `global.livekit[].affinity`                   | Per-instance affinity (merged with `livekit.affinity`)   | `{}`           |
| `global.livekit[].tolerations`                | Per-instance tolerations (appended to `livekit.tolerations`) | `[]`       |

\* `secret` is required only when `existingSecret` is not set.

**Using an existing secret (e.g. Azure Key Vault CSI):**

If you manage secrets externally (e.g. via `SecretProviderClass`), set `existingSecret` to the name of your Kubernetes Secret. The secret must contain a key named `keys.yaml` with content in the format:
```yaml
<instance-name>: <api-secret>
```

When `existingSecret` is set, Helm skips creating a managed secret and mounts the existing one directly.

### Application Configuration

`Revolt.toml` is always generated by Helm and stored in the chart-managed `*-config` Secret.
For supported sensitive fields, values are resolved in this order:
1. key in `global.existingSecret`
2. value in `global.config.*` (or other chart values)
3. chart fallback/default behavior (for fields that have one)

#### Registration

| Chart Option                                           | Description                                   | Default |
|--------------------------------------------------------|-----------------------------------------------|---------|
| `global.config.registration.invite_only`               | Require invite codes for registration         | `false` |

#### SMTP (Email)

Leave `host` empty to disable email verification.

| Chart Option                                           | Description                                   | Default                |
|--------------------------------------------------------|-----------------------------------------------|------------------------|
| `global.config.smtp.host`                              | SMTP server hostname                          | `''`                   |
| `global.config.smtp.username`                          | SMTP username                                 | `''`                   |
| `global.config.smtp.password`                          | SMTP password                                 | `''`                   |
| `global.config.smtp.from_address`                      | Email sender address                          | `'noreply@example.com'`|
| `global.config.smtp.port`                              | SMTP port                                     | _(commented out)_      |
| `global.config.smtp.use_tls`                           | Use TLS for SMTP                              | _(commented out)_      |
| `global.config.smtp.reply_to`                          | Reply-to address                              | _(commented out)_      |

#### Security

| Chart Option                                           | Description                                   | Default |
|--------------------------------------------------------|-----------------------------------------------|---------|
| `global.config.security.trust_cloudflare`              | Enable if behind Cloudflare proxy             | `false` |
| `global.config.security.authifier_shield_key`          | Authifier Shield API key                      | `''`    |
| `global.config.security.tenor_key`                     | Tenor GIF API key                             | `''`    |
| `global.config.security.captcha.hcaptcha_key`          | hCaptcha secret key                           | `''`    |
| `global.config.security.captcha.hcaptcha_sitekey`      | hCaptcha site key                             | `''`    |

#### Features

| Chart Option                                           | Description                                   | Default |
|--------------------------------------------------------|-----------------------------------------------|---------|
| `global.config.features.webhooks_enabled`              | Enable webhook support                        | `false` |
| `global.config.features.mass_mentions_send_notifications` | Send notifications for mass mentions       | `true`  |
| `global.config.features.mass_mentions_enabled`         | Enable mass mentions                          | `true`  |

#### Files

| Chart Option                                           | Description                                   | Default |
|--------------------------------------------------------|-----------------------------------------------|---------|
| `global.config.files.webp_quality`                     | WebP preview quality (1-100)                  | `80.0`  |
| `global.config.files.blocked_mime_types`               | List of blocked MIME types                    | `[]`    |
| `global.config.files.clamd_host`                       | ClamAV antivirus host:port (empty = disabled) | `''`    |

#### LiveKit API Settings

| Chart Option                                           | Description                                   | Default |
|--------------------------------------------------------|-----------------------------------------------|---------|
| `global.config.livekit.call_ring_duration`             | How long to ring devices when calling (seconds) | `30`  |

#### Push Notifications

Leave empty to disable.

**FCM (Firebase Cloud Messaging):**

| Chart Option                                           | Description                                   | Default |
|--------------------------------------------------------|-----------------------------------------------|---------|
| `global.config.pushd.fcm.key_type`                    | Service account key type                      | `''`    |
| `global.config.pushd.fcm.project_id`                  | Firebase project ID                           | `''`    |
| `global.config.pushd.fcm.private_key_id`              | Private key ID                                | `''`    |
| `global.config.pushd.fcm.private_key`                 | Private key (PEM)                             | `''`    |
| `global.config.pushd.fcm.client_email`                | Service account email                         | `''`    |
| `global.config.pushd.fcm.client_id`                   | Client ID                                     | `''`    |
| `global.config.pushd.fcm.auth_uri`                    | Auth URI                                      | `''`    |
| `global.config.pushd.fcm.token_uri`                   | Token URI                                     | `''`    |
| `global.config.pushd.fcm.auth_provider_x509_cert_url` | Auth provider cert URL                        | `''`    |
| `global.config.pushd.fcm.client_x509_cert_url`        | Client cert URL                               | `''`    |

**APN (Apple Push Notifications):**

| Chart Option                                           | Description                                   | Default |
|--------------------------------------------------------|-----------------------------------------------|---------|
| `global.config.pushd.apn.sandbox`                     | Use APN sandbox                               | `false` |
| `global.config.pushd.apn.pkcs8`                       | PKCS8 private key                             | `''`    |
| `global.config.pushd.apn.key_id`                      | APN key ID                                    | `''`    |
| `global.config.pushd.apn.team_id`                     | Apple team ID                                 | `''`    |

#### Sentry

DSNs for error reporting. Leave empty to disable.

| Chart Option                                           | Description                                   | Default |
|--------------------------------------------------------|-----------------------------------------------|---------|
| `global.config.sentry.api`                             | Sentry DSN for API                            | `''`    |
| `global.config.sentry.events`                          | Sentry DSN for events                         | `''`    |
| `global.config.sentry.voice_ingress`                   | Sentry DSN for voice ingress                  | `''`    |
| `global.config.sentry.files`                           | Sentry DSN for file server                    | `''`    |
| `global.config.sentry.proxy`                           | Sentry DSN for proxy                          | `''`    |
| `global.config.sentry.pushd`                           | Sentry DSN for push daemon                    | `''`    |
| `global.config.sentry.crond`                           | Sentry DSN for cron daemon                    | `''`    |
| `global.config.sentry.gifbox`                          | Sentry DSN for gifbox                         | `''`    |

#### Limits

Feature limits control resource usage per user tier. See `values.yaml` for the full structure.

**Global limits:**

| Chart Option                                           | Description                                   | Default    |
|--------------------------------------------------------|-----------------------------------------------|------------|
| `global.config.limits.global.group_size`               | Max group size                                | `100`      |
| `global.config.limits.global.message_embeds`           | Max embeds per message                        | `5`        |
| `global.config.limits.global.message_replies`          | Max replies per message                       | `5`        |
| `global.config.limits.global.message_reactions`        | Max reactions per message                     | `20`       |
| `global.config.limits.global.server_emoji`             | Max emoji per server                          | `100`      |
| `global.config.limits.global.server_roles`             | Max roles per server                          | `200`      |
| `global.config.limits.global.server_channels`          | Max channels per server                       | `200`      |
| `global.config.limits.global.new_user_hours`           | Hours until user is no longer "new"           | `72`       |
| `global.config.limits.global.body_limit_size`          | Max request body size (bytes)                 | `20000000` |

**New user limits** (`global.config.limits.new_user.*`) and **default user limits** (`global.config.limits.default.*`) share the same structure:

| Chart Option (replace `<tier>` with `new_user` or `default`) | Description                        | New User Default | Default |
|---------------------------------------------------------------|------------------------------------|------------------|---------|
| `global.config.limits.<tier>.outgoing_friend_requests`        | Max outgoing friend requests       | `5`              | `10`    |
| `global.config.limits.<tier>.bots`                            | Max bots                           | `2`              | `5`     |
| `global.config.limits.<tier>.message_length`                  | Max message length (chars)         | `2000`           | `2000`  |
| `global.config.limits.<tier>.message_attachments`             | Max attachments per message        | `5`              | `5`     |
| `global.config.limits.<tier>.servers`                         | Max servers                        | `50`             | `100`   |
| `global.config.limits.<tier>.voice_quality`                   | Voice quality (bitrate)            | `16000`          | `16000` |
| `global.config.limits.<tier>.video`                           | Video calls enabled                | `true`           | `true`  |
| `global.config.limits.<tier>.video_resolution`                | Max video resolution [w, h]        | `[1080, 720]`    | `[1080, 720]` |
| `global.config.limits.<tier>.video_aspect_ratio`              | Allowed aspect ratio range [min, max] | `[0.3, 2.5]` | `[0.3, 2.5]` |
| `global.config.limits.<tier>.file_upload_size_limit.attachments` | Max attachment size (bytes)     | `20000000`       | `20000000` |
| `global.config.limits.<tier>.file_upload_size_limit.avatars`     | Max avatar size (bytes)         | `4000000`        | `4000000`  |
| `global.config.limits.<tier>.file_upload_size_limit.backgrounds` | Max background size (bytes)     | `6000000`        | `6000000`  |
| `global.config.limits.<tier>.file_upload_size_limit.icons`       | Max icon size (bytes)           | `2500000`        | `2500000`  |
| `global.config.limits.<tier>.file_upload_size_limit.banners`     | Max banner size (bytes)         | `6000000`        | `6000000`  |
| `global.config.limits.<tier>.file_upload_size_limit.emojis`      | Max emoji size (bytes)          | `500000`         | `500000`   |

### Ingress

| Chart Option                                  | Description                                              | Default        |
|-----------------------------------------------|----------------------------------------------------------|----------------|
| `global.ingress.enabled`                      | Enable Kubernetes Ingress                                | `false`        |
| `global.ingress.className`                    | Ingress class name (e.g. `nginx`)                        | `''`           |
| `global.ingress.annotations`                  | Additional Ingress annotations (map)                     | `{}`           |
| `global.ingress.extra_hosts`                  | Additional hosts for Ingress (list)                      | `[]`           |

### Service Account

| Chart Option                                  | Description                                              | Default        |
|-----------------------------------------------|----------------------------------------------------------|----------------|
| `global.serviceAccount.create`                | Whether to create a Kubernetes service account           | `true`         |
| `global.serviceAccount.automount`             | Automount service account tokens                         | `true`         |
| `global.serviceAccount.annotations`           | Additional annotations for ServiceAccount                | `{}`           |
| `global.serviceAccount.name`                  | ServiceAccount name override                             | `''`           |

### Subcharts

| Chart Option                                  | Description                                              | Default        |
|-----------------------------------------------|----------------------------------------------------------|----------------|
| `global.subcharts.mongodb.enabled`            | Enable built-in MongoDB subchart                         | `true`         |
| `global.subcharts.mongodb.connection_url`     | MongoDB connection string (if using external)            | `''`           |
| `global.subcharts.redis.enabled`              | Enable built-in Redis subchart                           | `true`         |
| `global.subcharts.redis.connection_url`       | Redis connection string (if using external)              | `''`           |
| `global.subcharts.minio.enabled`              | Enable built-in MinIO subchart                           | `true`         |
| `global.subcharts.minio.connection_url`       | MinIO connection string (if using external)              | `''`           |
| `global.subcharts.rabbitmq.enabled`           | Enable built-in RabbitMQ subchart                        | `true`         |
| `global.subcharts.rabbitmq.host`              | RabbitMQ hostname (if using external)                    | `''`           |
| `global.subcharts.rabbitmq.port`              | RabbitMQ port (if using external)                        | `5672`         |
| `global.subcharts.rabbitmq.username`          | RabbitMQ username                                        | `'rabbituser'` |
| `global.subcharts.rabbitmq.password`          | RabbitMQ password                                        | `'rabbitpass'` |


## Subchart Defaults

MongoDB, Redis, MinIO, and RabbitMQ are all subcharts.  Consult their respective documentation for more information.

- MongoDB: https://github.com/bitnami/charts/tree/main/bitnami/mongodb#parameters
- Redis: https://github.com/bitnami/charts/tree/main/bitnami/redis#parameters
- MinIO: https://github.com/bitnami/charts/tree/main/bitnami/minio#parameters
- RabbitMQ: https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq#parameters

Here are some default values for testing of the subcharts.

#### MongoDB

| Config                          | Description                                    | Default     |
|---------------------------------|------------------------------------------------|-------------|
| `mongodb.architecture`          | MongoDB deployment mode                        | standalone  |
| `mongodb.auth.enabled`          | Enable auth                                    | false       |
| `mongodb.persistence.enabled`   | Enable persistence                             | false       |

#### Redis

| Config                              | Description                                    | Default     |
|-------------------------------------|------------------------------------------------|-------------|
| `redis.architecture`                | Redis deployment mode                          | standalone  |
| `redis.auth.enabled`                | Enable auth                                    | false       |
| `redis.master.persistence.enabled`  | Enable persistence for master                  | false       |

#### RabbitMQ

| Config                            | Description                                    | Default         |
|-----------------------------------|------------------------------------------------|-----------------|
| `rabbitmq.replicaCount`           | Number of RabbitMQ replicas                    | 1               |
| `rabbitmq.auth.username`          | RabbitMQ username                              | rabbituser      |
| `rabbitmq.auth.password`          | RabbitMQ password                              | rabbitpass      |
| `rabbitmq.persistence.enabled`    | Enable persistence                             | false           |

#### MinIO

| Config                              | Description                                    | Default         |
|-------------------------------------|------------------------------------------------|-----------------|
| `minio.mode`                        | MinIO deployment mode                          | standalone      |
| `minio.rootUser`                    | MinIO root user                                | minioautumn     |
| `minio.rootPassword`                | MinIO root password                            | minioautumn     |
| `minio.persistence.enabled`         | Enable persistence                             | false           |
| `minio.auth.rootUser`               | MinIO root user for auth section               | minioautumn     |
| `minio.auth.rootPassword`           | MinIO root password for auth section           | minioautumn     |


## Component Images

All service deployments support the following common settings. Replace `<component>` with the service name (e.g. `api`, `bonfire`, `autumn`, etc.):

| Config                                | Description                                        | 
|---------------------------------------|----------------------------------------------------|
| `<component>.image.repository`        | Image repository                                   |
| `<component>.image.tag`               | Image tag                                          |
| `<component>.image.pullPolicy`        | Image pull policy                                  |
| `<component>.replicaCount`            | Number of replicas                                 |
| `<component>.annotations`             | Additional pod annotations                         |
| `<component>.labels`                  | Additional pod labels                              |
| `<component>.nodeSelector`            | Pod nodeSelector                                   |
| `<component>.tolerations`             | Pod tolerations list                               |
| `<component>.affinity`                | Pod affinity                                       |
| `<component>.resources`               | Resource requests and limits                       |
| `<component>.livenessProbe`           | Liveness probe config                              |
| `<component>.readinessProbe`          | Readiness probe config                             |
| `<component>.service.type`            | Service type (where applicable)                    |
| `<component>.extra_volumes`           | Additional pod volumes                             |
| `<component>.extra_volumeMounts`      | Additional pod volumeMounts                        |
| `<component>.configMountPath`         | Config mount path in pod (where applicable)        |

### Default Image Tags

| Service        | Image                                  | Default Tag |
|----------------|----------------------------------------|-------------|
| Web App        | `ghcr.io/YOUR_USERNAME/stoat-for-web`  | `v0.1.0` (requires custom build — see `build/BUILD-IMAGES.md`) |
| API Server     | `ghcr.io/stoatchat/api`                | `v0.11.1`   |
| LiveKit Server | `ghcr.io/stoatchat/livekit-server`     | `v1.9.9`    |
| Bonfire        | `ghcr.io/stoatchat/events`             | `v0.11.1`   |
| Autumn         | `ghcr.io/stoatchat/file-server`        | `v0.11.1`   |
| January        | `ghcr.io/stoatchat/proxy`              | `v0.11.1`   |
| Crond          | `ghcr.io/stoatchat/crond`              | `v0.11.1`   |
| Pushd          | `ghcr.io/stoatchat/pushd`              | `v0.11.1`   |
| Voice Ingress  | `ghcr.io/stoatchat/voice-ingress`      | `v0.11.1`   |
| Gifbox         | `ghcr.io/stoatchat/gifbox`             | `v0.11.1`   |


