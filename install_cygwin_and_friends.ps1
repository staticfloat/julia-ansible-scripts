# Open up Powershell ISE and run these commands to download and open this file
#
# Set-Location $env:userprofile\Desktop
# Invoke-WebRequest -Uri "https://raw.githubusercontent.com/staticfloat/julia-ansible-scripts/master/install_cygwin_and_friends.ps1" -OutFile "install_cygwin_and_friends.ps1"
# psEdit install_cygwin_and_friends.ps1

function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Verbose "IE Enhanced Security Configuration (ESC) has been disabled."
}


function EnableAutomaticUpdates {
    $AUSettings = (New-Object -com "Microsoft.Update.AutoUpdate").Settings
    $AUSettings.NotificationLevel = 4
    $AUSettings.Save()
}


function Install-Cygwin {
    param ( $CygDir="c:\cygwin", $arch="x86")

    # Generate random password (forcing a non-alphanumeric at the end because of policies
    $password = (([char[]]([char]'a'..[char]'z') + 0..9 | sort {get-random})[0..12] -join '') + '.'
    Write-Verbose "Not-so-secret password: $password"

    if(!(Test-Path -Path $CygDir -PathType Container)) {
        Write-Verbose "Creating directory $CygDir"
        New-Item -Type Directory -Path $CygDir -Force
    }
    Write-Verbose "Downloading http://cygwin.com/setup-$arch.exe"
    $client = new-object System.Net.WebClient
    $client.DownloadFile("http://cygwin.com/setup-$arch.exe", "$CygDir\setup-$arch.exe" )

    $pkg_list = "git,make,curl,patch,python,gcc-g++,m4,cmake,p7zip,openssh,nano,tmux,cron,procps"
    if( $arch -eq "x86" ) {
        $pkg_list += ",mingw64-i686-gcc-g++,mingw64-i686-gcc-fortran"
    } else {
        $pkg_list += ",mingw64-x86_64-gcc-g++,mingw64-x86_64-gcc-fortran"
    }

    Write-Verbose "Installing Cygwin and $pkg_list"
    Start-Process -wait -FilePath "$CygDir\setup-$arch.exe" -ArgumentList "-q -g -l $CygDir -s http://mirror.mit.edu/cygwin/ -R c:\cygwin -P $pkg_list"

    $env:Path = $env:Path + ";$CygDir\bin"
    Write-Verbose "Setting up SSH server configuration"
    bash --login -c "ssh-host-config -y -w $password"

    Write-Verbose "Configuring windows firewall for SSH"
    $fwtest = netsh advfirewall firewall show rule name="Cygwin SSH"
    if( $fwtest.count -lt 5 ) {
        netsh advfirewall firewall add rule profile=any name="Cygwin SSH" dir=in localport=22 protocol=TCP action=allow
    }

    Write-Verbose "Starting SSHd"
    Start-Service sshd -ErrorAction SilentlyContinue

    Write-Verbose "Installing SSH key fingerprint"
    if( !(Test-Path -Path "$CygDir\home\Administrator\.ssh" -PathType Container) ) {
        Write-Verbose "Creating directory $CygDir\home\Administrator\.ssh"
        New-Item -Type Directory -Path "$CygDir\home\Administrator\.ssh" -Force
    }
    $client.DownloadFile("http://sophia.e.ip.saba.us/julia_buildbot_rsa.pub", "$CygDir\home\Administrator\.ssh\authorized_keys" )

    Write-Verbose "chown'ing authorized_keys"
    chown Administrator ~/.ssh/authorized_keys
    chmod 0600 ~/.ssh/authorized_keys
    chown Administrator ~/.ssh
    chmod 0600 ~/.ssh

    Write-Verbose "Downloading and running Windows 10 SDK"
    $client.DownloadFile( "http://download.microsoft.com/download/E/1/F/E1F1E61E-F3C6-4420-A916-FB7C47FBC89E/standalonesdk/sdksetup.exe", "$CygDir\home\Administrator\sdksetup.exe" )
    Start-Process -FilePath "$CygDir\home\Administrator\sdksetup.exe"
    if( $arch -eq "x86" ) {
        bash --login -c 'echo export PATH=\"\\\"$PATH:/cygdrive/c/Program Files (x86)/Windows Kits/10/bin/x86\\\"\" >> /etc/profile'
    } else {
        bash --login -c 'echo export PATH=\"\\\"$PATH:/cygdrive/c/Program Files (x86)/Windows Kits/10/bin/x64\\\"\" >> /etc/profile'
    }
}

$VerbosePreference = "Continue"

Disable-InternetExplorerESC
#Install-Cygwin -arch "x86"
Install-Cygwin -arch "x86_64"
EnableAutomaticUpdates
