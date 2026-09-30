## 📋 Payload Submission Summary
<!-- Provide a clear description of the new payload, bug fix, or configuration upgrade. -->

## 📂 Payload Classification
- [ ] Lua 5.4 App (`apps/*.lua`)
- [ ] WebAssembly Binary (`apps/*.wasm`)
- [ ] BadUSB Injection Script (`badusb/scripts/*.txt`)
- [ ] BadUSB Keyboard Layout (`badusb/layouts/*.kl`)
- [ ] Infrared Profile (`infrared/**/*.ir`)
- [ ] Universal Configuration Template (`config/*.cfg.example`)
- [ ] Documentation / README Manifest Update

## 🧪 Hardware & Performance Verification
- [ ] Tested on physical MEOWKit ESP32-S3 hardware
- [ ] Zero runaway memory allocations in rendering loops (Lua / WASM verified)
- [ ] Reads dynamically from `/config/<app>.cfg` or automatically generates `.cfg` template on first boot
- [ ] Responds immediately to D-Pad navigation (`UP`, `DOWN`, `LEFT`, `RIGHT`, `A`, `B`)
- [ ] Cleanly terminates and releases resources when holding `[B]`
- [ ] Updated root `README.md` manifest table

## 🔒 Security & Opsec Review
- [ ] Strictly adheres to ethical security research guidelines in [SECURITY.md](SECURITY.md)
- [ ] No hardcoded personal Wi-Fi SSIDs, private passwords, or operator network IPs
- [ ] Contains no destructive payloads, wipers, or uncontained malware
