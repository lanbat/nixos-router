# NixOS Multi-VLAN Router & Services

This project sets up a declarative, secure, and modular **multi-VLAN NixOS router** that includes:

- VLAN routing
- DHCP + PowerDNS with per-VLAN DNS blocklists
- Samba AD + FreeIPA + GPO integration
- Certificate generation with Step-CA and secure distribution
- WireGuard with FreeIPA-synced peers
- Containerized services (e.g. Home Assistant, Deluge, Jellyfin)
- IP filtering via nftables + Suricata
- OAuth2 auth gateway via nginx + oauth2-proxy + Caddy

## 🧪 Local Testing Without Installing Nix

You can run everything inside a Docker container — no need to install Nix or NixOS locally.

### 🚀 Quickstart (Docker)

1. **Clone the repo**:
   ```bash
   git clone https://github.com/youruser/nixos-router.git
   cd nixos-router
   ```

2. **Run a Nix shell in Docker**:
   ```bash
   make shell
   ```

3. **Run the integration test suite**:
   ```bash
   make test
   ```

4. **Build the NixOS system config**:
   ```bash
   make build
   ```

5. **Build a bootable VM**:
   ```bash
   make vm
   ./result/bin/run-router-vm
   ```

## 🧱 Project Structure

```
.
├── configuration.nix               # System config
├── flake.nix                       # Flake entry point
├── networking/
│   └── variables.nix               # VLAN definitions, blocklists, subnets, etc.
├── services/
│   └── *.nix                       # DHCP, DNS, VPN, Samba AD, containers, etc.
├── tools/
│   └── wg-peer-generate.nix       # FreeIPA-synced WireGuard peer generator
├── tests/
│   ├── make-test.nix
│   ├── default.nix
│   ├── tests-full.nix             # Full system test
│   └── nixos-multivlan-full.nix   # Test logic using variables.nix
├── Makefile                        # Automation helpers
└── README.md
```

## 📚 Documentation

This repo includes Markdown docs on:

- Certificate distribution & GPO
- Guest VPN/Wi-Fi password rotation
- DNS and container auto-registration
- Persistent volumes, ACLs, and quotas

## 💡 Requirements

- Linux, macOS, or WSL
- [Docker](https://www.docker.com/) OR [nix-portable](https://github.com/DavHau/nix-portable)

Optional:
```bash
curl -L https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable -o nix-portable
chmod +x nix-portable
./nix-portable shell
```

## 🔐 Security Notes

- All secrets are mounted from `/mnt/vaultwarden/secrets/` at boot
- TLS certs are distributed read-only via Samba and auto-installed via GPO
- VPN credentials and peer config are synced from FreeIPA groups
- Guests use rotating daily credentials for VPN/Wi-Fi

## 🛠️ Want to Contribute?

Feel free to open an issue or PR to:

- Add more tests
- Extend containerized services
- Improve automation or GPO handling

## 🔗 License

This project is licensed under the **GNU Affero General Public License v3.0**.
See the `LICENSE` file for details.
