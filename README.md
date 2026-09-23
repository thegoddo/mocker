# Mocker

### A tiny Docker-like container runtime written in Bash

Mocker is a small, experimental project that explores how Docker works under the hood.

The goal is to understand the Linux primitives behind containers by implementing a minimal set of Docker-like operations using Bash and existing Linux utilities.

Instead of building a production-ready container engine, Mocker focuses on learning, experimentation, and understanding how filesystems, namespaces, networking, and resource limits work together.

---

## Inspiration

A special shout-out to **Peter Wilmott**, the OG creator of Bocker.

This project is inspired by his work demonstrating how Docker-like functionality can be implemented using approximately 100 lines of Bash.

Bocker was an excellent example of how much can be learned by stripping away abstractions and exploring the underlying Linux primitives.

**Check out the original project:**

https://github.com/p8952/bocker

All credit for the original Bocker project goes to Peter Wilmott. Mocker is an independent learning-oriented implementation inspired by his work.

---

## Features

Mocker aims to implement a small subset of Docker-like functionality.

- **Image creation:** Create an image from an existing directory.
- **Image pulling:** Pull container images from Docker Hub.
- **Container execution:** Run commands inside an isolated filesystem.
- **Process isolation:** Use Linux namespaces to isolate container processes.
- **Filesystem isolation:** Use `chroot` and Btrfs snapshots.
- **Resource limits:** Use Linux cgroups to configure CPU and memory limits.
- **Networking:** Connect containers through virtual Ethernet interfaces and a network bridge.
- **Container management:** List containers, execute commands, view logs, and remove containers.
- **Image management:** List images and commit container changes to an image.

This is a learning project, so functionality and compatibility may be limited.

---

## How It Works

Mocker combines several Linux facilities to approximate the basic behavior of a container runtime.

| Component | Purpose |
|---|---|
| Bash | Orchestrates the container lifecycle. |
| Btrfs | Stores images and creates writable snapshots for containers. |
| `chroot` | Changes the root filesystem seen by a process. |
| Linux namespaces | Provide isolation for processes, mounts, networking, and other resources. |
| cgroups | Apply CPU and memory resource limits. |
| veth interfaces | Provide virtual network connectivity. |
| Network bridge | Connects container network interfaces. |
| `iproute2` | Configures network interfaces, namespaces, and routes. |
| `util-linux` | Provides utilities such as `unshare` and `nsenter`. |

The project is intended to make these components easier to explore and understand.

---

## Prerequisites

Mocker is intended for Linux systems.

The following tools and facilities are required by the current implementation:

- Bash
- Btrfs and `btrfs-progs`
- `curl`
- `iproute2`
- `libcgroup-tools`
- `util-linux`
- `coreutils`
- `ripgrep`
- `uuidgen`
- `tar`
- `sed`
- `awk`

### System configuration

The current implementation expects:

- A Btrfs filesystem mounted at `/var/mocker`.
- A network bridge named `bridge0`.
- A gateway at `10.0.0.1` on the container network.
- Appropriate permissions to configure network interfaces, namespaces, and cgroups.

Additional network configuration may be necessary for containers to access external networks.

The exact requirements depend on your Linux distribution and system configuration.

---

## Usage

The command interface is designed to resemble a small subset of Docker.

### 1. Create an image

Create an image from an existing directory:

```bash
sudo ./mocker init <directory>
```

For example:

```bash
sudo ./mocker init ./rootfs
```

This creates a Btrfs subvolume containing the directory's contents.

### 2. Pull an image

Pull an image from Docker Hub:

```bash
sudo ./mocker pull <name> <tag>
```

For example:

```bash
sudo ./mocker pull centos 7
```

**Note:** The current implementation uses legacy Docker Registry v1 endpoints. These endpoints may no longer be compatible with Docker Hub.

### 3. List images

Display the images stored in the configured Btrfs directory:

```bash
sudo ./mocker images
```

### 4. Run a container

Run a command inside a container created from an image:

```bash
sudo ./mocker run <image_id> <command>
```

For example:

```bash
sudo ./mocker run img_42002 /bin/sh
```

Replace `img_42002` with an image ID that exists on your system.

The container receives a writable Btrfs snapshot of the specified image.

### 5. List containers

Display the containers stored in the configured Btrfs directory:

```bash
sudo ./mocker ps
```

### 6. Execute a command in a running container

Execute a command in a running container:

```bash
sudo ./mocker exec <container_id> <command>
```

For example:

```bash
sudo ./mocker exec ps_42002 /bin/sh
```

Replace the container ID with the ID of a container that is currently running.

### 7. View container logs

Display the log file associated with a container:

```bash
sudo ./mocker logs <container_id>
```

### 8. Commit a container

Commit a container's filesystem changes to an image:

```bash
sudo ./mocker commit <container_id> <image_id>
```

### 9. Remove an image or container

Remove an image or container:

```bash
sudo ./mocker rm <image_id_or_container_id>
```

---

## Resource Limits

The implementation supports CPU shares and memory limits through cgroups.

The current default values are:

| Resource | Default |
|---|---:|
| CPU shares | 512 |
| Memory limit | 512 MB |

These values can be overridden using environment variables.

For example:

```bash
sudo MOCKER_CPU_SHARE=1024 \
     MOCKER_MEM_LIMIT=1024 \
     ./mocker run <image_id> <command>
```

This requests 1024 CPU shares and a memory limit of approximately 1024 MB.

The actual behavior depends on the host's cgroup configuration and the compatibility of the available cgroup tools.

---

## Project Scope

Mocker is an educational project.

It is intended to help explore:

- How container filesystems are assembled.
- How Linux namespaces isolate processes.
- How cgroups control resource usage.
- How virtual networking connects containers.
- How Btrfs snapshots can be used to create writable container filesystems.
- How image and container lifecycle operations can be implemented using Linux utilities.
- How a collection of relatively simple commands can be orchestrated into a container runtime.

The goal is understanding, experimentation, and learning—not reproducing the full functionality of Docker.

---

## Limitations

Mocker is a work in progress.

It does not aim to implement every Docker feature, and its behavior may differ significantly from Docker.

Some limitations of the current implementation include:

- Compatibility with modern Docker Hub APIs is not guaranteed.
- Networking depends on the host's bridge and routing configuration.
- Resource-limit behavior depends on the host's cgroup configuration.
- Container isolation is simplified compared with mature container runtimes.
- Not all Docker image formats and filesystem-layer behaviors are supported.
- Some container-management operations may require further development.

These limitations are acceptable within the scope of a learning project.

---

## Disclaimer

**Mocker is experimental software and is not intended for production use.**

It requires elevated privileges and makes changes to host-level resources, including network interfaces, namespaces, and cgroups.

Use it in a disposable virtual machine or another isolated Linux environment.

Do not rely on it to securely isolate untrusted workloads.

---

## Acknowledgements

A special thanks to **Peter Wilmott**, the OG creator of Bocker.

His project inspired this exploration of Docker-like functionality using Bash and Linux primitives.

Original repository:

https://github.com/p8952/bocker

---

## License

Mocker is a learning implementation inspired by Bocker.

The original Bocker project is licensed under the GNU General Public License v3.0 or later.

See the original repository for its license:

https://github.com/p8952/bocker

The license for Mocker should be specified separately in this repository. Do not assume that the original project's license automatically establishes the license for this implementation.
