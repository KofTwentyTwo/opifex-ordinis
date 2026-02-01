# opifex-ordinis

General-purpose CircleCI orb for K8s-based projects. Two pipeline jobs handle the entire CI/CD lifecycle -- build, test, Docker multi-arch (buildx+QEMU), GHCR push, and security scanning. Consuming projects need ~3 lines of config.

## Quick Start

### Node.js
```yaml
version: 2.1
orbs:
  oo: kof22/opifex-ordinis@1
workflows:
  default:
    jobs:
      - oo/node_pipeline:
          context: ghcr
```

### Java/Maven
```yaml
version: 2.1
orbs:
  oo: kof22/opifex-ordinis@1
workflows:
  default:
    jobs:
      - oo/mvn_pipeline:
          context: ghcr
```

## How It Works

Both pipeline jobs run on a **machine executor** (Ubuntu 24.04) with native Docker. They install their runtimes on the machine, build and test the project, then conditionally build and push a multi-arch Docker image to GHCR on deploy branches. The machine executor is required for buildx + QEMU multi-platform builds.

**Branch-aware logic**: Docker push and container scanning only run on deploy branches (default: `main`). This is handled inside the scripts, so consuming projects don't need CircleCI workflow-level `filters`.

### node_pipeline

1. Checkout (full, with tags)
2. Install Node.js
3. `npm ci` (cached via package-lock.json)
4. **Pre-steps** (optional custom steps)
5. Lint, build, test (optional Playwright)
6. Gitleaks + Trivy (deploy branches) -- **fails before publish**
7. Docker buildx multi-arch push (deploy branches only, **last step**)

### mvn_pipeline

1. Checkout (full, with tags)
2. Install Temurin JDK + Maven (optional Node.js)
3. Generate Maven settings.xml
4. **Pre-steps** (optional custom steps)
5. Checkstyle (optional), compile, verify
6. Collect JaCoCo + test results
7. Gitleaks + OWASP + Trivy (deploy branches) -- **fails before publish**
8. Docker buildx multi-arch push (deploy branches only, **last step**)

## Parameters

