#!/bin/bash

# Function to check Docker logs for specific text
wait_for_docker_log() {
    local container_name=$1
    local search_text=$2
    local max_wait_minutes=${3:-5}
    
    echo -e "\033[0;33mExasol Container in running waiting for stability...\033[0m"
    
    local end_time=$(($(date +%s) + max_wait_minutes * 60))
    local attempt=0
    
    while [ $(date +%s) -lt $end_time ]; do
        ((attempt++))
        echo -e "\033[0;36mAttempt $attempt - Checking stability...\033[0m"
        
        # Get last 100 lines of Docker logs
        local logs=$(docker logs $container_name --tail 100 2>&1)
        
        # Check if search text exists
        if echo "$logs" | grep -q "$search_text"; then
            echo -e "\033[0;32mExasol is stable!\033[0m"
            return 0
        fi
        
        echo -e "\033[0;33mNot ready yet. waiting 30 seconds...\033[0m"
        
        for ((total_sec=30; total_sec>0; total_sec--)); do
            local min=$((total_sec / 60))
            local sec=$((total_sec % 60))
            printf "\r\033[0;33mNext check in: %02d:%02d   \033[0m" $min $sec
            sleep 1
        done
        printf "\r\033[0;33mNext check in: 00:00   \033[0m\n"
    done
    
    echo -e "\033[0;31mTimeout: '$search_text' not found after $max_wait_minutes minutes\033[0m"
    return 1
}


echo -e "\033[0;32mStarting Exasol UDF Test Script...\033[0m"


echo -e "\033[0;33mStopping and removing any existing Exasol container...\033[0m"
docker stop exasol-github-test 2>/dev/null
docker rm exasol-github-test 2>/dev/null


echo -e "\033[0;33mStarting Exasol container...\033[0m"
docker run -d --name exasol-github-test \
  --platform linux/amd64 \
  --privileged \
  --shm-size 2g \
  --cap-add SYS_ADMIN \
  -p 8563:8563 -p 8560:8560 \
  -e EXASOL_WEB_PORT=8560 \
  -e EXASOL_DOCKER_NAMESERVER=1.1.1.1 \
  exasol/docker-db:latest


if wait_for_docker_log "exasol-github-test" "stage6: All stages finished." 20; then
    echo -e "\033[0;33mCreating virtual environment...\033[0m"
    
    rm -rf .venv
    
    python -m venv .venv

    echo -e "\033[0;33mActivating virtual environment...\033[0m"
    
    source .venv/Scripts/activate

    echo -e "\033[0;33mUpgrading pip...\033[0m"

    python -m pip install --upgrade pip
    
    echo -e "\033[0;33mInstalling dependencies...\033[0m"
    
    python -m pip install -r requirements.txt
    
    # Run tests
    echo -e "\033[0;33mTesting UDF...\033[0m"
    python run.py
    
    
    echo -e "\033[0;33mDeactivating virtual environment...\033[0m"
    deactivate
    
    
    echo -e "\033[0;33mStopping and removing Exasol container...\033[0m"
    
    
    docker stop exasol-github-test
    docker rm exasol-github-test
else
    echo -e "\033[0;31mExasol failed to start in time. Exiting.\033[0m"
    exit 1
fi


echo -e "\033[0;32mScript Execution Complete!\033[0m"
