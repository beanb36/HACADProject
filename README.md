# Google Cloud Kubernetes Deployment Setup

## Setup Instructions

### 1. Create a Google Cloud Project

- Visit the [Google Cloud Console](https://console.cloud.google.com/).
- Click on "New Project".
- Give it a descriptive name.
- Use the GCloud Shell terminal to unzip the project
- Do not use a VM to run the shell script
  
### 2. Update the Project ID in the Setup Script

- Open the setup script using `vim` or your preferred text editor:
  ```bash
  vim gcp_setup.sh
  ```
- Find the `PROJECT_ID` variable and replace its value with your actual Google Cloud Project ID

### 3. Make the Script Executable

Run the following command to grant execute permission to the script:

```bash
chmod +x gcp_setup.sh
```

### 4. Run the Setup Script

Execute the setup script to initialize your cloud resources:

```bash
./gcp_setup.sh
```

Follow any prompts and verify that all services are correctly enabled.
