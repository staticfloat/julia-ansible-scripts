# To get verbose status messages, run `$VerbosePreference = "Continue"` in PowerShell

# Install Cygwin and SSH, set it to startup and add an authorized_key as a buildbot
# function Install-Cygwin {
#     param ( $CygDir="c:\cygwin", $arch="x86", $password )
#     if(!(Test-Path -Path $CygDir -PathType Container)) {
#         Write-Verbose "Creating directory $CygDir"
#         New-Item -Type Directory -Path $CygDir -Force
#     }
#     Write-Verbose "Downloading http://cygwin.com/setup-$arch.exe"
#     $client = new-object System.Net.WebClient
#     $client.DownloadFile("http://cygwin.com/setup-$arch.exe", "$CygDir\setup-$arch.exe" )
   
#     Write-Verbose "Installing Cygwin and ssh"
#     Start-Process -wait -FilePath "$CygDir\setup-$arch.exe" -ArgumentList "-q -g -l $CygDir -s http://mirror.mit.edu/cygwin/ -R c:\cygwin -P openssh"

#     $env:Path = $env:Path + ";$CygDir\bin"
#     Write-Verbose "Setting up SSH server configuration"
#     bash --login -c "ssh-host-config -y -w $password"

#     Write-Verbose "Configuring windows firewall for SSH"
#     $fwtest = netsh advfirewall firewall show rule name="Cygwin SSH"
#     if( $fwtest.count -lt 5 ) {
#         netsh advfirewall firewall add rule profile=any name="Cygwin SSH" dir=in localport=22 protocol=TCP action=allow
#     }

#     Write-Verbose "Starting SSHd"
#     Start-Service sshd -ErrorAction SilentlyContinue

#     Write-Verbose "Installing SSH key fingerprint"
#     if( !(Test-Path -Path "$CygDir\home\Administrator\.ssh" -PathType Container) ) {
#         Write-Verbose "Creating directory $CygDir\home\Administrator\.ssh"
#         New-Item -Type Directory -Path "$CygDir\home\Administrator\.ssh" -Force
#     }
#     $client.DownloadFile("http://sophia.e.ip.saba.us/julia_rsa.pub", "$CygDir\home\Administrator\.ssh\authorized_keys" )

#     Write-Verbose "chown'ing authorized_keys"
#     chown Administrator ~/.ssh/authorized_keys
#     chmod 0600 ~/.ssh/authorized_keys
#     chown Administrator ~/.ssh
#     chmod 0600 ~/.ssh
# }

$VerbosePreference = "Continue"
# Install Msys2 and most of a toolchain
function Install-Msys2 {
    param ( $arch="i686" )

    if( $arch -eq "x86_64" ) {
        $bits = "64"
    } else {
        $bits = "32"
    }

    # change the date in the following for future msys2 releases
    $msys2tarball = "msys2-base-$arch-20150512.tar"
    $msyspath = "C:\msys$bits"

    if(!(Test-Path -Path "$msyspath/usr/bin/git.exe")) {
        # install chocolatey and cmake
        Write-Verbose "Installing Chocolatey from https://chocolatey.org/install.ps1"
        iex ((new-object net.webclient).DownloadString("https://chocolatey.org/install.ps1"))
        choco install -y cmake

        # pacman is picky, reinstall msys2 from scratch
        foreach ($dir in @("etc", "usr", "var", "mingw32")) {
          if (Test-Path "$msyspath\$dir") {
            rm -Recurse -Force $msyspath\$dir
          }
        }
        mkdir -Force $msyspath | Out-Null

        Write-Verbose "Installing 7za from https://chocolatey.org/7za.exe"
        (new-object net.webclient).DownloadFile(
          "https://chocolatey.org/7za.exe",
          "$msyspath\7za.exe")

        Write-Verbose "Installing msys2 from http://sourceforge.net/projects/msys2/files/Base/$arch/$msys2tarball.xz"
        (new-object net.webclient).DownloadFile(
          "http://sourceforge.net/projects/msys2/files/Base/$arch/$msys2tarball.xz",
          "$msyspath\$msys2tarball.xz")
        
        cd C:\
        &"$msyspath\7za.exe" x -y "$msyspath\$msys2tarball.xz"
        &"$msyspath\7za.exe" x -y "$msys2tarball" | Out-Null

        Write-Verbose "Installing bash, pacman, pacman-mirrors and msys2-runtime"
        &$msyspath\usr\bin\sh -lc "pacman --noconfirm --force --needed -Sy bash pacman pacman-mirrors msys2-runtime"

        $pkg_list = "diffutils git curl python nano tmux m4 make patch tar p7zip msys/python2 openssh cygrunsrv mingw-w64-$arch-editrights"
        Write-Verbose "Installing $pkg_list"
        &$msyspath\usr\bin\sh -lc "pacman --noconfirm -Syu && pacman --noconfirm -S $pkg_list"
    }

    # Start doing the ssh-configuration dance
    Write-Verbose "Configuring ssh..."
    &$msyspath\usr\bin\bash -lc @'
PRIV_USER="ssh_user"

# Generate a host key for ourselves
ssh-keygen -A

# Make a temporary password for ourselves
tmp_pass=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | dd count=14 bs=1 2>/dev/null)

# Add ssh user
add=$(if ! net user "${PRIV_USER}" >/dev/null; then echo "//add"; fi)
net user "${PRIV_USER}" "${tmp_pass}" ${add} //fullname:"${PRIV_NAME}" //homedir:"$(cygpath -w $/var/empty)" //yes

# Add user to the Administrators group if necessary
if ! (net localgroup "Administrators" | grep -q '^'"${PRIV_USER}"'$'); then
    net localgroup "Administrators" "${PRIV_USER}" //add
fi

# Don't let passwords expire on this joker
passwd -e "${PRIV_USER}""

# Set required privileges
/mingw64/bin/editrights -a SeAssignPrimaryTokenPrivilege -u "${PRIV_USER}"
/mingw64/bin/editrights -a SeCreateTokenPrivilege -u "${PRIV_USER}"
/mingw64/bin/editrights -a SeTcbPrivilege -u "${PRIV_USER}"
/mingw64/bin/editrights -a SeDenyRemoteInteractiveLogonRight -u "${PRIV_USER}"
/mingw64/bin/editrights -a SeServiceLogonRight -u "${PRIV_USER}"
'@
}

# Then, install Msys2
Install-Msys2 -arch "i686"

