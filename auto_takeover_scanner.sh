#!/bin/bash

# Script: Automated Subdomain Takeover Scanner with Nuclei
# Description: This script automates subdomain enumeration for a given domain,
#              checks each discovered subdomain for potential CNAME-based
#              subdomain takeover vulnerabilities, and then uses Nuclei
#              to perform a more detailed check on identified potential targets.
# Prerequisites: subfinder, dig, whois, and nuclei tools must be installed and in your PATH.

# --- Configuration ---
# Default domain: You can set a default domain here. If left empty, the script
# will prompt the user to enter a domain.
DOMAIN_TO_SCAN="" 

# --- Color Codes for Terminal Output ---
GREEN="\e[32m"   # Green text for success/active status
WHITE="\e[37m"   # White text for general info/no CNAME found
RED="\e[31m"     # Red text for errors or potential takeover warnings
YELLOW="\e[33m"   # Yellow text for warnings or informational messages
CYAN="\e[36m"    # Cyan text for process headers
BLUE="\e[34m"     # Blue text for nuclei specific messages
PURPLE="\e[35m"   # Purple text for ASCII art
BOLD="\e[1m"     # Bold text
RESET="\e[0m"    # Resets text color to default

# --- Global File Variables (paths will be constructed dynamically) ---
# These are initial declarations; actual file paths will be set after DOMAIN_TO_SCAN is known.
OUTPUT_SUBDOMAINS_FILE=""
OUTPUT_CNAME_RESULTS_FILE=""
POTENTIAL_CNAME_TARGETS_FILE="" # Temporary file to store non-resolving CNAME targets for Nuclei
OUTPUT_NUCLEI_RESULTS_FILE="" # File to store Nuclei scan results
SCAN_RESULTS_DIR="" # Directory to store all results for a specific domain

# --- Functions ---

# Function to display the tool's name as a banner
display_banner() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "  █████╗ ██╗   ██╗████████╗ ██████╗  ██████╗ ██╗   ██╗███████╗███████╗"
    echo " ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗██╔═══██╗██║   ██║██╔════╝██╔════╝"
    echo " ███████║██║   ██║   ██║   ██║   ██║██║   ██║██║   ██║█████╗  ███████╗"
    echo " ██╔══██║██║   ██║   ██║   ██║   ██║██║   ██║██║   ██║██╔══╝  ╚════██║"
    echo " ██║  ██║╚██████╔╝   ██║   ╚██████╔╝╚██████╔╝╚██████╔╝███████╗███████║"
    echo " ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝  ╚═════╝  ╚═════╝ ╚══════╝╚══════╝"
    echo -e "${RESET}"
    echo -e "${CYAN}${BOLD}           Automated Subdomain Takeover Scanner${RESET}"
    echo -e "${YELLOW}           --------------------------------------${RESET}"
    echo -e "${WHITE}           Made by ${BOLD}@ethical_kunal & @itshiddeneye ${RESET}" # Added credit line
    echo ""
}

# Function to check if all necessary tools are installed and accessible
check_dependencies() {
    echo -e "${YELLOW}Checking for required tools (subfinder, dig, whois, nuclei)...${RESET}"
    
    # Check for subfinder
    if ! command -v subfinder &> /dev/null; then
        echo -e "${RED}Error: 'subfinder' is not installed or not in your PATH.${RESET}"
        echo -e "${CYAN}Please install it from https://github.com/projectdiscovery/subfinder and ensure it's in your system's PATH.${RESET}"
        exit 1
    fi
    
    # Check for dig
    if ! command -v dig &> /dev/null; then
        echo -e "${RED}Error: 'dig' is not installed. Please install dnsutils (e.g., sudo apt-get install dnsutils).${RESET}"
        exit 1
    fi
    
    # Check for whois
    if ! command -v whois &> /dev/null; then
        echo -e "${RED}Error: 'whois' is not installed. Please install it (e.g., sudo apt-get install whois).${RESET}"
        exit 1
    fi

    # Check for nuclei
    if ! command -v nuclei &> /dev/null; then
        echo -e "${RED}Error: 'nuclei' is not installed or not in your PATH.${RESET}"
        echo -e "${CYAN}Please install it from https://github.com/projectdiscovery/nuclei and ensure it's in your system's PATH.${RESET}"
        echo -e "${CYAN}Also, ensure you have the latest nuclei templates: nuclei -update-templates${RESET}"
        exit 1
    fi
    
    echo -e "${GREEN}All required tools are installed and ready.${RESET}"
}

