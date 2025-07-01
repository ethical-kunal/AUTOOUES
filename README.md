<p align="center">
  <img src="https://github.com/user-attachments/assets/c54e8e5d-c09b-4818-84c8-4c3e08e5a6a8" alt="AUTOOUES" />
</p>

## 📝 Description

**AUTOOUES** is a powerful and automated Bash script designed to identify potential subdomain takeover vulnerabilities. It streamlines the process by first enumerating all subdomains for a given target, then performing intelligent CNAME record checks, and finally leveraging the `nuclei` tool with specialized templates for deeper validation on potentially vulnerable targets. All scan results are neatly organized into a dedicated directory named after the target domain.

## ✨ Features

* **Automated Subdomain Enumeration:** Discovers subdomains using `subfinder`.

* **Intelligent CNAME Analysis:** Identifies CNAME records pointing to external services and checks if those services are unresolved or potentially available for registration (via `dig` and `whois`).

* **Targeted Nuclei Scanning:** Automatically feeds potentially vulnerable CNAME targets to `nuclei` using specific subdomain takeover templates for precise validation.

* **Organized Output:** Creates a dedicated directory for each scan, saving all results (discovered subdomains, CNAME analysis, Nuclei findings) within it.

* **Interactive Menu:** Provides an easy-to-use menu for initiating scans.


## 🚀 Installation

1.  **Clone the repository (once uploaded to GitHub) or download the script:**

    ```bash
    git clone https://github.com/ethical-kunal/AUTOOUES.git
    cd AUTOOUES
    ```

    *(For now, you'll just copy the script content into a file.)*

2.  **Make the script and requirement file executable:**

    ```bash
    chmod +x auto_takeover_scanner.sh
    ```
     ```bash
    chmod +x requirements.sh
    ```
3. **Run `requirements.sh` to get Web Security Scanner Toolkit Prerequisites:**

   ```bash
    ./requirements.sh
    ```

## 💻 Usage

### Interactive Mode (Recommended)

Run the script without any arguments to enter the interactive menu:

```bash
./auto_takeover_scanner.sh
```

You will be greeted with the tool's banner and a menu:

```
  █████╗ ██╗   ██╗████████╗ ██████╗  ██████╗ ██╗   ██╗███████╗███████╗
 ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗██╔═══██╗██║   ██║██╔════╝██╔════╝
 ███████║██║   ██║   ██║   ██║   ██║██║   ██║██║   ██║█████╗  ███████╗
 ██╔══██║██║   ██║   ██║   ██║   ██║██║   ██║██║   ██║██╔══╝  ╚════██║
 ██║  ██║╚██████╔╝   ██║   ╚██████╔╝╚██████╔╝╚██████╔╝███████╗███████║
 ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝  ╚═════╝  ╚═════╝ ╚══════╝╚══════╝
             Automated Subdomain Takeover Scanner
           --------------------------------------
           Made by @ethical_kunal & @itshiddeneye

Main Menu:
1. Scan a new domain
2. Exit

Enter your choice (1 or 2):
```

Choose option `1` and follow the prompts to enter your target domain.

### Direct Scan Mode

You can also provide the target domain directly as a command-line argument for a one-time scan:

```bash
./auto_takeover_scanner.sh example.com
```

*(Replace `example.com` with your actual target domain.)*

### Output

For each scan, a new directory will be created in the format `yourdomain_com_scan_results` (e.g., `example_com_scan_results/`). This directory will contain the following files:

* `yourdomain_com_discovered_subdomains.txt`: A list of all subdomains found by `subfinder`.

* `yourdomain_com_cname_takeover_results.txt`: Detailed output of the CNAME checks, including potential takeover flags and WHOIS information.

* `yourdomain_com_potential_takeover_targets.txt`: A temporary file listing only the CNAME targets identified as potentially vulnerable, used as input for Nuclei.

* `yourdomain_com_nuclei_takeover_results.txt`: The results from the `nuclei` scan, indicating confirmed subdomain takeover vulnerabilities.

## 🤝 Credits

This tool was created by:

**@ethical_kunal & @itshiddeneye**

## 💡 Contributing

Contributions are welcome! If you have suggestions for improvements, new features, or bug fixes, please feel free to:

1.  Fork the repository.

2.  Create a new branch (`git checkout -b feature/YourFeature`).

3.  Make your changes.

4.  Commit your changes (`git commit -m 'Add some feature'`).

5.  Push to the branch (`git push origin feature/YourFeature`).

6.  Open a Pull Request.

## 📄 License

This project is open-source and available under the [MIT License](https://opensource.org/licenses/MIT).
