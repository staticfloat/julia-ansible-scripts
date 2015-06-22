# To get verbose status messages, run `$VerbosePreference = "Continue"` in PowerShell

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

    # This takes a long time, let's only do it if we need to.
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

        $pkg_list = "diffutils git curl nano tmux m4 make patch tar p7zip openssh cygrunsrv mingw-w64-$arch-editrights"
        Write-Verbose "Installing $pkg_list"
        &$msyspath\usr\bin\sh -lc "pacman --noconfirm -Syu && pacman --noconfirm -S $pkg_list"

        Write-Verbose "Rebasing MSYS2"
        &$msyspath\autorebase.bat

        # Let's install python
        Write-Verbose "Installing python from chocolatey"
        choco install -y python2
        &$msyspath\usr\bin\sh -lc 'ln -s $(which python) /usr/bin/python'
    }

    # Start doing the ssh-configuration dance
    Write-Verbose "Configuring ssh..."
    &$msyspath\usr\bin\bash -lc @'
set -x
PRIV_USER="cyg_server"
UNPRIV_USER="sshd"

# Generate a host key for ourselves
ssh-keygen -A

# Make a temporary password for ourselves
tmp_pass=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | dd count=14 bs=1 2>/dev/null)

# Add ssh user
add=$(if ! net user "${PRIV_USER}" >/dev/null 2>&1; then echo "//add"; fi)
net user "${PRIV_USER}" "${tmp_pass}" ${add} //fullname:"${PRIV_NAME}" //homedir:$(cygpath -w $/var/empty) //yes

# Add user to the Administrators group if necessary
if ! (net localgroup "Administrators" | grep -q '^'"${PRIV_USER}"'$'); then
    net localgroup "Administrators" "${PRIV_USER}" //add
fi

# Don't let passwords expire on this joker
passwd -e "${PRIV_USER}"

# Set required privileges
ER=/mingw*/bin/editrights
$ER -a SeAssignPrimaryTokenPrivilege -u "${PRIV_USER}"
$ER -a SeCreateTokenPrivilege -u "${PRIV_USER}"
$ER -a SeTcbPrivilege -u "${PRIV_USER}"
$ER -a SeDenyRemoteInteractiveLogonRight -u "${PRIV_USER}"
$ER -a SeServiceLogonRight -u "${PRIV_USER}"

add=$(if ! net user "${UNPRIV_USER}" >/dev/null; then echo "//add"; fi)
net user "${UNPRIV_USER}" ${add} //fullname:"${UNPRIV_NAME}" //homedir:$(cygpath -w /var/empty) //active:no

cygrunsrv -R sshd >/dev/null 2>&1 || true
cygrunsrv -I sshd -d 'MSYS2 sshd' -p /usr/bin/sshd -a -D -y tcpip -u "${PRIV_USER}" -w "${tmp_pass}"
net start sshd
'@

    Write-Verbose "Configuring windows firewall for SSH"
    $fwtest = netsh advfirewall firewall show rule name="SSH"
    if( $fwtest.count -lt 5 ) {
        netsh advfirewall firewall add rule profile=any name="SSH" dir=in localport=22 protocol=TCP action=allow
    }

    Write-Verbose "Installing SSH key fingerprint"
    if( !(Test-Path -Path "$msyspath\home\Administrator\.ssh" -PathType Container) ) {
        Write-Verbose "Creating directory $msyspath\home\Administrator\.ssh"
        New-Item -Type Directory -Path "$msyspath\home\Administrator\.ssh" -Force
    }
    (new-object net.webclient).DownloadFile("http://sophia.e.ip.saba.us/julia_rsa.pub", "$msyspath\home\Administrator\.ssh\authorized_keys" )

    Write-Verbose "chown'ing authorized_keys"
    &$msyspath\usr\bin\bash -lc @'
chown Administrator ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
chown Administrator ~/.ssh
chmod 0600 ~/.ssh
'@
}

# Then, install Msys2 as either 64-bit or 32-bit
Install-Msys2 -arch "i686"
#Install-Msys2 -arch "x86_64"