# Function to perform subdomain enumeration using subfinder
enumerate_subdomains() {
    local target_domain=$1
    echo -e "${YELLOW}--------------------------------------------------${RESET}"
    echo -e "${CYAN}Starting subdomain enumeration for: $target_domain${RESET}"
    echo -e "${YELLOW}--------------------------------------------------${RESET}"
    
    # Ensure the output directory exists
    mkdir -p "$SCAN_RESULTS_DIR"

    # Ensure the output file is empty before starting
    > "$OUTPUT_SUBDOMAINS_FILE"

    # Run subfinder to discover subdomains silently and save them to the file
    subfinder -d "$target_domain" -o "$OUTPUT_SUBDOMAINS_FILE" -silent
    
    # Check if any subdomains were found (file is not empty)
    if [ ! -s "$OUTPUT_SUBDOMAINS_FILE" ]; then
        echo -e "${RED}Error: No subdomains found for '$target_domain' or 'subfinder' failed to write to the file.${RESET}"
        rm -f "$OUTPUT_SUBDOMAINS_FILE" # Clean up any empty file created
        exit 1
    fi

    echo -e "${GREEN}[+] Subdomain enumeration completed! Found $(wc -l < "$OUTPUT_SUBDOMAINS_FILE") subdomains.${RESET}"
    echo -e "${GREEN}[+] Discovered subdomains saved to '$OUTPUT_SUBDOMAINS_FILE'${RESET}"
}

# Function to check CNAME records for potential subdomain takeover
# This function also populates a temporary file with non-resolving CNAME targets
check_cname_takeover() {
    local subdomains_file=$1 # Path to the discovered subdomains file
    echo -e "${YELLOW}--------------------------------------------------${RESET}"
    echo -e "${CYAN}Checking CNAME records for potential subdomain takeover...${RESET}"
    echo -e "${YELLOW}--------------------------------------------------${RESET}"
    
    # Ensure the output directory exists
    mkdir -p "$SCAN_RESULTS_DIR"

    # Clear previous results file and the temporary targets file before writing new ones
    > "$OUTPUT_CNAME_RESULTS_FILE"
    > "$POTENTIAL_CNAME_TARGETS_FILE"
    
    # Read each subdomain from the generated file
    while read -r subdomain; do
        # Skip empty lines
        if [ -z "$subdomain" ]; then
            continue
        fi

        # Get CNAME record for the current subdomain
        cname=$(dig +short CNAME "$subdomain")

        if [ -n "$cname" ]; then
            # CNAME record found
            echo -e "${GREEN}[+] $subdomain -> $cname${RESET}" | tee -a "$OUTPUT_CNAME_RESULTS_FILE"

            # Check if the CNAME target (the domain it points to) resolves
            cname_resolves=$(dig +short "$cname")

            if [ -z "$cname_resolves" ]; then
                # CNAME target does not resolve - potential takeover
                echo -e "${RED}    [-] Potential Takeover: $cname does not resolve!${RESET}" | tee -a "$OUTPUT_CNAME_RESULTS_FILE"
                
                # Perform WHOIS lookup on the non-resolving CNAME target
                # Look for indicators that the domain might be unregistered/available
                whois_info=$(whois "$cname" 2>&1 | grep -Ei "No match|NOT FOUND|Status: inactive|No Data Found|Domain Not Found|not found in our database" | head -1)
                
                if [ -n "$whois_info" ]; then
                    echo -e "${YELLOW}    [!] WHOIS Check: Domain '$cname' might be available for registration!${RESET}" | tee -a "$OUTPUT_CNAME_RESULTS_FILE"
                    # Add the potential target to our temporary file for Nuclei scanning
                    echo "$cname" >> "$POTENTIAL_CNAME_TARGETS_FILE"
                fi
            else
                # CNAME target resolves - likely active
                echo -e "${GREEN}    [+] CNAME target is active.${RESET}" | tee -a "$OUTPUT_CNAME_RESULTS_FILE"
            fi
        else
            # No CNAME record found for the subdomain
            echo -e "${WHITE}[-] No CNAME found for $subdomain${RESET}" | tee -a "$OUTPUT_CNAME_RESULTS_FILE"
        fi
    done < "$subdomains_file" # Read from the file containing discovered subdomains

    echo -e "${YELLOW}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}CNAME takeover check completed! Full results saved to '$OUTPUT_CNAME_RESULTS_FILE'${RESET}"
}