### node_pipeline

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `node_version` | string | `"22"` | Node.js major version |
| `build_command` | string | `"npm run build"` | Build command |
| `test_command` | string | `"npm test"` | Test command |
| `lint_command` | string | `"npm run lint"` | Lint command |
| `install_playwright` | boolean | `false` | Install Playwright browsers before tests |
| `pre_steps` | steps | `[]` | Custom steps to run before lint/build/test (see [Pre-Steps](#pre-steps)) |
| `image_name` | string | `""` | Docker image name (default: `ghcr.io/<org>/<repo>`) |
| `image_tag` | string | `""` | Docker image tag (default: short SHA) |
| `deploy_branches` | string | `"main"` | Comma-separated branches that trigger Docker push |
| `push_latest` | boolean | `true` | Push `latest` tag on the first deploy branch |
| `docker_platforms` | string | `"linux/amd64,linux/arm64"` | Buildx target platforms |
| `run_security_scan` | boolean | `true` | Run Gitleaks + Trivy |
| `trivy_severity` | string | `"CRITICAL,HIGH"` | Trivy severity filter |
| `resource_class` | string | `"large"` | Machine resource class |

### mvn_pipeline

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `java_version` | string | `"21"` | Temurin JDK version |
| `install_node` | boolean | `false` | Install Node.js (for fullstack projects) |
| `node_version` | string | `"22"` | Node.js version (if `install_node` is true) |
| `maven_args` | string | `""` | Extra Maven arguments |
| `vite_build_mode` | string | `""` | Vite build mode: `"auto"` for branch mapping, specific value, or empty to skip |
| `run_checkstyle` | boolean | `true` | Run Checkstyle validation |
| `pre_steps` | steps | `[]` | Custom steps to run before build (see [Pre-Steps](#pre-steps)) |
| `image_name` | string | `""` | Docker image name (default: `ghcr.io/<org>/<repo>`) |
| `image_tag` | string | `""` | Docker image tag (default: short SHA) |
| `deploy_branches` | string | `"main"` | Comma-separated branches that trigger Docker push |
| `push_latest` | boolean | `true` | Push `latest` tag on the first deploy branch |
| `docker_platforms` | string | `"linux/amd64,linux/arm64"` | Buildx target platforms |
| `run_security_scan` | boolean | `true` | Run Gitleaks + OWASP + Trivy |
| `trivy_severity` | string | `"CRITICAL,HIGH"` | Trivy severity filter |
| `resource_class` | string | `"large"` | Machine resource class |

## Required Contexts

### `ghcr` context (both pipelines)

| Variable | Description |
|----------|-------------|
| `GHCR_USERNAME` | GitHub username |
| `GHCR_TOKEN` | GitHub PAT with `packages:write` scope |

### `ghcr` context (mvn_pipeline, optional)

| Variable | Description |
|----------|-------------|
| `GITHUB_USERNAME` | GitHub username for Maven repository access |
| `GITHUB_TOKEN` | GitHub token for Maven repository access |

### `security` context (mvn_pipeline, recommended)

| Variable | Description |
|----------|-------------|
| `NVD_API_KEY` | NVD API key for OWASP dependency checks (unauthenticated access is rate-limited) |

## Commands

All pipeline steps are exposed as individual commands for custom workflows:

| Command | Description |
|---------|-------------|
| `full_checkout` | Git checkout with full history and tags |
| `install_node` | Install Node.js via NodeSource |
| `install_java` | Install Temurin JDK + Maven (optional Node.js) |
| `node_install` | `npm ci` with caching |
| `node_lint` | Run lint command |
| `node_build` | Run build command |
| `node_test` | Run tests (optional Playwright) |
| `setup_maven_settings` | Generate Maven settings.xml |
| `mvn_checkstyle` | Maven Checkstyle validation |
| `mvn_build` | Maven compile with caching |
| `mvn_verify` | Maven verify with JaCoCo + test results |
| `docker_login_ghcr` | GHCR authentication (standalone) |
| `docker_build_local` | Local Docker build for pre-publish scanning |
| `docker_buildx_push` | Buildx multi-arch build + push |
| `run_gitleaks` | Gitleaks secret detection |
| `run_owasp_dependency_check` | OWASP CVE scanning (Maven) |
| `run_trivy` | Trivy container image scan |
| `collect_security_reports` | Aggregate security reports |
| `set_vite_build_mode` | Set VITE_BUILD_MODE env var (auto or explicit) |

## Vite Build Mode

Fullstack projects with a Vite frontend can use `vite_build_mode: "auto"` to automatically map the branch to a build mode. The first deploy branch (typically `main`) maps to `"production"`, other deploy branches use their branch name, and non-deploy branches default to `"production"`.

```yaml
- oo/mvn_pipeline:
    context: ghcr
    install_node: true
    deploy_branches: "main,develop,staging"
    vite_build_mode: "auto"
    # main -> production, develop -> develop, staging -> staging
```

You can also pass a fixed value (e.g., `vite_build_mode: "production"`) to use the same mode on all branches.

## Pre-Steps

Both pipeline jobs support a `pre_steps` parameter for injecting custom steps after checkout and runtime installation but before the build. Variables exported via `BASH_ENV` are available to all subsequent steps.

```yaml
- oo/mvn_pipeline:
    context: ghcr
    pre_steps:
      - run:
          name: Custom setup
          command: echo "export MY_VAR=value" >> "$BASH_ENV"
```

## Development

```bash
make validate   # Pack + validate the orb
make lint       # yamllint, shellcheck, orb validate
make dev        # Full development workflow
make clean      # Remove generated files
```

### CI Pipeline

Pushes to `develop` auto-publish `kof22/opifex-ordinis@dev:snapshot`. Tags matching `v*.*.*` publish production versions.

### Versioning

Production releases use semver. Include `[minor]` or `[major]` in commit messages to bump accordingly; otherwise defaults to patch.

## License

Apache License 2.0
