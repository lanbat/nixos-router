# Makefile for testing NixOS Multi-VLAN config

CONFIG_HOST ?= router
NIX_CONTAINER_IMAGE = nixos/nix
FLAKE ?= .#$(CONFIG_HOST)

.PHONY: shell test build vm clean

NIX := nix --experimental-features "nix-command flakes"
UID := $(shell id -u)
GID := $(shell id -g)
PWD := $(shell pwd)

shell:
	docker volume create nix-store
	docker run -it --rm \
	  -v nix-store:/nix \
	  -v $$(pwd):/workspace \
	  -w /workspace \
	  nixos/nix \
	  bash -c 'mkdir -p /etc/nix && echo "experimental-features = nix-command flakes" > /etc/nix/nix.conf && nix-shell -p gnumake nixos-rebuild'

test:
	docker run -it --rm \
	  -v $(PWD):/workspace \
	  -w /workspace \
	  nixos/nix \
	  bash -c 'git config --global --add safe.directory /workspace && nix --experimental-features "nix-command flakes" build .#nixosTests.nixos-multivlan && \
	  nix store gc --debug || true'

build:
	docker run -it --rm \
	  -u $(UID):$(GID) \
	  -v $(PWD):/workspace \
	  -w /workspace \
	  $(NIX_CONTAINER_IMAGE) \
	  $(NIX) rebuild dry-build --flake $(FLAKE)

vm:
	docker run -it --rm \
	  -v $(PWD):/workspace \
	  -w /workspace \
	  $(NIX_CONTAINER_IMAGE) \
	  $(NIX) .#nixosConfigurations.$(CONFIG_HOST).config.system.build.vm

clean:
	rm -rf result result-* .#*

