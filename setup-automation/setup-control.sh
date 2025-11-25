#!/bin/bash

systemctl stop systemd-tmpfiles-setup.service
systemctl disable systemd-tmpfiles-setup.service

# Install collection(s)
ansible-galaxy collection install ansible.eda
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.windows
ansible-galaxy collection install microsoft.ad

# # ## setup rhel user
# touch /etc/sudoers.d/rhel_sudoers
# echo "%rhel ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/rhel_sudoers
# cp -a /root/.ssh/* /home/$USER/.ssh/.
# chown -R rhel:rhel /home/$USER/.ssh

# Create an inventory file for this environment
tee /tmp/inventory << EOF
[nodes]
node01
node02

[storage]
storage01

[all]
node01
node02

[all:vars]
ansible_user = rhel
ansible_password = ansible123!
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_python_interpreter=/usr/bin/python3

EOF
# sudo chown rhel:rhel /tmp/inventory


# # # creates a playbook to setup environment
tee /tmp/setup.yml << EOF
---
### Automation Controller setup 
###
- name: Setup Controller 
  hosts: localhost
  connection: local
  collections:
    - ansible.controller
  vars:
    GUID: "{{ lookup('env', 'GUID') | default('GUID_NOT_FOUND', true) }}"
    DOMAIN: "{{ lookup('env', 'DOMAIN') | default('DOMAIN_NOT_FOUND', true) }}"
  tasks:

  - name: (EXECUTION) add App machine credential
    ansible.controller.credential:
      name: 'Application Nodes'
      organization: Default
      credential_type: Machine
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false
      inputs:
        username: rhel
        password: ansible123!

  - name: (EXECUTION) add Windows machine credential
    ansible.controller.credential:
      name: 'Windows Nodes'
      organization: Default
      credential_type: Machine
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false
      inputs:
        username: Administrator
        password: Ansible123!

  - name: (EXECUTION) add Arista credential
    ansible.controller.credential:
      name: 'Arista Network'
      organization: Default
      credential_type: Machine
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false
      inputs:
        username: ansible
        password: ansible

  - name: Add Network EE
    ansible.controller.execution_environment:
      name: "Edge_Network_ee"
      image: quay.io/acme_corp/network-ee
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

  - name: Add Windows EE
    ansible.controller.execution_environment:
      name: "Windows_ee"
      image: quay.io/acme_corp/windows-ee
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

  - name: Add RHEL EE
    ansible.controller.execution_environment:
      name: "Rhel_ee"
      image: quay.io/acme_corp/rhel_90_ee
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

  - name: Add Video platform inventory
    ansible.controller.inventory:
      name: "Video Platform Inventory"
      description: "Nodes used for streaming"
      organization: "Default"
      state: present
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

  - name: Add Streaming Server hosts
    ansible.controller.host:
      name: "{{ item }}"
      description: "Application Nodes"
      inventory: "Video Platform Inventory"
      state: present
      enabled: true
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false
    loop:
      - node01
      - node02
      - node03
 
  - name: Add Streaming server group
    ansible.controller.group:
      name: "Streaming_Infrastucture"
      description: "Streaming Nodes"
      inventory: "Video Platform Inventory"
      hosts:
        - node01
        - node02
        - node03
      variables:
        ansible_user: rhel
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

  - name: Add Streaming server group
    ansible.controller.group:
      name: "Reporting"
      description: "Report Servers"
      inventory: "Video Platform Inventory"
      hosts:
        - node03
      variables:
        ansible_user: rhel
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false


  #   # Network
 
  - name: Add Edge Network Devices
    ansible.controller.inventory:
      name: "Edge Network"
      description: "Network for delivery"
      organization: "Default"
      state: present
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

  - name: Add CEOS1
    ansible.controller.host:
      name: "ceos01"
      description: "Edge Leaf"
      inventory: "Edge Network"
      state: present
      enabled: true
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false
      variables:
        ansible_host: node02
        ansible_port: 2001

  - name: Add CEOS2
    ansible.controller.host:
      name: "ceos02"
      description: "Edge Leaf"
      inventory: "Edge Network"
      state: present
      enabled: true
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false
      variables:
        ansible_host: node02
        ansible_port: 2002

  - name: Add CEOS3
    ansible.controller.host:
      name: "ceos03"
      description: "Edge Leaf"
      inventory: "Edge Network"
      state: present
      enabled: true
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false
      variables:
        ansible_host: node02
        ansible_port: 2003

  - name: Add EOS Network Group
    ansible.controller.group:
      name: "Delivery_Network"
      description: "EOS Network"
      inventory: "Edge Network"
      hosts:
        - ceos01
        - ceos02
        - ceos03
      variables:
        ansible_user: ansible
        ansible_connection: ansible.netcommon.network_cli 
        ansible_network_os: arista.eos.eos 
        ansible_password: ansible 
        ansible_become: yes 
        ansible_become_method: enable
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false
      
  #   ## Extra Inventories 

  # - name: Add Storage Infrastructure
  #   ansible.controller.inventory:
  #    name: "Cache Storage"
  #    description: "Edge NAS Storage"
  #    organization: "Default"
  #    state: present
  #    controller_host: "https://localhost"
  #    controller_username: admin
  #    controller_password: ansible123!
  #    validate_certs: false

  # - name: Add Storage Node
  #   ansible.controller.host:
  #    name: "Storage01"
  #    description: "Edge NAS Storage"
  #    inventory: "Cache Storage"
  #    state: present
  #    enabled: true
  #    controller_host: "https://localhost"
  #    controller_username: admin
  #    controller_password: ansible123!
  #    validate_certs: false

  - name:  Add Windows Inventory
    ansible.controller.inventory:
     name: "Windows Directory Servers"
     description: "AD Infrastructure"
     organization: "Default"
     state: present
     controller_host: "https://localhost"
     controller_username: admin
     controller_password: ansible123!
     validate_certs: false

  - name: Add Windows Inventory Host
    ansible.controller.host:
     name: "windows"
     description: "Directory Servers"
     inventory: "Windows Directory Servers"
     state: present
     enabled: true
     controller_host: "https://localhost"
     controller_username: admin
     controller_password: ansible123!
     validate_certs: false
     variables:
       ansible_host: windows

  - name: Create group with extra vars
    ansible.controller.group:
      name: "domain_controllers"
      inventory: "Windows Directory Servers"
      hosts:
        - windows
      state: present
      variables:
        ansible_connection: winrm
        ansible_port: 5986
        ansible_winrm_server_cert_validation: ignore
        ansible_winrm_transport: credssp
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false
        
  - name: (EXECUTION) Add project
    ansible.controller.project:
      name: "Roadshow"
      description: "Roadshow Content"
      organization: "Default"
      scm_type: git
      scm_url: http://gitea:3000/student/aap25-roadshow-content.git       ##ttps://github.com/nmartins0611/aap25-roadshow-content.git
      state: present
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

  #- name: (DECISIONS) Create an AAP Credential
  #  ansible.eda.credential:
  #    name: "AAP"
  #    description: "To execute jobs from EDA"
  #    inputs:
  #      host: "https://control-{{ GUID }}.{{ DOMAIN }}/api/controller/"
  #      username: "admin"
  #      password: "ansible123!"
  #    credential_type_name: "Red Hat Ansible Automation Platform"
  #    organization_name: Default
  #    controller_host: https://localhost
  #    controller_username: admin
  #    controller_password: ansible123!
  #    validate_certs: false

