# NovaPulse Monitoring: Multi-Stage Build & Network Optimization

## Company Background

**Company:** NovaPulse Monitoring  
**Industry:** DevOps / Infrastructure Observability  
**Scale:** Early-stage startup (60 employees)

NovaPulse builds a lightweight agent that collects system metrics from customer infrastructure and ships them to a central aggregation backend. The agent is written in Go. Deployment speed and image size are critical — the agent is installed on hundreds of customer nodes and pulled on every update.

---

## The Incident

A DevOps engineer shipped the initial Dockerfile for the `pulse-agent` service. The image was built successfully, passed smoke tests, and was pushed to the registry. During a rollout to 300 customer nodes, the operations team noticed:

- Pull times were 4–6x longer than the target SLA
- The deployed image contained the full Go toolchain, source code, and build cache
- The container was running as `root`
- The application binary and a static config file needed to be available inside the container but the config was missing at runtime
- The container was supposed to join a pre-existing bridge network called `novapulse-net` on startup but was connecting to the default bridge instead

A review identified that the Dockerfile was a single-stage build with no optimization, incorrect network configuration, missing non-root user setup, and a missing `COPY` instruction for the config file.

**Business impact:**
- 300-node rollout took 47 minutes instead of the target 8 minutes
- Security audit flagged root-running containers across all customer nodes
- Config file absence caused silent metric collection failures on 40% of nodes
- On-call rotation triggered at 2 AM for an issue that was entirely preventable

---

## Environment

The following files are present in `/home/user/pulse-agent/`:

```
/home/user/pulse-agent/
├── main.go          # Go source — do not modify
├── go.mod           # Go module file — do not modify  
├── config.yaml      # Static agent config — must be present in the final image
└── Dockerfile       # You must rewrite this entirely
```

**Go build commands for reference** (you do not need to know Go):

**Build and Binary Requirements**

1. Download dependencies using `go mod download`.
2. Build the static binary using `CGO_ENABLED=0 GOOS=linux go build -o pulse-agent .`.
3. The build output binary must be `./pulse-agent`.
4. The final binary must be placed at `/app/pulse-agent` inside the container.
5. The configuration file must be placed at `/app/config.yaml` inside the container.


**Success Criteria**

- The Dockerfile must use at least two stages where the first stage builds the binary and the final stage is the runtime image.
- The build stage must use the base image `golang:1.21-alpine`.
- The final stage must use the base image `alpine:3.19`.
- The final image must not contain the Go toolchain, meaning the `go` binary must not exist in the final image.
- The binary must be built using `CGO_ENABLED=0 GOOS=linux`.
- The compiled binary must exist at `/app/pulse-agent` in the final image and must be copied from the build stage.
- The file `config.yaml` must exist at `/app/config.yaml` in the final image and must be copied from the build context.
- The container must run as a non-root user and a user named `pulse` must exist and be used as the running user.
- The built image must be tagged `pulse-agent:latest`.
- A container named `pulse-agent` must be running from the image `pulse-agent:latest`.
- The container must be connected to the `novapulse-net` bridge network and must not run only on the default bridge network.


The final binary must be placed at `/app/pulse-agent` inside the container.  
The config file must be placed at `/app/config.yaml` inside the container.

**Docker network:**

A bridge network named `novapulse-net` already exists on the host. The container must be connected to this network when it runs. You do not need to create the network — it will be created by the setup script.

---

## Your Task

Rewrite the Dockerfile at `/home/user/pulse-agent/Dockerfile` to produce a correctly optimized, secure, production-ready image. Then run the container correctly.

---

## Success Criteria

```markdown
| # | Requirement | Constraint |
|---|-------------|------------|
| 1 | Dockerfile uses at least 2 stages | First stage builds the binary; final stage is the runtime image |
| 2 | Build stage uses `golang:1.21-alpine` as base | Exact image tag required |
| 3 | Final stage uses `alpine:3.19` as base | Exact image tag required — not `golang`, not `scratch`, not `ubuntu` |
| 4 | Final image does not contain the Go toolchain | `go` binary must not exist in the final image |
| 5 | Binary is built with `CGO_ENABLED=0 GOOS=linux` | Required for a static binary that runs on Alpine |
| 6 | Binary is present at `/app/pulse-agent` in the final image | Copied from the build stage |
| 7 | `config.yaml` is present at `/app/config.yaml` in the final image | Copied from the build context |
| 8 | Container runs as a non-root user | A user named `pulse` must exist and be set as the running user |
| 9 | Image is tagged `pulse-agent:latest` | Exact tag required |
| 10 | A container named `pulse-agent` is running from image `pulse-agent:latest` | Container must be in `running` state |
| 11 | Container is connected to the `novapulse-net` bridge network | Must not be on only the default bridge |
```
---

## Background Knowledge

**Multi-stage builds**
A multi-stage Dockerfile uses multiple `FROM` instructions. Earlier stages handle compilation and produce artifacts. The final stage starts from a clean base image and copies only what is needed — the compiled binary, config files, certificates. The Go toolchain, source code, and build cache never make it into the final image. This is the standard pattern for Go services.

**Static binaries and Alpine**
Go can compile fully static binaries that have no shared library dependencies by setting `CGO_ENABLED=0`. Combined with `GOOS=linux`, the resulting binary runs on any Linux image including minimal ones like Alpine. Without `CGO_ENABLED=0`, the binary may link against glibc and fail to start on Alpine, which uses musl.

**Non-root containers**
Running containers as root means a process escape gives an attacker root on the host (in misconfigured environments). The standard mitigation is to create a dedicated user in the Dockerfile and switch to it with the `USER` instruction before the entrypoint. Most security benchmarks (CIS, PCI-DSS) require this.

**Docker bridge networks**
By default, `docker run` connects a container to the built-in `bridge` network. To connect to a named user-defined network, the `--network` flag must be passed at run time. User-defined bridge networks provide automatic DNS resolution between containers by container name — the default bridge does not.

**WORKDIR**
Setting `WORKDIR /app` in the final stage ensures the binary and config land in `/app`, the working directory is set correctly for the entrypoint, and there is no ambiguity about relative paths inside the container.