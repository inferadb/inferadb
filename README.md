# InferaDB

__The distributed inference engine for authorization, designed for fine-grained, low-latency environments.__

This repository orchestrates the InferaDB ecosystem, including the core policy engine (`server`), management API (`management`), and management dashboard (`dashboard`). It provides configuration, containerization, and deployment resources for running the full system locally or in the cloud.

## Requirements

- [Mise](https://mise.jdx.dev/getting-started.html)
- Make
- Rust

## Getting Started

Clone this repository:

```bash
git clone https://github.com/inferadb/inferadb
```

Initialize the submodules:

```bash
git submodule init && git module update --remote
```

Install the required development tools and dependencies:

```bash
make setup
```

Start the services in development mode:

```bash
make dev
```

## License

This meta-repository is organized using submodules, each of which represents unique project repositories with their own licensing conditions. Please review each project license individually.