###############TEMPLATES###############

  # - name: Add System Report
  #   ansible.controller.job_template:
  #     name: "System Report"
  #     job_type: "run"
  #     organization: "Default"
  #     inventory: "Video Platform Inventory"
  #     project: "Roadshow"
  #     playbook: "playbooks/section01/server_re[ort].yml"
  #     execution_environment: "RHEL EE"
  #     credentials:
  #       - "Application Nodes"
  #     state: "present"
  #     controller_host: "https://localhost"
  #     controller_username: admin
  #     controller_password: ansible123!
  #     validate_certs: false

  # - name: Add Windows Setup Template
  #   ansible.controller.job_template:
  #     name: "Windows Patching Report"
  #     job_type: "run"
  #     organization: "Default"
  #     inventory: "Windows Directory Servers"
  #     project: "Roadshow"
  #     playbook: "playbooks/section01/windows_report.yml"
  #     execution_environment: "Windows_ee"
  #     credentials:
  #       - "Windows Nodes"
  #     state: "present"
  #     controller_host: "https://localhost"
  #     controller_username: admin
  #     controller_password: ansible123!
  #     validate_certs: false

  - name: Add Rhel Report Template
    ansible.controller.job_template:
      name: "Application Server Report"
      job_type: "run"
      organization: "Default"
      inventory: "Video Platform Inventory"
      project: "Roadshow"
      playbook: "playbooks/section01/rhel_report.yml"
      execution_environment: "Rhel_ee"
      credentials:
        - "Application Nodes"
      state: "present"
      survey_enabled: true
      survey_spec:
           {
             "name": "Report Details",
             "description": "Report components needed",
             "spec": [
               {
    	          "type": "multiplechoice",
    	          "question_name": "What data are you looking for ?",
              	"question_description": "Defined data",
              	"variable": "report_type",
                "choices": ["All","Storage Usage","User List","OS Versions"],
                "required": true
               }
             ]
           }
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

  - name: Add OSCAP Setup Template
    ansible.controller.job_template:
      name: "OpenSCAP Report"
      job_type: "run"
      organization: "Default"
      inventory: "Video Platform Inventory"
      project: "Roadshow"
      playbook: "playbooks/section01/rhel_compliance_report.yml"
      execution_environment: "Rhel_ee"
      credentials:
        - "Application Nodes"
      state: "present"
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

  - name: Add Windows Update Report Template
    ansible.controller.job_template:
      name: "Windows Update Report"
      job_type: "run"
      organization: "Default"
      inventory: "Windows Directory Servers"
      project: "Roadshow"
      playbook: "playbooks/section01/windows_update_report.yml"
      execution_environment: "Windows_ee"
      credentials:
        - "Windows Nodes"
      state: "present"
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

  - name: Add RHEL Backup
    ansible.controller.job_template:
      name: "Server Backup - XFS/RHEL"
      job_type: "run"
      organization: "Default"
      inventory: "Video Platform Inventory"
      project: "Roadshow"
      playbook: "playbooks/section01/xfs_backup.yml"
      execution_environment: "Rhel_ee"
      credentials:
        - "Application Nodes"
      state: "present"
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

  - name: Add RHEL Backup Check
    ansible.controller.job_template:
      name: "Check RHEL Backup"
      job_type: "run"
      organization: "Default"
      inventory: "Video Platform Inventory"
      project: "Roadshow"
      playbook: "playbooks/section01/check_backups.yml"
      execution_environment: "Rhel_ee"
      credentials:
        - "Application Nodes"
      state: "present"
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false


  - name: Add Windows Backup 
    ansible.controller.job_template:
      name: "Server Backup - VSS/Windows"
      job_type: "run"
      organization: "Default"
      inventory: "Windows Directory Servers"
      project: "Roadshow"
      playbook: "playbooks/section01/vss_windows.yml"
      execution_environment: "Windows_ee"
      credentials:
        - "Windows Nodes"
      state: "present"
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

  - name: Add Windows Backup Check
    ansible.controller.job_template:
      name: "Check Windows Backups"
      job_type: "run"
      organization: "Default"
      inventory: "Windows Directory Servers"
      project: "Roadshow"
      playbook: "playbooks/section01/check_windowsvss.yml"
      execution_environment: "Windows_ee"
      credentials:
        - "Windows Nodes"
      state: "present"
      controller_host: "https://localhost"
      controller_username: admin
      controller_password: ansible123!
      validate_certs: false

