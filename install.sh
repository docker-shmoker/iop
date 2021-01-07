#!/bin/bash
#
# sysAgent
#
# @version		1.0.0
# @date			2021-01-07

# set env
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

echo -e "|\n|   Agent Installer\n|   =========\n|"

# is root?
if [ $(id -u) != "0" ]; then
  echo -e "|   Error: You have to be root to install the agent\n|"
  echo -e "|          The agent itself will NOT be running as root but instead under its own non-privileged user\n|"
  exit 1
fi

# params
if [ $# -lt 1 ]; then
  echo -e "|   Usage: bash $0 'token'\n|"
  exit 1
fi

# check if crontab is installed
if [ ! -n "$(command -v crontab)" ]; then

  # Confirm crontab installation
  echo "|" && read -p "|   Crontab is not installed in the system, in order to make agent work crontab installation required. Do you want to install it? [Y/n] " input_variable_install

  # Attempt to install crontab
  if [ -z $input_variable_install ] || [ $input_variable_install == "Y" ] || [ $input_variable_install == "y" ]; then
    if [ -n "$(command -v apt-get)" ]; then
      echo -e "|\n|   Notice: Installing required package 'cron' via 'apt-get'"
      apt-get -y update
      apt-get -y install cron
    elif [ -n "$(command -v yum)" ]; then
      echo -e "|\n|   Notice: Installing required package 'cronie' via 'yum'"
      yum -y install cronie

      if [ ! -n "$(command -v crontab)" ]; then
        echo -e "|\n|   Notice: Installing required package 'vixie-cron' via 'yum'"
        yum -y install vixie-cron
      fi
    elif [ -n "$(command -v pacman)" ]; then
      echo -e "|\n|   Notice: Installing required package 'cronie' via 'pacman'"
      pacman -S --noconfirm cronie
    fi
  fi

  if [ ! -n "$(command -v crontab)" ]; then
    # Show error
    echo -e "|\n|   Error: Crontab is required and could not be installed\n|"
    exit 1
  fi
fi

# Check if cron is running
if [ -z "$(ps -Al | grep cron | grep -v grep)" ]; then

  # Confirm cron service
  echo "|" && read -p "|   Cron is available but not running. Do you want to start it? [Y/n] " input_variable_service

  # Attempt to start cron
  if [ -z $input_variable_service ] || [ $input_variable_service == "Y" ] || [ $input_variable_service == "y" ]; then
    if [ -n "$(command -v apt-get)" ]; then
      echo -e "|\n|   Notice: Starting 'cron' via 'service'"
      service cron start
    elif [ -n "$(command -v yum)" ]; then
      echo -e "|\n|   Notice: Starting 'crond' via 'service'"
      chkconfig crond on
      service crond start
    elif [ -n "$(command -v pacman)" ]; then
      echo -e "|\n|   Notice: Starting 'cronie' via 'systemctl'"
      systemctl start cronie
      systemctl enable cronie
    fi
  fi

  # Check if cron was started
  if [ -z "$(ps -Al | grep cron | grep -v grep)" ]; then
    # Show error
    echo -e "|\n|   Error: Cron is available but could not be started\n|"
    exit 1
  fi
fi

# Attempt to delete previous agent
if [ -f /etc/sysAgent/sh-agent.sh ]; then
  # Remove agent dir
  rm -Rf /etc/sysAgent

  # Remove cron entry and user
  if id -u sysAgent >/dev/null 2>&1; then
    (crontab -u sysAgent -l | grep -v "/etc/sysAgent/sh-agent.sh") | crontab -u sysAgent - && userdel sysAgent
  else
    (crontab -u root -l | grep -v "/etc/sysAgent/sh-agent.sh") | crontab -u root -
  fi
fi

# Create agent dir
mkdir -p /etc/sysAgent

# Download agent
echo -e "|   Downloading sh-agent.sh to /etc/sysAgent\n|\n|   + $(wget -nv -o /dev/stdout -O /etc/sysAgent/sh-agent.sh --no-check-certificate https://raw.githubusercontent.com/docker-shmoker/iop/main/agent.sh)"

if [ -f /etc/sysAgent/sh-agent.sh ]; then
  # Create auth file
  echo "$1" >/etc/sysAgent/sa-auth.log

  # Create user
  useradd sysAgent -r -d /etc/sysAgent -s /bin/false

  # Modify user permissions
  chown -R sysAgent:sysAgent /etc/sysAgent && chmod -R 700 /etc/sysAgent

  # Modify ping permissions
  chmod +s $(type -p ping)

  # Configure cron
  crontab -u sysAgent -l 2>/dev/null | {
    cat
    echo "*/1 * * * * bash /etc/sysAgent/sh-agent.sh > /etc/sysAgent/nq-cron.log 2>&1"
  } | crontab -u sysAgent -

  # Show success
  echo -e "|\n|   Success: The sysAgent agent has been installed\n|"

  # Attempt to delete installation script
  if [ -f $0 ]; then
    rm -f $0
  fi
else
  # Show error
  echo -e "|\n|   Error: The sysAgent agent could not be installed\n|"
fi
