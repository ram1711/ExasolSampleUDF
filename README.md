# Exasol UDF Integration Test Runner

A robust PowerShell automation script to manage the lifecycle of an **Exasol Docker** instance and execute Python-based User Defined Function (UDF) tests.

This script ensures a "clean room" testing environment by spinning up a fresh Exasol container, waiting for database stability, configuring a virtual environment, and cleaning up resources after execution.



## Features

* **Automated Container Management**: Automatically stops, removes, and recreates the Exasol Docker container to ensure test isolation.
* **Smart Wait Logic**: Monitors Docker logs for `stage6: All stages finished` to ensure the database is fully initialized before starting tests.
* **Environment Isolation**: Automatically creates a Python `.venv`, upgrades `pip`, and installs dependencies from `requirements.txt`.
* **Visual Feedback**: Uses color-coded terminal output and a live countdown timer for polling checks.
* **UDF Optimized**: Pre-configured with `--privileged` and `SYS_ADMIN` capabilities, plus custom DNS settings to allow UDFs to access the internet (e.g., GitHub API).

## Prerequisites

Before running the script, ensure you have the following installed:
* **Docker Desktop**: Running with Linux containers enabled.
* **PowerShell 5.1+**: Standard on Windows 10/11.
* **Python 3.11+**: Added to your System PATH.

## 📁 Project Structure

```text
.
├── setup_and_test.ps1   # PowerShell automation script
├── setup_and_test.sh    # bash command automation script
├── run.py               # Python UDF test logic (using pyexasol)
├── requirements.txt     # Python dependencies (pyexasol, rich, pytest)
└── README.md            # Project documentation
```

## Usage

* **Clone the repository** to your local machine.
*  **Open PowerShell** (Run as Administrator is recommended for Docker operations).
* **Navigate** to the project folder.
* **Execute the script via powershell**:

    ```powershell
    .\setup_and_test.ps1
    ```
or

* **Execute the script via bash**:

    ```powershell
    ./setup_and_test.sh
    ```

## Configuration

You can modify the following parameters inside the script to suit your environment:

| Parameter | Default Value | Description |
| :--- | :--- | :--- |
| `ContainerName` | `exasol-github-test` | The name assigned to the Docker container. |
| `MaxWaitIteration` | `5` | Maximum time to wait for exasol container to boot. ||


## Process Workflow

* **Cleanup**: Force-stops and removes any existing container with the same name.
* **Container Launch**: Starts the Exasol DB with 2GB of shared memory and exposed ports `8563` (SQL) and `8560` (Web).
* **Polling**: Enters a loop checking `docker logs`. Includes a user-friendly countdown timer between attempts.
* **Python Setup**: Creates `.venv`, installs requirements, and activates the environment.
* **Execution**: Runs `run.py`, which performs the actual UDF testing.
* **Teardown**: Automatically stops the container to free up system RAM and CPU.

## Common Issues

* **Port 8563/8560 Occupied**: Ensure no other Exasol instances or services are using these ports.
* **Docker Memory**: If the container crashes, ensure Docker Desktop has at least 4GB of RAM allocated in *Settings > Resources*.
* **Execution Policy**: If the `.ps1` won't run, try: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`.

---
*Generated for Exasol UDF Development Pipelines*