EOF

# # # chown files
# sudo chown rhel:rhel /tmp/setup.yml
# sudo chown rhel:rhel /tmp/inventory
# sudo chown rhel:rhel /tmp/git-setup.yml

# # # execute above playbook



ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-automation-platform-containerized-setup-bundle-2.5-9-x86_64/collections/:/root/.ansible/collections/ansible_collections/ ansible-playbook -i /tmp/inventory /tmp/setup.yml


cat <<'EOF' | tee /tmp/windows-setup.yml
---
- name: Push and execute windows-setup.ps1 on Windows
  hosts: "Windows Directory Servers"
  gather_facts: false
  tasks:
    - name: Ensure WinRM service is running
      ansible.windows.win_service:
        name: WinRM
        state: started
        start_mode: auto

    - name: Enable PowerShell remoting (idempotent)
      ansible.windows.win_shell: |
        try { Enable-PSRemoting -Force -SkipNetworkProfileCheck } catch { }
      args:
        executable: powershell.exe
      changed_when: false
      failed_when: false

    - name: Ensure IIS features are present
      ansible.windows.win_feature:
        name:
          - Web-Server
          - Web-Mgmt-Console
        state: present
        include_management_tools: true

    - name: Create IIS landing page
      ansible.windows.win_copy:
        dest: C:\\inetpub\\wwwroot\\index.html
        content: |
          <!DOCTYPE html>
          <html>
          <head>
              <title>Windows AD Lab</title>
          </head>
          <body>
              <h1>Windows AD Domain Controller</h1>
              <p>This is the Windows AD domain controller for the lab.</p>
          </body>
          </html>

    - name: Disable Server Manager auto-start at logon (policy, all users)
      ansible.windows.win_regedit:
        path: HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager
        name: DoNotOpenAtLogon
        data: 1
        type: dword
        state: present

    - name: Ensure AD DS feature is present
      ansible.windows.win_feature:
        name: AD-Domain-Services
        include_management_tools: true
        state: present

    - name: Install Chocolatey
      ansible.windows.win_shell: |
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
      args:
        executable: powershell.exe

    - name: Execute slmgr /rearm
      ansible.windows.win_powershell:
        script: |
          $Action = New-ScheduledTaskAction -Execute "cscript.exe" -Argument "//B //NoLogo %windir%\system32\slmgr.vbs /rearm"

          $Principal = New-ScheduledTaskPrincipal -UserId "Administrator" -RunLevel Highest

          $TaskName = "TempSLMGRRearm"
          Register-ScheduledTask -TaskName $TaskName -Action $Action -Principal $Principal -Force | Out-Null

          Start-ScheduledTask -TaskName $TaskName

          $TaskState = (Get-ScheduledTask -TaskName $TaskName).State
          while ($TaskState -eq "Running") {
            Start-Sleep -Seconds 1
            $TaskState = (Get-ScheduledTask -TaskName $TaskName).State
          }

          Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
      become: yes
      become_method: runas
      become_user: Administrator
      register: rearm_result

    - name: Reboot after Chocolatey/slmgr setup
      ansible.windows.win_reboot:
        msg: "Reboot to finalize Chocolatey/slmgr setup"
        pre_reboot_delay: 5

    - name: Set MapsBroker to manual and stopped (silence Server Manager)
      ansible.windows.win_service:
        name: MapsBroker
        start_mode: manual
        state: stopped

    - name: Install Microsoft Edge via Chocolatey (with retries)
      ansible.windows.win_shell: choco install microsoft-edge -y --no-progress
      args:
        executable: powershell.exe
      register: edge_install
      retries: 3
      delay: 20
      until: edge_install.rc == 0

    - name: Verify Edge installed
      ansible.windows.win_stat:
        path: C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe
      register: edge_bin

    - name: Fail if Edge not installed
      ansible.builtin.fail:
        msg: 'Edge did not install; check Chocolatey logs on the VM'
      when: not edge_bin.stat.exists
EOF

echo "=== Running Windows set up ==="
ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-automation-platform-containerized-setup-bundle-2.5-9-x86_64/collections/:/root/.ansible/collections/ansible_collections/ ansible-playbook -e @/tmp/track-vars.yml -i /tmp/inventory /tmp/windows-setup.yml