# Function to run Nuclei scans on potential CNAME takeover targets
run_nuclei_check() {
    local targets_file=$1 # Path to the file containing potential CNAME targets
    echo -e "${YELLOW}--------------------------------------------------${RESET}"
    echo -e "${BLUE}Starting Nuclei scan for potential subdomain takeover targets...${RESET}"
    echo -e "${YELLOW}--------------------------------------------------${RESET}"

    # Ensure the output directory exists
    mkdir -p "$SCAN_RESULTS_DIR"

    # Clear previous Nuclei results file
    > "$OUTPUT_NUCLEI_RESULTS_FILE"

    if [ ! -s "$targets_file" ]; then
        echo -e "${BLUE}[i] No non-resolving CNAME targets found for Nuclei scan.${RESET}"
        echo -e "${YELLOW}--------------------------------------------------${RESET}"
        return # Exit function if no targets
    fi

    echo -e "${BLUE}[i] Nuclei will scan targets listed in '$targets_file' using subdomain takeover templates.${RESET}"
    
    # Run Nuclei against the list of potential targets
    # -l: List of targets from a file
    # -t: Templates to use (specific subdomain takeover templates)
    # -o: Output file for results
    # -silent: Suppress all output except for results
    # -json: Output results in JSON format for easier parsing (optional, but good for automation)
    # -disable-update-check: Disable update check for faster execution
    nuclei -l "$targets_file" \
           -t vulnerabilities/subdomain-takeover/ \
           -o "$OUTPUT_NUCLEI_RESULTS_FILE" \
           -silent \
           -disable-update-check 

    if [ -s "$OUTPUT_NUCLEI_RESULTS_FILE" ]; then
        echo -e "${RED}[!] Nuclei scan completed. Potential subdomain takeover vulnerabilities found!${RESET}"
        echo -e "${RED}    Results saved to '$OUTPUT_NUCLEI_RESULTS_FILE'${RESET}"
    else
        echo -e "${GREEN}[+] Nuclei scan completed. No subdomain takeover vulnerabilities identified by Nuclei.${RESET}"
    fi
    echo -e "${YELLOW}--------------------------------------------------${RESET}"
}

# Function to display the main menu and handle user choices
main_menu_loop() {
    while true; do
        display_banner
        echo -e "${GREEN}Main Menu:${RESET}"
        echo -e "${WHITE}1. Scan a new domain${RESET}"
        echo -e "${WHITE}2. Exit${RESET}"
        echo ""
        read -p "$(echo -e "${CYAN}Enter your choice (1 or 2): ${RESET}")" choice

        case "$choice" in
            1)
                # Prompt for domain
                read -p "$(echo -e "${CYAN}Please enter the target domain (e.g., example.com): ${RESET}")" DOMAIN_TO_SCAN
                
                if [ -z "$DOMAIN_TO_SCAN" ]; then
                    echo -e "${RED}Error: No target domain provided. Please try again.${RESET}"
                    sleep 2
                    continue # Go back to the main menu
                fi

                # Construct dynamic output filenames and directory
                SAFE_DOMAIN_NAME=$(echo "$DOMAIN_TO_SCAN" | tr '.' '_')
                SCAN_RESULTS_DIR="${SAFE_DOMAIN_NAME}_scan_results" # New directory
                OUTPUT_SUBDOMAINS_FILE="${SCAN_RESULTS_DIR}/${SAFE_DOMAIN_NAME}_discovered_subdomains.txt"
                OUTPUT_CNAME_RESULTS_FILE="${SCAN_RESULTS_DIR}/${SAFE_DOMAIN_NAME}_cname_takeover_results.txt"
                POTENTIAL_CNAME_TARGETS_FILE="${SCAN_RESULTS_DIR}/${SAFE_DOMAIN_NAME}_potential_takeover_targets.txt"
                OUTPUT_NUCLEI_RESULTS_FILE="${SCAN_RESULTS_DIR}/${SAFE_DOMAIN_NAME}_nuclei_takeover_results.txt"

                # Step 4: Enumerate subdomains
                enumerate_subdomains "$DOMAIN_TO_SCAN"

                # Step 5: Perform CNAME takeover check
                check_cname_takeover "$OUTPUT_SUBDOMAINS_FILE"

                # Step 6: Run Nuclei scan
                run_nuclei_check "$POTENTIAL_CNAME_TARGETS_FILE"

                echo -e "${CYAN}Scan finished. Results are saved in the '${SCAN_RESULTS_DIR}/' directory.${RESET}"
                echo -e "${CYAN}- Discovered Subdomains: '$OUTPUT_SUBDOMAINS_FILE'${RESET}"
                echo -e "${CYAN}- CNAME Takeover Analysis: '$OUTPUT_CNAME_RESULTS_FILE'${RESET}"
                echo -e "${CYAN}- Nuclei Takeover Scan: '$OUTPUT_NUCLEI_RESULTS_FILE'${RESET}"
                echo -e "${YELLOW}Press Enter to return to Main Menu...${RESET}"
                read -r -s -n 1 # Wait for any key press
                ;;
            2)
                echo -e "${GREEN}Exiting Auto_Takeover. Goodbye!${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 1 or 2.${RESET}"
                sleep 2
                ;;
        esac
    done
}

