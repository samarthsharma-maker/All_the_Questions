# NovaPulse Monitoring: pulse-agent v2

## Company Background

**Company:** NovaPulse Monitoring  
**Industry:** DevOps / Infrastructure Observability  
**Scale:** Early-stage startup (60 employees)

NovaPulse builds a lightweight metrics agent deployed as a Docker container across hundreds of customer nodes. The previous sprint delivered a working multi-stage build. This sprint's goal is production hardening: correct signal handling, health probing, build-time variable hygiene, and a clean build context.

---

## The Situation

The current Dockerfile at `/home/user/pulse-agent/Dockerfile` is a valid multi-stage build that produces a running image. However it has never been hardened for production. A new set of requirements has been handed to you by the platform lead, and a separate bug report has been filed by the security team.

A container named `pulse-agent-staging` is already running on the host from the current broken image. There may be additional issues with the running container beyond what is documented here — you are expected to investigate it as part of this task.

---

## Environment

All files are at `/home/user/pulse-agent/`:

```
/home/user/pulse-agent/
├── main.go                 # Do not modify
├── go.mod                  # Do not modify
├── healthcheck/
│   └── main.go             # Do not modify
├── config.yaml             # Do not modify
├── .env                    # Local dev secrets
├── tests/
│   └── main_test.go        # Test suite
├── Dockerfile              # Fix and extend
└── .dockerignore           # Fix
```

The application exposes a health endpoint at `http://localhost:8080/health`.  
A `healthcheck` binary is built from `./healthcheck/` during the build stage.

**Go build commands — for reference:**

```
| Purpose | Command |
|---|---|
| Download dependencies | `go mod download` |
| Build agent binary | `CGO_ENABLED=0 GOOS=linux go build -o pulse-agent .` |
| Build healthcheck binary | `CGO_ENABLED=0 GOOS=linux go build -o healthcheck ./healthcheck/` |
```

**Bridge network** `novapulse-net` already exists on the host.

---

## Part A — Implement (New Requirements)

These features do not exist in the current Dockerfile. You must add them.

**A1. Signal-safe ENTRYPOINT**  
The agent must shut down gracefully when Docker sends `SIGTERM`. Replace the current `ENTRYPOINT` with exec form so the Go binary becomes PID 1 and receives signals directly.

```
Required:  ENTRYPOINT ["/app/pulse-agent"]
```

**A2. Health check with exec form and tuned parameters**  
Add a `HEALTHCHECK` instruction using the `healthcheck` binary already built into the image. It must use exec form with the following parameters:

```
--interval=30s
--timeout=5s
--retries=3
```

**A3. Build-time version injection without runtime leakage**  
The build pipeline injects a `BUILD_VERSION` value at build time via `--build-arg`. It must be available during the build but must **not** appear as an environment variable in any container spawned from the final image. Declare it so `docker inspect` on the final image does not reveal it.

**A4. Runtime environment defaults**  
The following variables must have safe defaults baked into the final image:

```
| Variable | Default |
|---|---|
| `APP_ENV` | `production` |
| `LOG_LEVEL` | `info` |
```

---

## Part B — Fix (Known Bugs)

These bugs have been reported. Find them and fix them.

**B1. `.dockerignore` is incomplete**  
The image is larger than expected and local development files are reaching the build context. Fix `.dockerignore` so that `tests/` and `.env` are excluded.

**B2. `BUILD_VERSION` is leaking into the final image**  
The current Dockerfile promotes the `BUILD_VERSION` `ARG` into an `ENV`. This bakes the value into every image layer. Fix it so `BUILD_VERSION` is build-time only.

---

## Part C — Investigate

The running container `pulse-agent-staging` may have issues beyond what is documented above. Use the available Docker tooling to inspect its live state and correct anything you find before submitting.

> There are no further hints for Part C.

---

## Deliverables

1. Fixed `Dockerfile` at `/home/user/pulse-agent/Dockerfile`
2. Fixed `.dockerignore` at `/home/user/pulse-agent/.dockerignore`
3. Image built and tagged `pulse-agent:v2`
4. Container `pulse-agent-staging` running on `novapulse-net` with correct configuration

---

## Success Criteria

- **Part A1:** `ENTRYPOINT` must use exec form and be defined as `ENTRYPOINT ["/app/pulse-agent"]`.
- **Part A2:** `HEALTHCHECK` must use exec form with `CMD ["/app/healthcheck"]` and must not use `CMD-SHELL`.
- **Part A2:** `HEALTHCHECK` must use the parameters `--interval=30s --timeout=5s --retries=3`.
- **Part A3 / B2:** `BUILD_VERSION` must not appear as an `ENV` variable in the final image and must only be defined using `ARG` so it is not visible through `docker inspect`.
- **Part A4:** `APP_ENV` must default to `production` and must be defined using `ENV` in the final stage.
- **Part A4:** `LOG_LEVEL` must default to `info` and must be defined using `ENV` in the final stage.
- **Part B1:** The `tests/` directory must not be present in the final image and must be excluded using `.dockerignore`.
- **Part B1:** The `.env` file must not be present in the final image and must be excluded using `.dockerignore`.
- The image must be tagged as `pulse-agent:v2`.
- A container named `pulse-agent-staging` must be running on the `novapulse-net` network and must be in the `running` state.
- The container environment variable `APP_ENV` must be set to `staging` and must be provided at runtime using the `-e` flag.


---

## Background Knowledge

**ENTRYPOINT exec form vs shell form**  
`ENTRYPOINT ["/app/binary"]` — binary is PID 1, receives `SIGTERM` directly. `ENTRYPOINT /app/binary` — Docker wraps it as `sh -c`, `sh` becomes PID 1, the Go process never receives `SIGTERM` and is forcibly killed after the stop timeout.

**HEALTHCHECK exec form vs shell form**  
`CMD ["/app/healthcheck"]` runs the binary directly as the probe. `CMD /app/healthcheck` spawns a new `sh` process for every probe interval — on minimal Alpine images this adds unnecessary overhead and an extra process in the probe chain.

**ARG vs ENV — the leakage risk**  
`ARG` values exist only during the build and do not persist into the final image. `ENV` values are baked into every image layer and are permanently visible via `docker inspect` on the image and any container. Promoting a build-time `ARG` to `ENV` causes the value to leak into every container ever spawned from that image.

**.dockerignore**  
Without a correct `.dockerignore`, the entire build directory is sent to the Docker daemon as build context — including test code, `.env` files, and any other development artifact. These land in intermediate layers and inflate the image even when the final stage does not explicitly copy them.

**docker exec**  
`docker exec -it <container> sh` opens an interactive shell inside a running container without restarting it. This is the standard way to inspect the live runtime environment — active env vars, present files, running user, process tree.