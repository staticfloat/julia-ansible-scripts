function Install-Cygwin {
    param ( $CygDir="c:\cygwin", $arch="x86", $password )
    if(!(Test-Path -Path $CygDir -PathType Container)) {
        Write-Verbose "Creating directory $CygDir"
        New-Item -Type Directory -Path $CygDir -Force
    }
    Write-Verbose "Downloading http://cygwin.com/setup-$arch.exe"
    $client = new-object System.Net.WebClient
    $client.DownloadFile("http://cygwin.com/setup-$arch.exe", "$CygDir\setup-$arch.exe" )

    $pkg_list = "git,make,curl,patch,python,gcc-g++,m4,cmake,p7zip,ssh"
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
    $client.DownloadFile("http://sophia.e.ip.saba.us/julia_rsa.pub", "$CygDir\home\Administrator\.ssh\authorized_keys" )

    Write-Verbose "chown'ing authorized_keys"
    chown Administrator ~/.ssh/authorized_keys
    chmod 0600 ~/.ssh/authorized_keys
    chown Administrator ~/.ssh
    chmod 0600 ~/.ssh
}

Install-Cygwin -arch "x86" -password "julialang.sshpassword123"