# --- Main Script Execution Logic ---

# Step 1: Check if all necessary dependencies are installed
check_dependencies

# Step 2: If a domain is provided as a command-line argument, run a single scan.
# Otherwise, enter the interactive menu loop.
if [ -n "$1" ]; then
    DOMAIN_TO_SCAN=$1
    
    # Construct dynamic output filenames and directory
    SAFE_DOMAIN_NAME=$(echo "$DOMAIN_TO_SCAN" | tr '.' '_')
    SCAN_RESULTS_DIR="${SAFE_DOMAIN_NAME}_scan_results" # New directory
    OUTPUT_SUBDOMAINS_FILE="${SCAN_RESULTS_DIR}/${SAFE_DOMAIN_NAME}_discovered_subdomains.txt"
    OUTPUT_CNAME_RESULTS_FILE="${SCAN_RESULTS_DIR}/${SAFE_DOMAIN_NAME}_cname_takeover_results.txt"
    POTENTIAL_CNAME_TARGETS_FILE="${SCAN_RESULTS_DIR}/${SAFE_DOMAIN_NAME}_potential_takeover_targets.txt"
    OUTPUT_NUCLEI_RESULTS_FILE="${SCAN_RESULTS_DIR}/${SAFE_DOMAIN_NAME}_nuclei_takeover_results.txt"

    display_banner # Show banner even for direct scan
    echo -e "${CYAN}Running one-time scan for: $DOMAIN_TO_SCAN${RESET}"
    echo -e "${YELLOW}--------------------------------------------------${RESET}"

    # Step 3: Enumerate subdomains for the target domain
    enumerate_subdomains "$DOMAIN_TO_SCAN"

    # Step 4: Perform the CNAME takeover check using the discovered subdomains file
    # This will also populate POTENTIAL_CNAME_TARGETS_FILE
    check_cname_takeover "$OUTPUT_SUBDOMAINS_FILE"

    # Step 5: Run Nuclei scan on the potential CNAME takeover targets
    run_nuclei_check "$POTENTIAL_CNAME_TARGETS_FILE"

    echo -e "${CYAN}Script finished. Results are saved in the '${SCAN_RESULTS_DIR}/' directory.${RESET}"
    echo -e "${CYAN}- Discovered Subdomains: '$OUTPUT_SUBDOMAINS_FILE'${RESET}"
    echo -e "${CYAN}- CNAME Takeover Analysis: '$OUTPUT_CNAME_RESULTS_FILE'${RESET}"
    echo -e "${CYAN}- Nuclei Takeover Scan: '$OUTPUT_NUCLEI_RESULTS_FILE'${RESET}"
    exit 0
else
    # Enter the interactive menu loop if no domain provided as argument
    main_menu_loop
fi
