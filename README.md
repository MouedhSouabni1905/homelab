# Homelab
> [!WARNING] 
> Some scripts may be specific to fedora.

Qemu scripts are a clone of [this repo](https://github.com/dpiegdon/qemu-scripts).

# Architecture

```
                                       Internet
                                          ^
 ________________                    _____|______________________
| Libre Computer | ---------------- | NAT |                      |
| AML-S905X-CC   |                  |_____|                      |
| ( Pi-hole )    |                  | ASUS TUF Gaming F15 (2021) |
 ________________                   |                            |
  OS : Armbian                      |                            |
                                     ____________________________
                                        OS : Fedora Workstation
```
