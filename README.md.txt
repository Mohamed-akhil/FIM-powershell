# 🔐 File Integrity Monitoring System (PowerShell)

A real-time **File Integrity Monitoring (FIM)** system built using PowerShell. It continuously watches selected folders, detects file tampering (modification, deletion), and logs critical events — including attempts to modify or delete its own logs.

---

## 📌 Features

- ✅ Real-time file monitoring using `FileSystemWatcher`
- ✅ SHA256 hashing to detect unauthorized changes
- ✅ Monitors both **files/** and **logs/** directories
- ✅ Alerts on:
  - File **modification**
  - File **deletion**
  - **Log tampering**
- ✅ Ignores:
  - File creation
  - Self-generated files (like `hashes.txt`)
  - Logging updates to the current log file
- ✅ Color-coded console alerts and `.log` file output
- ✅ Lightweight and portable (pure PowerShell)

---

## 🛠 How It Works

- The **files/** folder is monitored for changes.
- The **logs/** folder is monitored for attempts to tamper with existing `.log` files.
- File hashes are recalculated and compared on every file change.
- **Critical actions** like `MODIFIED` or `DELETED` trigger red-colored console alerts and are written to log files.
- Log file creation and internal logging updates are ignored to prevent false alerts.

---

## 🧪 How to Run

```powershell

powershell.exe -ExecutionPolicy Bypass -File "fim.ps1"
