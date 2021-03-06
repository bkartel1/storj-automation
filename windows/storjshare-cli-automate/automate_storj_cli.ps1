#Requires -Version 3
#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Automates the management of storjshare-cli for Windows
.DESCRIPTION
  Automates the management of storjshare-cli for Windows

  Examples:
  To deploy silently use the following command
  ./automate_storj_cli.ps1 -silent

  To install service use the following command
  ./automate_storj_cli.ps1 -installsvc -datadir C:\storjshare -storjpassword 4321

  To remove service use the following command
  ./automate_storj_cli.ps1 -removesvc

  To disable UPNP
  ./automate_storj_cli.ps1 -noupnp

    To run as a service account in silent mode, no upnp, auto reboot, and install a service
  ./automate_storj_cli.ps1 -silent -runas -username username -password password -noupnp -autoreboot -installsvc -datadir C:\storjshare -storjpassword 4321

.INPUTS
  -silent - [optional] this will write everything to a log file and prevent the script from running pause commands.
  -noupnp - [optional] Disables UPNP
  -installsvc - [optional] Installs storjshare as a service (see the config section in the script to customize)
    -svcname [name] - [optional] Installs the service with this name - storjshare-cli is default
    -datadir [directory] - [required] Data Directory of Storjshare
    -storjpassword [password] - [required] Password for Storjshare Directory
  -removesvc - [optional] Removes storjshare as a service (see the config section in the script to customize)
    -svcname [name] - required] Removes the service with this name (*becareful*)
  -runas - [optional] Runs the script as a service account
    -username username [required] Username of the account
    -password 'password' [required] Password of the account
  -autoreboot [optional] Automatically reboots if required
  -autosetup
    -datadir [directory] - [optional] Data Directory of Storjshare
    -storjpassword [password] - [required] Password for Storjshare Directory
    -publicaddr [ip or dns] - [optional] Public IP or DNS of storjshare (Default: 127.0.0.1)
        *Note use [THIS] to use the the hostname of the computer
        For example: [THIS] replaces with hostname
        For example: [THIS].domain.com replaces with hostname.domain.com
    -svcport [port number] - [optional] TCP Port Number of storjshare Service (Default: 4000)
    -nat [true | false] - [optional] Turn on or Off Nat (UPNP) [Default: true]
    -uri [uri of known good seed] - [optional] URI of a known good seed (Default: [blank])
    -loglvl [integer 1-4] - [optional] Logging Level of storjshare (Default: 3)
    -amt [number with unit] - [optional] Amount of space allowed to consume (Default: 2GB)
    -concurrency [integer] - [optional] Modifying this value can cause issues with getting contracts!
                             [warn]   See: http://docs.storj.io/docs/storjshare-troubleshooting-guide#rpc-call-timed-out
    -payaddr [storj addr] - [optional] Payment address STORJ wallet (Default: [blank; free])
    -tunconns [integer] - [optional] Number of allowed tunnel connections (Default: 3)
    -tunsvcport [port number] - [optional] Port number of Tunnel Service (Default: 0; random)
    -tunstart [port number] - [optional] Starting port number (Default: 0; random)
    -tunend [port number] - [optional] Ending port number (Default: 0; random)
   -noautoupdate
     -howoften - [optional] Days to check for updates (Default: Every day)
     -checktime - [optional] Time to check for updates (Default: 3:00am Local Time)
   -update - [optional] Performs an update only function and skips the rest
   -beta - [optional] Enables installation of beta releases
.OUTPUTS
  Return Codes (follows .msi standards) (https://msdn.microsoft.com/en-us/library/windows/desktop/aa376931(v=vs.85).aspx)
#>

#-----------------------------------------------------------[Parameters]------------------------------------------------------------

param(
    [Parameter(Mandatory=$false)]
    [SWITCH]$silent,

    [Parameter(Mandatory=$false)]
    [SWITCH]$noupnp,

    [Parameter(Mandatory=$false)]
    [SWITCH]$installsvc,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$svcname,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$datadir,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$storjpassword,

    [Parameter(Mandatory=$false)]
    [SWITCH]$removesvc,

    [Parameter(Mandatory=$false)]
    [SWITCH]$runas,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$username,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$password,

    [Parameter(Mandatory=$false)]
    [SWITCH]$autoreboot,

    [Parameter(Mandatory=$false)]
    [SWITCH]$autosetup,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$publicaddr,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$svcport,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$nat,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$uri,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$loglvl,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$amt,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$concurrency,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$payaddr,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$tunconns,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$tunsvcport,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$tunstart,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$tunend,

    [Parameter(Mandatory=$false)]
    [SWITCH]$noautoupdate,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$howoften,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [STRING]$checktime,

    [Parameter(Mandatory=$false)]
    [SWITCH]$update,

    [Parameter(Mandatory=$false)]
    [SWITCH]$beta,

    [parameter(Mandatory=$false,ValueFromRemainingArguments=$true)]
    [STRING]$other_args
 )

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

$global:script_version="5.5" # Script version
$global:reboot_needed=""
$global:noupnp=""
$global:installsvc="true"
$global:svcname="storjshare-cli"
$global:storjpassword=""
$global:runas=""
$global:username=""
$global:password=""
$global:autoreboot=""
$global:noautoupdate=""
$global:howoften="Daily"
$global:checktime="3am"
$global:update=""
$global:return_code=$global:error_success #default success
$global:user_profile=$env:userprofile + '\' # (Default: %USERPROFILE%) - runas overwrites this variable
$global:appdata=$env:appdata + '\' # (Default: %APPDATA%\) - runas overwrites this variable
$global:npm_path='' + $global:appdata + "npm\"
$global:datadir=$global:user_profile + ".storjshare\" #Default: %USERPROFILE%\.storjshare
$global:storjshare_bin='' + $global:npm_path + "storjshare.cmd" # Default: storj-bridge location %APPDATA%\npm\storj-bridge.cmd" - runas overwrites this variable
$global:autosetup=""
$global:publicaddr="127.0.0.1" #Default 127.0.0.1
$global:svcport="4000" #Default to 4000
$global:nat="true" #Default true for storjshare
$global:uri="" #Default blank for storjshare
$global:loglvl="3" #Default 3 for storjshare
$global:amt="2GB" #default: 2GB for storjshare
$global:concurrency="3" #default: 3
$global:payaddr="" #Default none; aka farming for free; for storjshare
$global:tunconns="3" #Default 3
$global:tunsvcport="0" #Default 0; random
$global:tunstart="0" #Defualt 0; random
$global:tunend="0" #Default 0; random
$global:beta="0" #Default 0
$global:recompile=""

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$windows_env=$env:windir
$work_directory='' + $windows_env + '\Temp\storj'
$save_dir=$work_directory + '\installs'
$storjshare_cli_install_log_path=$save_dir
$storjshare_cli_install_log_file=$storjshare_cli_install_log_path + '\automate_storjshare_cli.log'; #outputs everything to a file if -silent is used, instead of the console
$storjshare_cli_log_path=$work_directory + '\cli'
$global:storjshare_cli_log="$storjshare_cli_log_path\$global:svcname.log"
$global:storjshare_cli_log_ver="$save_dir\storjshare_ver.log"

$nodejs_ver="6" #make sure to reference Major Branch Version (Default: 6)

$python_ver="2" #make sure to reference Major Branch Version (Default: 2)

$openssl_ver="1.0.2j" #make sure to reference Major Branch Version (Default: 1.0.2j)

$visualstudio_ver="2015" # currently only supports 2015 Edition (Default: 2015)
$visualstudio_dl="http://go.microsoft.com/fwlink/?LinkID=626924"  #  link to 2015 download   (Default: http://go.microsoft.com/fwlink/?LinkID=626924)

#Handles EXE Security Warnings
$Lowriskregpath ="HKCU:\Software\Microsoft\Windows\Currentversion\Policies\Associations"
$Lowriskregfile = "LowRiskFileTypes"
$LowRiskFileTypes = ".exe"

$nssm_ver="2.24" # (Default: 2.24)
$nssm_location="$windows_env\System32" # Default windows directory
$nssm_bin='' + $nssm_location + '\' + "nssm.exe" # (Default: %WINDIR%\System32\nssm.exe)

$error_success=0  #this is success
$error_invalid_parameter=87 #this is failiure, invalid parameters referenced
$error_install_failure=1603 #this is failure, A fatal error occured during installation (default error)
$error_success_reboot_required=3010  #this is success, but requests for reboot

$automatic_restart_timeout=10  #in seconds Default: 10

$automated_script_path=Split-Path -parent $PSCommandPath
$automated_script_path=$automated_script_path + '\'

$recompile_file_path=$storjshare_cli_install_log_path + "\recompile.txt"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function handleParameters() {

    if(!(Test-Path -pathType container $storjshare_cli_install_log_path)) {
        New-Item $storjshare_cli_install_log_path -type directory -force | Out-Null
    }

    if(!(Test-Path -pathType container $storjshare_cli_install_log_path)) {
    	ErrorOut "Log Directory $storjshare_cli_install_log_path failed to create, try it manually..."
    }

    if(!(Test-Path -pathType container $storjshare_cli_log_path)) {
        New-Item $storjshare_cli_log_path -type directory -force | Out-Null
    }

    if(!(Test-Path -pathType container $storjshare_cli_log_path)) {
	ErrorOut "Log Directory $storjshare_cli_log_path failed to create, try it manually..."
    }

    if(!(Test-Path -pathType container $save_dir)) {
        New-Item $save_dir -type directory -force | Out-Null
    }

    if(!(Test-Path -pathType container $save_dir)) {
	ErrorOut "Save Directory $save_dir failed to create, try it manually..."
    }

    #checks the silent parameter and if true, writes to log instead of console, also ignores pausing
    if($silent) {
        LogWrite "Logging to file $storjshare_cli_install_log_file"
    } else {
        $message="Logging to console"
        LogWrite $message
    }

    if($beta) {
        LogWrite "Beta Updates Enabled"
        $global:beta="1"
    }

    if ($runas) {
        $global:runas="true"

        if(!($username)) {
            ErrorOut -code $error_invalid_parameter "ERROR: Username not specified"
        } else {
            $global:username="$username"
        }

        if(!($password)) {
            ErrorOut -code $error_invalid_parameter "ERROR: Password not specified"
        } else {
            $global:password="$password"
        }

        $securePassword = ConvertTo-SecureString $global:password -AsPlainText -Force
        $global:credential = New-Object System.Management.Automation.PSCredential $global:username, $securePassword

        $user_profile=GetUserEnvironment "%USERPROFILE%"
        $global:user_profile=$user_profile.Substring(0,$user_profile.Length-1) + '\'

        $appdata=GetUserEnvironment "%APPDATA%"
        $global:appdata=$appdata.Substring(0,$appdata.Length-1) + '\'

        $global:npm_path='' + $global:appdata + "npm\"
        $global:storjshare_bin='' + $global:npm_path + "storjshare.cmd" # Default: storjshare location %APPDATA%\npm\storjshare.cmd" - runas overwrites this variable

        $global:datadir=$global:user_profile + ".storjshare\"

        LogWrite "Using Service Account: $global:username"
        LogWrite "Granting $global:username Logon As A Service Right"
        Grant-LogOnAsService $global:username
    }

    if(Test-Path $recompile_file_path) {
        LogWrite "Recompile will be needed"
        $global:recompile="true"
    }

    if($update) {
        $global:update="true"
        LogWrite "Performing Update Only Function"
    } else {
        #checks for noupnp flag
        if ($noupnp) {
            $global:noupnp="true"
        }

        #checks for installsvc flag
        if ($global:installsvc) {
            $global:installsvc="true"

            if(!($svcname)) {
                $global:svcname="$global:svcname"
            } else {
                $global:svcname="$svcname"
            }

            $global:storjshare_cli_log="$storjshare_cli_log_path\$global:svcname.log"
            $global:storjshare_cli_log_ver="$save_dir\storjshare_ver.log"

            if(!($datadir)) {
                LogWrite "Using default storjshare datadir path: $datadir"
                $global:datadir="$global:datadir"
            } else {
                LogWrite "Using custom storjshare datadir path: $datadir"
                $global:datadir="$datadir"
            }

            if(!($storjpassword)) {
                if($silent) {
                    ErrorOut -code $global:error_invalid_parameter "ERROR: Service Password not specified"
                } else {
                    $pass = Read-Host 'Enter the password for storjshare-cli - Press Enter When Done' -AsSecureString
                    $global:storjpassword=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
                }
            } else {
                $global:storjpassword="$storjpassword"
            }
        }

        #checks for removesvc flag
        if ($removesvc) {
            $global:removesvc="true"

            if(!($svcname)) {
                $global:svcname="$storshare_svcname"
            } else {
                $global:svcname="$svcname"
            }

            $global:storjshare_cli_log="$storjshare_cli_log_path\$global:svcname.log"
        }

        if($autoreboot) {
            LogWrite "Will auto-reboot if needed"
            $global:autoreboot="true"
        }

        if ($autosetup) {
            $global:autosetup="true"

            if(!($datadir)) {
                LogWrite "Using default storjshare datadir path: $datadir"
                $global:datadir="$global:datadir"
            } else {
                LogWrite "Using custom storjshare datadir path: $datadir"
                $global:datadir="$datadir"
            }

            if(!($storjpassword)) {
                ErrorOut -code $global:error_invalid_parameter "ERROR: storjshare Password not specified"
            } else {
                $global:storjpassword="$storjpassword"
            }

            if(!($publicaddr)) {
                $global:publicaddr="$global:publicaddr"
            } else {
                $global:publicaddr=$publicaddr.Replace("[THIS]",$env:computername)
            }

            if(!($svcport)) {
                $global:svcport="$global:svcport"
            } else {
                $global:svcport="$svcport"
            }

            if(!($nat)) {
                $global:nat="$global:nat"
            } else {
                $global:nat="$nat"
            }

            if(!($amt)) {
                $global:amt="$global:amt"
            } else {
                $global:amt="$amt"
            }

            if(!($concurrency)) {
                $global:concurrency="$global:concurrency"
            } else {
                $global:concurrency="$concurrency"
            }

            if(!($uri)) {
                $global:uri="$global:uri"
            } else {
                $global:uri="$uri"
            }

            if(!($loglvl)) {
                $global:loglvl="$global:loglvl"
            } else {
                $global:loglvl="$loglvl"
            }

            if(!($payaddr)) {
                $global:payaddr="$global:payaddr"
            } else {
                $global:payaddr="$payaddr"
            }

            if(!($tunconns)) {
                $global:tunconns="$global:tunconns"
            } else {
                $global:tunconns="$tunconns"
            }

            if(!($tunsvcport)) {
                $global:tunsvcport="$global:tunsvcport"
            } else {
                $global:tunsvcport="$tunsvcport"
            }

            if(!($tunstart)) {
                $global:tunstart="$global:tunstart"
            } else {
                $global:tunstart="$tunstart"
            }

            if(!($tunend)) {
                $global:tunend="$global:tunend"
            } else {
                $global:tunend="$tunend"
            }
        }

        if($noautoupdate) {
            $global:noautoupdate="true"
        } else {
            if(!($howoften)) {
                $global:howoften=$global:howoften
            } else {
                $global:howoften=$howoften
            }

            if(!($checktime)) {
                $global:checktime=$global:checktime
            } else {
                $global:checktime=$checktime
            }

            LogWrite -Color Cyan "Auto-update set to happen every $global:howoften day(s) at $global:checktime"
        }
    }

    #checks for unknown/invalid parameters referenced
    if ($other_args) {
        ErrorOut -code $global:error_invalid_parameter "ERROR: Unknown arguments: $other_args"
    }
}

function LogWrite([string]$logstring,[string]$color) {
    $LogTime = Get-Date -Format "MM-dd-yyyy HH:mm:ss"
    $logmessage="["+$LogTime+"] "+$logstring
    if($silent) {
        if($logstring) {
            if(!(Test-Path -pathType container $storjshare_cli_install_log_path)) {
                New-Item $storjshare_cli_install_log_path -type directory -force | Out-Null
                if(!(Test-Path -pathType container $storjshare_cli_install_log_path)) {
		    ErrorOut "Log Directory $storjshare_cli_install_log_path failed to create, try it manually..."
	        }
	    }
            Add-content $storjshare_cli_install_log_file -value $logmessage
        }
    } else {
        if(!$logstring) {
            $logmessage=$logstring
        }
        if($color) {
            write-host -fore $color $logmessage
        } else {
            write-host $logmessage
        }
    }
}

function ErrorOut([string]$message,[int]$code=$error_install_failure) {
    LogWrite -color Red $message
    if($silent) {
    	LogWrite -color Red "Returning Error Code: $code"
    }
    exit $code;
}

function GitForWindowsCheck() {
    LogWrite "Checking if Git for Windows is installed..."
    if(!(Get-IsProgramInstalled "Git")) {
        $url = "https://github.com/git-for-windows/git/releases/latest"
        $request = [System.Net.WebRequest]::Create($url)
        $request.AllowAutoRedirect=$false
        $response = $request.GetResponse()
 
        if($response.StatusCode -eq "Found") {
            $url = $response.GetResponseHeader("Location")
        } else {
            ErrorOut "Unable to determine latest version for Git for Windows"
        }

        $version = $url.Substring(0,$url.Length-".windows.1".Length)
        $pos = $version.IndexOf("v")
        $version = $version.Substring($pos+1)

        LogWrite "Found Latest Version of Git for Windows - ${version}"

        LogWrite "Git for Windows is not installed."
        if([System.IntPtr]::Size -eq 4) {
            $arch="32-bit"
            $arch_ver='-32-bit'
        } else {
            $arch="64-bit"
            $arch_ver='-64-bit'
        }
	$filename = 'Git-' + $version + $arch_ver + '.exe';
	$save_path = '' + $save_dir + '\' + $filename;
        $url='https://github.com/git-for-windows/git/releases/download/v' + $version + '.windows.1/' + $filename;
	if(!(Test-Path -pathType container $save_dir)) {
	    ErrorOut "Save directory $save_dir does not exist"
	}
        LogWrite "Downloading Git for Windows ($arch) $version..."
        DownloadFile $url $save_path
        LogWrite "Git for Windows downloaded"

	LogWrite "Installing Git for Windows $version..."
        $Arguments = "/SILENT /COMPONENTS=""icons,ext\reg\shellhere,assoc,assoc_sh"""
	InstallEXE $save_path $Arguments
        
        if(!(Get-IsProgramInstalled "Git")) {
           ErrorOut "Git for Windows did not complete installation successfully...try manually installing it..."
        }
        $global:reboot_needed="true"
        LogWrite -color Green "Git for Windows Installed Successfully"
    }
    else
    {
        LogWrite "Git for Windows is already installed."
        LogWrite "Checking version..."
        $installed_version = Get-ProgramVersion( "Git" )
        if(!$installed_version) {
            ErrorOut "Git for Windows Version is Unknown - Error"
        }
        $url = "https://github.com/git-for-windows/git/releases/latest"
        $request = [System.Net.WebRequest]::Create($url)
        $request.AllowAutoRedirect=$false
        $response = $request.GetResponse()
 
        if($response.StatusCode -eq "Found") {
            $url = $response.GetResponseHeader("Location")
        } else {
            ErrorOut "Unable to determine latest version for Git for Windows"
        }
        $version = $url.Substring(0,$url.Length-".windows.1".Length)
        $pos = $version.IndexOf("v")
        $version = $version.Substring($pos+1)
        LogWrite "Found Latest Version of Git for Windows - ${version}"
        $result = CompareVersions $installed_version $version
        if($result -eq "-2") {
            ErrorOut "Unable to match Git for Windows version (Installed Version: $installed_version / Requested Version: $version)"
        }
        if($result -eq 0) {
            LogWrite "Git for Windows is already updated. Skipping..."
        } elseif($result -eq 1) {
            LogWrite "Git for Windows is newer than the recommended version. Skipping..."
        } else {
            LogWrite "Git for Windows is out of date."
            LogWrite -Color Cyan "Git for Windows $installed_version will be updated to $version..."
            if ([System.IntPtr]::Size -eq 4) {
                $arch="32-bit"
                $arch_ver='-32-bit'
            } else {
                $arch="64-bit"
                $arch_ver='-64-bit'
            }

    	    $filename = 'Git-' + $version + $arch_ver + '.exe';
	    $save_path = '' + $save_dir + '\' + $filename;
            $url='https://github.com/git-for-windows/git/releases/download/v' + $version + '.windows.1/' + $filename;
	    if(!(Test-Path -pathType container $save_dir)) {
	        ErrorOut "Save directory $save_dir does not exist"
	    }
            LogWrite "Downloading Git for Windows ($arch) $version..."
            DownloadFile $url $save_path
            LogWrite "Git for Windows downloaded"

	    LogWrite "Installing Git for Windows $version..."
            $Arguments = "/SILENT /COMPONENTS=""icons,ext\reg\shellhere,assoc,assoc_sh"""
	    InstallEXE $save_path $Arguments
        
            if(!(Get-IsProgramInstalled "Git")) {
                ErrorOut "Git for Windows did not complete installation successfully...try manually updating it..."
            }
            $global:reboot_needed="true"
            LogWrite -color Green "Git for Windows Updated Successfully"
            $installed_version = $version           
        }
        LogWrite -color Green "Git for Windows Installed Version: $installed_version"
    }
}

function OpenSSLCheck() {
    LogWrite "Checking if OpenSSL for Windows is installed..."
    if(!(Get-IsProgramInstalled "OpenSSL")) {
        $version = $openssl_ver

        LogWrite "Found Latest Version of OpenSSL for Windows - ${version}"

        LogWrite "OpenSSL for Windows is not installed."
        if([System.IntPtr]::Size -eq 4) {
            $arch="32-bit"
            $arch_ver='Win32OpenSSL-'
        } else {
            $arch="64-bit"
            $arch_ver='Win64OpenSSL-'
        }

    $file_ver = $version.replace('.','_')

	$filename = $arch_ver + $file_ver + '.exe';
	$save_path = '' + $save_dir + '\' + $filename;
        $url='https://slproweb.com/download/' + $filename;
	if(!(Test-Path -pathType container $save_dir)) {
	    ErrorOut "Save directory $save_dir does not exist"
	}
        LogWrite "Downloading OpenSSL for Windows ($arch) $version..."
        DownloadFile $url $save_path
        LogWrite "OpenSSL for Windows downloaded"

	LogWrite "Installing OpenSSL for Windows $version..."
        $Arguments = "/silent"
	InstallEXE $save_path $Arguments
        
        if(!(Get-IsProgramInstalled "OpenSSL")) {
           ErrorOut "OpenSSL for Windows did not complete installation successfully...try manually installing it..."
        }
        $global:reboot_needed="true"
        $global:recompile="true"
        LogWrite -color Green "OpenSSL for Windows Installed Successfully"
    }
    else
    {
        LogWrite "OpenSSL for Windows is already installed."
       
        LogWrite -color Green "OpenSSL for Windows Installed Version: $openssl_ver"
    }
}

function NodejsCheck([string]$version) {
    LogWrite "Checking if Node.js is installed..."
    if(!(Get-IsProgramInstalled "Node.js")) {
        LogWrite "Node.js is not installed."
        if([System.IntPtr]::Size -eq 4) {
            $arch="32-bit"
            $arch_ver='-x86'
        } else {
            $arch="64-bit"
            $arch_ver='-x64'
        }
        LogWrite "Gathering Latest Node.js for Major Version ${version}..."
        $url = "https://nodejs.org/dist/latest-v${version}.x/"
        $site = Invoke-WebRequest -URI "$url" -UseBasicParsing
        $found=0
        $site.Links | Foreach {
            $url_items = $_.href
            if($url_items -like "*${arch_ver}.msi") {
                $filename=$url_items
                $found=1
            }
        }
        if($found -ne 1) {
            ErrorOut "Unable to gather Node.js Version";
        }
        $url="${url}$filename"
        $version = $filename.Substring(0,$filename.Length-"${arch_ver}.msi".Length)
        $pos = $version.IndexOf("v")
        $version = $version.Substring($pos+1)
        LogWrite "Found Latest Version of Node.js - ${version}"
	$save_path = '' + $save_dir + '\' + $filename;
	if(!(Test-Path -pathType container $save_dir)) {
	    ErrorOut "Save directory $save_dir does not exist";
	}
        LogWrite "Downloading Node.js ($arch) $version..."
        DownloadFile $url $save_path
        LogWrite "Node.js downloaded"
	LogWrite "Installing Node.js $version..."
	InstallMSI $save_path
        if(!(Get-IsProgramInstalled "Node.js")) {
           ErrorOut "Node.js did not complete installation successfully...try manually installing it..."
        }
        $global:reboot_needed="true"
        $global:recompile="true"
        LogWrite -color Green "Node.js Installed Successfully"
    } else {
        LogWrite "Node.js already installed."
        LogWrite "Checking version..."
        $installed_version = Get-ProgramVersion( "Node.js" )
        if(!$version) {
            ErrorOut "Node.js Version is Unknown - Error"
        }
        if([System.IntPtr]::Size -eq 4) {
            $arch="32-bit"
            $arch_ver='-x86'
        } else {
            $arch="64-bit"
            $arch_ver='-x64'
        }

        LogWrite "Gathering Latest Node.js for Major Version ${version}..."
        $url = "https://nodejs.org/dist/latest-v${version}.x/"
        $site = Invoke-WebRequest -URI "$url" -UseBasicParsing
        $found=0
        $site.Links | Foreach {
            $url_items = $_.href
            if($url_items -like "*${arch_ver}.msi") {
                $filename=$url_items
                $found=1
            }
        }
        if($found -ne 1) {
            ErrorOut "Unable to gather Node.js Version";
        }
        $url="${url}$filename"
        $version = $filename.Substring(0,$filename.Length-"${arch_ver}.msi".Length)
        $pos = $version.IndexOf("v")
        $version = $version.Substring($pos+1)
        LogWrite "Found Latest Version ${version}"
        $result = CompareVersions $installed_version $version
        if($result -eq "-2") {
            ErrorOut "Unable to match Node.js version (Installed Version: $installed_version / Requested Version: $version)"
        }
        if($result -eq 0) {
            LogWrite "Node.js is already updated. Skipping..."
        } elseif($result -eq 1) {
            LogWrite "Node.js is newer than the recommended version. Skipping..."
        } else {
            LogWrite "Node.js is out of date."
            LogWrite -Color Cyan "Node.js $installed_version will be updated to $version..."
	    $save_path = '' + $save_dir + '\' + $filename;
	    if(!(Test-Path -pathType container $save_dir)) {
	        ErrorOut "Save directory $save_dir does not exist";
	    }
            LogWrite "Downloading Node.js ($arch) $version..."
            DownloadFile $url $save_path
            LogWrite "Nodejs downloaded"
	    LogWrite "Installing Node.js $version..."
	    InstallMSI $save_path
            if(!(Get-IsProgramInstalled "Node.js")) {
               ErrorOut "Node.js did not complete installation successfully...try manually updating it..."
            }
            $global:reboot_needed="true"
            $global:recompile="true"
            LogWrite -color Green "Node.js Updated Successfully"
            $installed_version = $version
        }
        LogWrite -color Green "Node.js Installed Version: $installed_version"
    }
    LogWrite "Checking for Node.js NPM Environment Path..."
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    $PathasArray=($Env:PATH).split(';')
    if ($PathasArray -contains $global:npm_path -or $PathAsArray -contains $global:npm_path+'\') {
    	LogWrite "Node.js NPM Environment Path $global:npm_path already within System Environment Path, skipping..."
    } else {
        $OldPath=(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -ErrorAction SilentlyContinue).Path
        $NewPath=$OldPath+';'+$global:npm_path;
        Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath -ErrorAction SilentlyContinue
        LogWrite "Node.js NPM Environment Path Added: $global:npm_path"
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
        $global:reboot_needed="true"
    }
}

function PythonCheck([string]$version) {
    LogWrite "Checking if Python is installed..."
    if(!(Get-IsProgramInstalled "Python")) {
        LogWrite "Python is not installed."
        if([System.IntPtr]::Size -eq 4) {
            $arch="32-bit"
            $arch_ver=''
        } else {
            $arch="64-bit"
            $arch_ver='.amd64'
        }
        $url = "https://www.python.org/ftp/python/"
        $site = Invoke-WebRequest -URI "$url" -UseBasicParsing
        $last=-1
        $site.Links | Foreach {
            $url_items = $_.href
            if($url_items -like "${version}.*") {
                $filename=$url_items
                $filename=$filename.Substring(0,$filename.Length-1)
                $version_check=$filename.Substring($version.Length+1)
                if($version_check.IndexOf(".") -gt 0) {
                    $pos = $version_check.IndexOf(".")
                    $get_version_part=$version_check.Substring(0,$pos)
                } else {
                    $get_version_part=$version_check
                }
                if([int]$get_version_part -gt [int]$last) {
                    $last=$get_version_part
                }
            }
        }
        $version="${version}.${last}"
        $last=-1
        $site.Links | Foreach {
            $url_items = $_.href
	    if($url_items -like "${version}.*") {
	        $filename=$url_items
	        $filename=$filename.Substring(0,$filename.Length-1)
	        $version_check=$filename.Substring($version.Length+1)
	        if($version_check.IndexOf(".") -gt 0) {
	            $pos = $version_check.IndexOf(".")
	            $get_version_part=$version_check.Substring(0,$pos)
	        } else {
	            $get_version_part=$version_check
	        }
	        if([int]$get_version_part -gt [int]$last) {
	            $last=$get_version_part
	        }
	    }
        }
        $version="${version}.${last}"
        $filename = 'python-' + $version + $arch_ver + '.msi';
        $save_path = '' + $save_dir + '\' + $filename;
        $url='http://www.python.org/ftp/python/' + $version + '/' + $filename;
        if(!(Test-Path -pathType container $save_dir)) {
            ErrorOut "Save directory $save_dir does not exist";
        }
        LogWrite "Downloading Python ($arch) $version..."
        DownloadFile $url $save_path
        LogWrite "Python downloaded"
        LogWrite "Installing Python $version..."
        InstallMSI $save_path
        if(!(Get-IsProgramInstalled "Python")) {
            ErrorOut "Python did not complete installation successfully...try manually installing it..."
        }
        $global:reboot_needed="true"
        $global:recompile="true"
        LogWrite -color Green "Python Installed Successfully"
        $installed_version=$version
    } else {
        LogWrite "Python already installed."
        LogWrite "Checking version..."
        $installed_version = Get-ProgramVersion( "Python" )
        $installed_version = $installed_version.Substring(0,$installed_version.Length-3)
        if(!$installed_version) {
            ErrorOut "Python Version is Unknown - Error"
        }
        if($installed_version.Split(".")[0] -gt "2" -Or $installed_version.Split(".")[0] -lt "2") {
            ErrorOut "Python version not supported.  Please remove all versions of Python and run the script again."
        }
        $url = "https://www.python.org/ftp/python/"
        $site = Invoke-WebRequest -URI "$url" -UseBasicParsing
        $last=-1
        $site.Links | Foreach {
            $url_items = $_.href
            if($url_items -like "${version}.*") {
                $filename=$url_items
                $filename=$filename.Substring(0,$filename.Length-1)
                $version_check=$filename.Substring($version.Length+1)
                if($version_check.IndexOf(".") -gt 0) {
                    $pos = $version_check.IndexOf(".")
                    $get_version_part=$version_check.Substring(0,$pos)
                } else {
                     $get_version_part=$version_check
                }
                if([int]$get_version_part -gt [int]$last) {
                    $last=$get_version_part
                }
            }
        }
        $version="${version}.${last}"
        $last=-1
        $site.Links | Foreach {
            $url_items = $_.href
            if($url_items -like "${version}.*") {
                $filename=$url_items
                $filename=$filename.Substring(0,$filename.Length-1)
                $version_check=$filename.Substring($version.Length+1)
                if($version_check.IndexOf(".") -gt 0) {
                    $pos = $version_check.IndexOf(".")
                    $get_version_part=$version_check.Substring(0,$pos)
                } else {
                     $get_version_part=$version_check
                }
                if([int]$get_version_part -gt [int]$last) {
                    $last=$get_version_part
                }
            }
        }
        $version="${version}.${last}"
        $result = CompareVersions $installed_version $version
        if($result -eq "-2") {
            ErrorOut "Unable to match Python version (Installed Version: $installed_version / Requested Version: $version)"
        }
        if($result -eq 0) {
            LogWrite "Python is already updated. Skipping..."
        } elseif($result -eq 1) {
            LogWrite "Python is newer than the recommended version. Skipping..."
        } else {
            LogWrite "Python is out of date."
            LogWrite -Color Cyan "Python $installed_version will be updated to $version..."
            if ([System.IntPtr]::Size -eq 4) {
                $arch="32-bit"
                $arch_ver=''
            } else {
                $arch="64-bit"
                $arch_ver='.amd64'
            }
	    $filename = 'python-' + $version + $arch_ver + '.msi';
	    $save_path = '' + $save_dir + '\' + $filename;
            $url='http://www.python.org/ftp/python/' + $version + '/' + $filename;
	    if(!(Test-Path -pathType container $save_dir)) {
	        ErrorOut "Save directory $save_dir does not exist";
	    }
            LogWrite "Downloading Python ($arch) $version..."
            DownloadFile $url $save_path
            LogWrite "Python downloaded"
	    LogWrite "Installing Python $version..."
	    InstallMSI $save_path
            if(!(Get-IsProgramInstalled "Python")) {
               ErrorOut "Python did not complete installation successfully...try manually installing it..."
            }
            $global:reboot_needed="true"
            $global:recompile="true"
            LogWrite -color Green "Python Updated Successfully"
            $installed_version=$version
        }
        LogWrite -color Green "Python Installed Version: $installed_version"
    }
    LogWrite "Checking for Python Environment Path..."
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    $PathasArray=($Env:PATH).split(';')
    
    $split_version=$installed_version.split('.')
    $python_path="C:\Python" + $split_version[0] + $split_version[1] + "\"

    if(!(Test-Path -pathType container $python_path)) {
        ErrorOut "Save directory $python_path does not exist";
    }
    
    if($PathasArray -contains $python_path -or $PathAsArray -contains $python_path+'\') {
        LogWrite "Python Environment Path $python_path already within System Environment Path, skipping..."
    } else {
        $OldPath=(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -ErrorAction SilentlyContinue).Path
        $NewPath=$OldPath+';'+$python_path;
        Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath -ErrorAction SilentlyContinue
        LogWrite "Python Environment Path Added: $python_path"
        $global:reboot_needed="true"
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    $PathasArray=($Env:PATH).split(';')
    $python_path=$python_path+"Scripts\";
    if($PathasArray -contains $python_path -or $PathAsArray -contains $python_path+'\') {
        LogWrite "Python Environment Path $python_path already within System Environment Path, skipping..."
    } else {
        $OldPath=(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -ErrorAction SilentlyContinue).Path
        $NewPath=$OldPath+';'+$python_path;
        Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath -ErrorAction SilentlyContinue
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
        LogWrite "Python Environment Path Added: $python_path"
        $global:reboot_needed="true"
    }
}

function VisualStudioCheck([string]$version, [string]$dl_link) {
    LogWrite "Checking if Visual Studio Community Edition is installed..."
    if(!(Get-IsProgramInstalled "Microsoft Visual Studio Community")) {
        LogWrite "Visual Studio Community $version Edition is not installed."
        $filename = 'vs_community_ENU.exe';
	$save_path = '' + $save_dir + '\' + $filename;
	if(!(Test-Path -pathType container $save_dir)) {
	    ErrorOut "Save directory $save_dir does not exist";
	}
        LogWrite "Downloading Visual Studio Community $version Edition..."
        FollowDownloadFile $dl_link $save_path
        LogWrite "Visual Studio Community $version Edition downloaded"
        LogWrite "Installing Visual Studio Community $version Edition..."
        $Arguments = "/InstallSelectableItems NativeLanguageSupport_Group /NoRestart /Passive"
	InstallEXE $save_path $Arguments
        if(!(Get-IsProgramInstalled "Microsoft Visual Studio Community")) {
           ErrorOut "Visual Studio Community $version Edition did not complete installation successfully...try manually installing it..."
        }
        $global:reboot_needed="true"
        LogWrite -color Green "Visual Studio Community $version Edition Installed"
    } else {
        LogWrite "Visual Studio Community $version Edition already installed."
        LogWrite "Checking version..."
        $version_check = Get-ProgramVersion( "Microsoft Visual Studio Community" )
        if(!$version_check) {
            ErrorOut "Visual Studio Community Edition Version is Unknown - Error"
        }
        LogWrite -color Green "Visual Studio Community $version Edition Installed"
    }
    LogWrite "Checking for Visual Studio Community $version Edition Environment Variable..."
    $env:GYP_MSVS_VERSION = [System.Environment]::GetEnvironmentVariable("GYP_MSVS_VERSION","Machine")
    if($env:GYP_MSVS_VERSION) {
        LogWrite "Visual Studio Community $version Edition Environment Variable (GYP_MSVS_VERSION - $env:GYP_MSVS_VERSION) is already set, skipping..."
    } else {
        [Environment]::SetEnvironmentVariable("GYP_MSVS_VERSION", $version, "Machine")
        $env:GYP_MSVS_VERSION = [System.Environment]::GetEnvironmentVariable("GYP_MSVS_VERSION","Machine")
        LogWrite "Visual Studio Community $version Edition Environment Variable Added: GYP_MSVS_VERSION - $env:GYP_MSVS_VERSION"
        $global:reboot_needed="true"
    }
}

function storjshare-cliCheck() {
    LogWrite "Checking if storjshare-cli is installed..."
    $Arguments = "list -g storjshare-cli"
    $output=(UseNPM $Arguments| Where-Object {$_ -like '*storjshare-cli@*'})
    #write npm logs to log file if in silent mode
    if($silent) {
        LogWrite "npm $Arguments results"
        Add-content $storjshare_cli_install_log_file -value $output
    }
    if (!$output.Length -gt 0) {
        LogWrite "storjshare-cli is not installed."

        LogWrite "Stopping $global:svcname service (if applicable)"
        Stop-Service $global:svcname -ErrorAction SilentlyContinue | Out-Null
        $services=Get-Service -Name *storjshare-cli*
        $services | ForEach-Object{Stop-Service $_.name -ErrorAction SilentlyContinue | Out-Null}
        if(Test-Path $global:storjshare_cli_log) {
            LogWrite "Removing Log file: $global:storjshare_cli_log"
            Remove-Item "$global:storjshare_cli_log" -force
        }
        if(Test-Path $storjshare_cli_log_path) {
            LogWrite "Removing Logs files $storjshare_cli_log_path"
            Remove-Item "$storjshare_cli_log_path\*" -force
        }

        LogWrite "Checking for old npm data"
        if(Test-Path "${global:npm_path}etc") {
            LogWrite "Removing Directory ${global:npm_path}etc"
            rm -r "${global:npm_path}etc" -force
        }

        if(Test-Path "${global:npm_path}node_modules") {
            LogWrite "Removing Directory ${global:npm_path}node_modules"
            rm -r "${global:npm_path}node_modules" -force
        }

        if(Test-Path "${global:appdata}npm-cache") {
            LogWrite "Removing Directory ${global:appdata}npm-cache"
            rm -r "${global:appdata}npm-cache" -force
        }

        LogWrite "Installing storjshare-cli (latest version released)..."

        if($global:beta -eq 1) {
            $storjshare_cli_type = "storjshare-cli@next"
        } else {
            $storjshare_cli_type = "storjshare-cli"
        }

        $Arguments = "install -g $storjshare_cli_type"
        $result=(UseNPM $Arguments| Where-Object {$_ -like '*ERR!*'})
        #write npm logs to log file if in silent mode
        if($silent) {
            LogWrite "npm $Arguments results"
            Add-content $storjshare_cli_install_log_file -value $result
        }
        if($result.Length -gt 0) {
            ErrorOut "storjshare-cli did not complete installation successfully...try manually installing it..."
        }

        if($global:recompile) {
            LogWrite "Clearing recompile"
            $global:recompile=""
        }

        if(Test-Path $recompile_file_path) {
            LogWrite "Removing recompile file: $recompile_file_path"
            Remove-Item "$recompile_file_path" -force
        }

        LogWrite -color Green "storjshare-cli Installed Successfully"
    } else {
        LogWrite -color Green "storjshare-cli already installed."
        LogWrite "Checking if storjshare-cli update is needed"
        $Arguments = "outdated -g -depth 1 storjshare-cli"
        $result=(UseNPM $Arguments)
        #write npm logs to log file if in silent mode
        if($silent) {
            LogWrite "npm $Arguments results"
            Add-content $storjshare_cli_install_log_file -value $result
        }
        if ($result.Length -gt 0 -or $global:recompile) {
            LogWrite -color Red "storjshare-cli update needed"
            LogWrite -color Cyan "Performing storjshare-cli Update..."
            LogWrite "Stopping $global:svcname service (if applicable)"
            Stop-Service $global:svcname -ErrorAction SilentlyContinue | Out-Null
            $services=Get-Service -Name *storjshare-cli*
            $services | ForEach-Object{Stop-Service $_.name -ErrorAction SilentlyContinue | Out-Null}
            if(Test-Path $global:storjshare_cli_log) {
                LogWrite "Removing Log file: $global:storjshare_cli_log"
                Remove-Item "$global:storjshare_cli_log" -force
            }
            if(Test-Path $storjshare_cli_log_path) {
                LogWrite "Removing Logs files $storjshare_cli_log_path"
                Remove-Item "$storjshare_cli_log_path\*" -force
            }

            LogWrite "Checking for old npm data"
            if(Test-Path "${global:npm_path}etc") {
                LogWrite "Removing Directory ${global:npm_path}etc"
                rm -r "${global:npm_path}etc" -force
            }

            if(Test-Path "${global:npm_path}node_modules") {
                LogWrite "Removing Directory ${global:npm_path}node_modules"
                rm -r "${global:npm_path}node_modules" -force
            }

            if(Test-Path "${global:appdata}npm-cache") {
                LogWrite "Removing Directory ${global:appdata}npm-cache"
                rm -r "${global:appdata}npm-cache" -force
            }

            if($global:beta -eq 1) {
                $storjshare_cli_type = "storjshare-cli@next"
            } else {
                $storjshare_cli_type = "storjshare-cli"
            }

            $Arguments = "install -g $storjshare_cli_type"
            $result=(UseNPM $Arguments | Where-Object {$_ -like '*ERR!*'})
            if ($result.Length -gt 0) {
                ErrorOut "storjshare-cli did not complete update successfully...try manually updating it..."
            }
            #write npm logs to log file if in silent mode
            if($silent) {
                LogWrite "npm $Arguments results"
                Add-content $storjshare_cli_install_log_file -value $result
            }

           if($global:recompile) {
                LogWrite "Clearing recompile"
                $global:recompile=""
           }

            if(Test-Path $recompile_file_path) {
                LogWrite "Removing recompile file: $recompile_file_path"
                Remove-Item "$recompile_file_path" -force
            }

            LogWrite -color Green "storjshare-cli Update Completed"
            LogWrite "Starting storjshare-cli services"
            $services=Get-Service -Name *storjshare-cli*
            $services | ForEach-Object{Start-Service -Name $_.name -ErrorAction SilentlyContinue}
            Start-Service -Name $global:svcname -ErrorAction SilentlyContinue
            LogWrite -color Green "storjshare-cli services started"
        } else {
            LogWrite -color Green "No update needed for storjshare-cli"
        }
        LogWrite -color Cyan "Checking storjshare-cli version..."
        $Arguments = "list -g storjshare-cli"
        $result=(UseNPM $Arguments)
        if ($result.Length -lt 1) {
            ErrorOut "storjshare-cli did not complete update successfully...try manually updating it..."
        }
        #write npm logs to log file if in silent mode
        if($silent) {
            LogWrite "npm $Arguments results"
            Add-content $storjshare_cli_install_log_file -value $result
        }
        $result=$result.Split('@')
        $version = $result[2]
        LogWrite -color Green "storjshare-cli Installed Version: $version"
    }
    LogWrite -color Cyan "Checking storjshare Version..."
    LogWrite -color Cyan "Placing version into log file..."
    if(!(Test-Path -pathType container $save_dir)) {
    	ErrorOut "Log directory $save_dir does not exist";
    }
    $Arguments="/c storjshare -V"
    if($global:runas) {
        Start-Process "cmd.exe" -Credential $global:credential -WorkingDirectory "$global:npm_path" -ArgumentList $Arguments -RedirectStandardOutput $global:storjshare_cli_log_ver -Wait
    } else {
        Start-Process "cmd.exe" -ArgumentList $Arguments -RedirectStandardOutput $global:storjshare_cli_log_ver -Wait
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:MM:ss"
    Add-Content $global:storjshare_cli_log_ver "Timestamp: $timestamp"
    LogWrite -color Cyan "Version recorded."
}

function Get-IsProgramInstalled([string]$program) {
    $x86 = ((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;

    $x64 = ((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;

    return $x86 -or $x64;
}

function Get-ProgramVersion([string]$program) {
    $x86 = ((Get-ChildItem  -ErrorAction SilentlyContinue "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } |
        Select-Object { $_.GetValue( "DisplayVersion" ) }  )

    $x64 = ((Get-ChildItem  -ErrorAction SilentlyContinue "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } |
        Select-Object { $_.GetValue( "DisplayVersion" ) }  )

    if ($x86) {
        $version = $x86 -split "="
        $version = $version[1].Split("}")[0]
    } elseif ($x64)  {
        $version = $x64 -split "="
        $version = $version[1].Split("}")[0]
    } else {
        $version = ""
    }

    return $version;
}

function DownloadFile([string]$url, [string]$targetFile) {
    if((Test-Path $targetFile)) {
        LogWrite "$targetFile exists, removing it and re-downloading it";
        Remove-Item $targetFile
    }

    $uri = New-Object "System.Uri" "$url"
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $request.set_Timeout(15000) #15 second timeout
    $response = $request.GetResponse()
    $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
    $responseStream = $response.GetResponseStream()
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
    $buffer = new-object byte[] 10KB
    $count = $responseStream.Read($buffer,0,$buffer.length)
    $downloadedBytes = $count
    while ($count -gt 0) {
        $targetStream.Write($buffer, 0, $count)
        $count = $responseStream.Read($buffer,0,$buffer.length)
        $downloadedBytes = $downloadedBytes + $count
        Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
    }
    Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'"
    $targetStream.Flush()
    $targetStream.Close()
    $targetStream.Dispose()
    $responseStream.Dispose()
}

function FollowDownloadFile([string]$url, [string]$targetFile) {
    if((Test-Path $targetFile)) {
        LogWrite "$targetFile exists, using this download";
    } else {
        $webclient = New-Object System.Net.WebClient
        $webclient.DownloadFile($url,$targetFile)
    }
}

function AddLowRiskFiles() {
	New-Item -Path $Lowriskregpath -Erroraction SilentlyContinue | Out-Null
	New-ItemProperty $Lowriskregpath -Name $Lowriskregfile -Value $LowRiskFileTypes -PropertyType String -ErrorAction SilentlyContinue | Out-Null
}

function RemoveLowRiskFiles() {
	Remove-ItemProperty -Path $Lowriskregpath -Name $Lowriskregfile -ErrorAction SilentlyContinue
}

function InstallEXE([string]$installer, [string]$Arguments) {
    Unblock-File $installer
    AddLowRiskFiles
    if($silent) {
        Start-Process "`"$installer`"" -ArgumentList $Arguments -Wait -NoNewWindow
    } else {
        Start-Process "`"$installer`"" -ArgumentList $Arguments -Wait
    }
    RemoveLowRiskFiles
}

function InstallMSI([string]$installer) {
    $Arguments = @()
    $Arguments += "/i"
    $Arguments += "`"$installer`""
    $Arguments += "ALLUSERS=`"1`""
    $Arguments += "/passive"
    $Arguments += "/norestart"
    if($silent) {
        Start-Process "msiexec.exe" -ArgumentList $Arguments -Wait -NoNewWindow
    } else {
        Start-Process "msiexec.exe" -ArgumentList $Arguments -Wait
    }
}

function UseNPM([string]$Arguments) {
    $filename = 'npm_output.log';
    $save_path = '' + $storjshare_cli_install_log_path + '\' + $filename;
    $filename_err = 'npm_output_err.log';
    $save_path_err = '' + $storjshare_cli_install_log_path + '\' + $filename_err;
    if(!(Test-Path -pathType container $storjshare_cli_install_log_path)) {
        ErrorOut "Log directory $storjshare_cli_install_log_path does not exist";
    }
    
    if(!(Test-Path -pathType container $global:npm_path)) {
        New-Item $global:npm_path -type directory -force | Out-Null
    }

    if($global:runas) {
        $proc = Start-Process "npm" -Credential $global:credential -WorkingDirectory "$global:npm_path" -ArgumentList $Arguments -RedirectStandardOutput "$save_path" -RedirectStandardError "$save_path_err"
    } else {
        $proc = Start-Process "npm" -ArgumentList $Arguments -RedirectStandardOutput "$save_path" -RedirectStandardError "$save_path_err"
    }

    Start-Sleep -s 5
    $processnpm=Get-Process | Where-Object { $_.MainWindowTitle -like '*npm*' } | select -expand id
    
    try
    {
        Wait-Process -Id $processnpm -Timeout 600 -ErrorAction SilentlyContinue
    }
    catch
    {
        LogWrite ""
    }
    
    if(!(Test-Path $save_path) -or !(Test-Path $save_path_err)) {
        ErrorOut "npm command $Arguments failed to execute...try manually running it..."
    }
    
    $results=(Get-Content -Path "$save_path")
    $results+=(Get-Content -Path "$save_path_err")

    Remove-Item "$save_path"
    Remove-Item "$save_path_err"

    return $results
}

function CheckRebootNeeded() {
    if($global:reboot_needed) {

        if($global:recompile) {
            LogWrite "Recompile is needed - storing for after reboot"
            Add-content $recompile_file_path -value "recompile needed"
        }

        if($global:autoreboot) {
            LogWrite -color Red "=============================================="
            LogWrite -color Red "Initiating Auto-Reboot in $automatic_restart_timeout seconds"
            Restart-Computer -Wait $automatic_restart_timeout
            ErrorOut -code $error_success_reboot_required "~~~Automatically Rebooting in $automatic_restart_timeout seconds~~~"
        } else {
            LogWrite -color Red "=============================================="
            LogWrite -color Red "~~~PLEASE REBOOT BEFORE PROCEEDING~~~"
            LogWrite -color White "After the reboot, re-launch this script to complete the installation"
            ErrorOut -code $error_success_reboot_required "~~~PLEASE REBOOT BEFORE PROCEEDING~~~"
        } 
    } else {
        LogWrite -color Green "No Reboot Needed, continuing on with script"
    }
}

function CompareVersions([String]$version1,[String]$version2) {
    $ver1 = $version1.Split(".")
    $ver2 = $version2.Split(".")
    if($ver1.Count -ne $ver2.Count) {
        return -2
    }
    for($i=0;$i -lt $ver1.count;$i++) {
        if($($ver1[$i]) -ne $($ver2[$i])) {
            if($($ver1[$i]) -lt $($ver2[$i])) {
                return -1
            } else {
                return 1
            }
        }
    }
    return 0
}

function ModifyService([string]$svc_name, [string]$svc_status) {
    Set-Service $svc_name -startuptype $svc_status   
}

function ChangeLogonService([string]$svc_name, [string]$username, [string]$password) {
    $LocalSrv = Get-WmiObject Win32_service -filter "name='$svc_name'"
    $LocalSrv.Change($null,$null,$null,$null,$null,$false,$username,$password)
    LogWrite "Changed Service $svc_name to Logon As $username"
}
function EnableUPNP() {
    LogWrite -color Cyan "Enabling UPNP..."
    #DNS Client
    ModifyService "Dnscache" "Automatic"
    #Function Discovery Resource Publication
    ModifyService "FDResPub" "Manual"
    #SSDP Discovery
    ModifyService "SSDPSRV" "Manual"
    #UPnP Device Host
    ModifyService "upnphost" "Manual"
    $results=SetUPNP "Yes"
    if($results -eq 0) {
        LogWrite "Attempting Enabling UPNP Old Fashioned Way"
        $results=SetUPNP "Yes" "Old"
        if($results -eq 0) {
            ErrorOut "Enabling UPNP failed to execute...try manually enabling UPNP..."
        } else {
            LogWrite -color Green "UPNP has been successfully enabled"
        }
    } else {
        LogWrite -color Green "UPNP has been successfully enabled"
    }
}

function DisableUPNP() {
    LogWrite -color Cyan "Disabling UPNP..."
    ModifyService "Dnscache" "Automatic"
    ModifyService "FDResPub" "Manual"
    ModifyService "SSDPSRV" "Disabled"
    ModifyService "upnphost" "Disabled"
    $results=SetUPNP "No"
    if($results -eq 0) {
        LogWrite "Attempting Enabling UPNP Old Fashioned Way"
        $results=SetUPNP "No" "Old"
        if($results -eq 0) {
            ErrorOut "Enabling UPNP failed to execute...try manually enabling UPNP..."
        } else {
            LogWrite -color Green "UPNP has been successfully enabled"
        }
        ErrorOut "Disabling UPNP failed to execute...try manually disabling UPNP..."
    } else {
        LogWrite -color Green "UPNP has been successfully disabled"
    }
}

function SetUPNP([string]$upnp_set, [string]$Old) {
    $filename = 'upnp_output.log';
    $save_path = '' + $storjshare_cli_install_log_path + '\' + $filename;
    if(!(Test-Path -pathType container $storjshare_cli_install_log_path)) {
        ErrorOut "Log directory $storjshare_cli_install_log_path does not exist";
    }
    if($Old) {
        if($upnp_set -eq "Yes") {
            $upnp_set_result="enable"
        } else {
            $upnp_set_result="disable"
        }
        $Arguments="firewall set service type=upnp mode=$upnp_set_result"
    } else {
        $Arguments="advfirewall firewall set rule group=`"Network Discovery`" new enable=$($upnp_set)"
    }

    if($silent) {
        $proc = Start-Process "netsh" -ArgumentList $Arguments -RedirectStandardOutput "$save_path" -Wait -NoNewWindow
    } else {
        $proc = Start-Process "netsh" -ArgumentList $Arguments -RedirectStandardOutput "$save_path" -Wait
    }

    if(!(Test-Path $save_path)) {
        ErrorOut "netsh command $Arguments failed to execute...try manually running it..."
    }
    
    $results=(Get-Content -Path "$save_path") | Where-Object {$_ -like '*Ok*'}
    Remove-Item "$save_path"
    if($results.Length -eq 0) {
        return 0
    }
    return 1
}

function CheckUPNP() {
    if(!($global:update)) {
        LogWrite "Checking UPNP Flag..."
        if($global:noupnp) {
            DisableUPNP
        } else {
            EnableUPNP
        }
    } else {
        LogWrite "Skipping UPNP checks, Update function flagged..."
    }
}

function CheckService([string]$svc_name) {
    write-host "Checking if $svc_name Service is installed..."
    if (Get-Service $svc_name -ErrorAction SilentlyContinue) {
        return 1
    } else {
        return 0
    }
}

function RemoveService([string]$svc_name) {
    LogWrite "Checking for service: $svc_name"
    if(CheckService $svc_name -eq 1) {
        Stop-Service $svc_name -ErrorAction SilentlyContinue
        $serviceToRemove = Get-WmiObject -Class Win32_Service -Filter "name='$svc_name'"
        $serviceToRemove.delete()
        if(CheckService $svc_name -eq 1) {
            ErrorOut "Failed to remove $svc_name"
        } else {
            LogWrite "Service $svc_name successfully removed"
        }
    } else {
        LogWrite "Service $svc_name is not installed, skipping removal..."
    }
}

function UseNSSM([string]$Arguments) {
    $filename = 'nssm_output.log';
    $save_path = '' + $storjshare_cli_install_log_path + '\' + $filename;
    if(!(Test-Path -pathType container $storjshare_cli_install_log_path)) {
        ErrorOut "Save directory $storjshare_cli_install_log_path does not exist";
    }
    if($silent) {
        $proc = Start-Process "nssm" -ArgumentList $Arguments -RedirectStandardOutput "$save_path" -Wait -NoNewWindow
    } else {
        $proc = Start-Process "nssm" -ArgumentList $Arguments -RedirectStandardOutput "$save_path" -Wait
    }
    if(!(Test-Path $save_path)) {
        ErrorOut "nssm command $Arguments failed to execute..."
    }
    $results=(Get-Content -Path "$save_path")
    Remove-Item "$save_path"
    return $results
}

function Installnssm([string]$save_location,[string]$arch) {
    if(Test-Path $save_location) {
        LogWrite "Checking for $save_location"
        $filename=Split-Path $save_location -leaf
        $filename=$filename.Substring(0,$filename.Length-4)
        $extracted_folder="$save_dir\$filename"
        if(Test-Path -pathType container $extracted_folder) {
	    LogWrite "Skipping extraction...extracted folder already exists"
	} else {
            LogWrite "Extracting NSSM zip"
            Add-Type -assembly "system.io.compression.filesystem"
            [io.compression.zipfile]::ExtractToDirectory($save_location, $save_dir)
            LogWrite "Extracted NSSM successfully"
        }
        LogWrite "Placing NSSM into $nssm_location"
        Copy-Item "$extracted_folder\$arch\nssm.exe" "$nssm_location"
        if(!(Test-Path "$nssm_location\nssm.exe")) {
            ErrorOut "Failed to place NSSM at $nssm_location"
        }
        LogWrite "NSSM Placed Successfully"
    } else {
        ErrorOut "NSSM installation file does not exist at: $save_location"
    }
}

function nssmCheck([string]$version) {
    if($global:installsvc -or $global:removesvc) {
        LogWrite "Checking if NSSM is installed..."
	if(!(Test-Path $nssm_bin)) {
            LogWrite "NSSM is not installed."
            if ([System.IntPtr]::Size -eq 4) {
                $arch="32-bit"
                $arch_ver='win32'
            } else {
                $arch="64-bit"
                $arch_ver='win64'
            }
	    $filename = 'nssm-' + $version + '.zip';
	    $save_path = '' + $save_dir + '\' + $filename;
            $url='https://nssm.cc/release/' + $filename;
	    if(!(Test-Path -pathType container $save_dir)) {
	        ErrorOut "Save directory $save_dir does not exist"
	    }
            LogWrite "Downloading NSSM $version..."
            DownloadFile $url $save_path
            LogWrite "NSSM downloaded"
            LogWrite "Installing NSSM $version..."
            Installnssm $save_path $arch_ver
            LogWrite -color Green "NSSM Installed Successfully"
        } else {
             LogWrite -color Green "NSSM already installed"
        }
        if(!($global:update)) {
            LogWrite "Checking for $global:svcname to see if it exists"
            if(!(CheckService $global:svcname)) {
                if($global:installsvc) {
                    LogWrite "Checking if storjshare-cli data directory exists..."
	            if(!(Test-Path -pathType container $global:datadir)) {
	                ErrorOut "sorjshare-cli directory $global:datadir does not exist, you may want to setup storjshare-cli first.";
	            }
                    LogWrite "Checking if storjshare-cli log directory exists..."
	            if(!(Test-Path -pathType container $storjshare_cli_log_path)) {
	                ErrorOut "storjshare-cli log directory $storjshare_cli_log_path does not exist, you may want to setup storjshare-cli first.";
	            }
                    LogWrite "Installing service $global:svcname"
                    $Arguments="install $global:svcname $storjshare_bin start --datadir $global:datadir --password $global:storjpassword >> $global:storjshare_cli_log"
                    $results=UseNSSM $Arguments
                    if(CheckService($global:svcname)) {
                        LogWrite -color Green "Service $global:svcname Installed Successfully"
                    } else {
                        ErrorOut "Failed to install service $global:svcname"
                    }
                    if($global:runas) {
                        ChangeLogonService -svc_name $global:svcname -username ".\$global:username" -password $global:password
                    }
                }
                ModifyService "$global:svcname" "Automatic"
                LogWrite "Starting $global:svcname service..."
                Start-Service $global:svcname -ErrorAction SilentlyContinue
            } else {
                LogWrite "Service already exists, skipping..."
                Start-Service $global:svcname -ErrorAction SilentlyContinue
            }
        } else {
            LogWrite "Skipping service functions, in update mode"
        }
    }
}

function GetUserEnvironment([string]$env_var) {
    $filename = 'user_env.log';
    $save_path = '' + $storjshare_cli_install_log_path + '\' + $filename;
    if(!(Test-Path -pathType container $storjshare_cli_install_log_path)) {
        ErrorOut "Save directory $storjshare_cli_install_log_path does not exist";
    }
    $Arguments="/c ECHO $env_var"
    if($silent) {
        $proc = Start-Process "cmd.exe" -Credential $global:credential -Workingdirectory "$env:windir\System32" -ArgumentList $Arguments -RedirectStandardOutput "$save_path" -Wait -NoNewWindow
    } else {
        $proc = Start-Process "cmd.exe" -Credential $global:credential -Workingdirectory "$env:windir\System32" -ArgumentList $Arguments -RedirectStandardOutput "$save_path" -Wait
    }
    if(!(Test-Path $save_path)) {
        ErrorOut "cmd command $Arguments failed to execute...try manually running it..."
    }
    $results=(Get-Content -Path "$save_path")
    Remove-Item "$save_path"
    return $results
}

function Grant-LogOnAsService{
param(
    [string[]] $users
    )
    #Get list of currently used SIDs 
    secedit /export /cfg "$storjshare_cli_install_log_path\tempexport.inf"
    $curSIDs = Select-String "$storjshare_cli_install_log_path\tempexport.inf" -Pattern "SeServiceLogonRight" 
    $Sids = $curSIDs.line 
    $sidstring = ""
    foreach($user in $users){
        $objUser = New-Object System.Security.Principal.NTAccount($user)
        $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
        if(!$Sids.Contains($strSID) -and !$sids.Contains($user)){
            $sidstring += ",*$strSID"
        }
    }
    if($sidstring){
        $newSids = $sids + $sidstring
        LogWrite "New Sids: $newSids"
        $tempinf = Get-Content "$storjshare_cli_install_log_path\tempexport.inf"
        $tempinf = $tempinf.Replace($Sids,$newSids)
        Add-Content -Path "$storjshare_cli_install_log_path\tempimport.inf" -Value $tempinf
        secedit /import /db "$storjshare_cli_install_log_path\secedit.sdb" /cfg "$storjshare_cli_install_log_path\tempimport.inf" 
        secedit /configure /db "$storjshare_cli_install_log_path\secedit.sdb"
 
        gpupdate /force 
    } else {
        LogWrite "No new sids, skipping..."
    }
    del "$storjshare_cli_install_log_path\tempimport.inf" -force -ErrorAction SilentlyContinue
    del "$storjshare_cli_install_log_path\secedit.sdb" -force -ErrorAction SilentlyContinue
    del "$storjshare_cli_install_log_path\tempexport.inf" -force
}

function storjshare-enterdata($processid, [string] $command) {
    [Microsoft.VisualBasic.Interaction]::AppActivate($processid)
    Start-Sleep -s 1
    [System.Windows.Forms.SendKeys]::SendWait("$command{ENTER}")
    Start-Sleep -s 2
}

function setup-storjshare() {
    if(!($global:update)) {
        if(!(Test-Path -pathType container $global:datadir)) {
            if($global:autosetup) {
                if(($global:storjpassword) -AND ($global:datadir)) {
                    $filename = 'storjshare_output.log';
                    $save_path = '' + $storjshare_cli_install_log_path + '\' + $filename;
	            if(!(Test-Path -pathType container $storjshare_cli_install_log_path)) {
                        ErrorOut "Save directory $storjshare_cli_install_log_path does not exist";
	            }
                    LogWrite "storjshare directory $global:datadir does not exist"
                    LogWrite "Performing storjshare Setup in this directory"
                    add-type -AssemblyName microsoft.VisualBasic
                    add-type -AssemblyName System.Windows.Forms
                    LogWrite "Starting storjshare key sequence. Please wait for the dialog to close as this may take a couple minutes."
                    Start-Sleep -s 2
                    $Arguments="setup --datadir $global:datadir --password $global:storjpassword"
                    if($global:runas) {
                        $proc = Start-Process "storjshare" -Credential $global:credential -WorkingDirectory "$global:npm_path" -ArgumentList $Arguments -RedirectStandardOutput "$save_path"
                    } else {
                        $proc = Start-Process "storjshare" -ArgumentList $Arguments -RedirectStandardOutput "$save_path"
                    }
                    if(!(Test-Path $save_path)) {
                        ErrorOut "storjshare command $Arguments failed to execute..."
                    }
                    Start-Sleep -s 3
                    $processstorjshare=Get-Process | Where-Object { $_.MainWindowTitle -like '*\System32\cmd.exe*' } | select -expand id
                    
                    #public ip / hostname (default: 127.0.0.1)
                    storjshare-enterdata -processid $processstorjshare -command "$global:publicaddr"

                    #TCP port number service should use (default: 4000)
                    storjshare-enterdata -processid $processstorjshare -command "$global:svcport"

                    #Use NAT traversal (default: true)
                    storjshare-enterdata -processid $processstorjshare -command "$global:nat"

                    #URI of known seed (default: leave blank)
                    storjshare-enterdata -processid $processstorjshare -command "$global:uri"

                    #Enter path to store configuration (hit enter given argument)
                    storjshare-enterdata -processid $processstorjshare -command ""

                    #Log Level (default 3)
                    storjshare-enterdata -processid $processstorjshare -command "$global:loglvl"

                    #Amount of storage to use (default 2GB)
                    storjshare-enterdata -processid $processstorjshare -command "$global:amt"

                    #Concurrency (default 3)
                    storjshare-enterdata -processid $processstorjshare -command "$global:concurrency"

                    #Payment Address  (default blank)
                    storjshare-enterdata -processid $processstorjshare -command "$global:payaddr"

                    #telemetry (force true and hit enter)
                    storjshare-enterdata -processid $processstorjshare -command "true"

                    #number of tunnel connections (default 3)
                    storjshare-enterdata -processid $processstorjshare -command "$global:tunconns"

                    #TCP port tunnel service (default 0 - random)
                    storjshare-enterdata -processid $processstorjshare -command "$global:tunsvcport"

                    #TCP start tunnel port (default 0 - random)
                    storjshare-enterdata -processid $processstorjshare -command "$global:tunstart"

                    #TCP end tunnel port (default port 0 - random)
                    storjshare-enterdata -processid $processstorjshare -command "$global:tunend"

                    #Path encrypted files (hit enter given argument)
                    storjshare-enterdata -processid $processstorjshare -command ""

                    #password to protect data (hit enter given argument)
                    storjshare-enterdata -processid $processstorjshare -command ""
        
                    $results=(Get-Content -Path "$save_path") | Where-Object {$_ -like '*error*'}

                    if($results) {
                        ErrorOut "storjshare command $Arguments failed to execute..."
                    }
                    Remove-Item "$save_path"
                } else {
                    LogWrite "Missing required parameters; skipping setup..."
                }
            } else {
                LogWrite "Manually going through setup"
                LogWrite "You will be prompted by storjshare to enter various values"
                LogWrite -Yellow "Any questions around these values can be answered on https://github.com/Storj/storjshare-cli"
                $Arguments="setup --datadir $global:datadir --password $global:storjpassword"
                $proc = Start-Process "storjshare" -ArgumentList $Arguments -Wait
                LogWrite "Completed entering storjshare values...moving on"
            }
            LogWrite "Starting $global:svcname service..."
            Start-Service $global:svcname -ErrorAction SilentlyContinue
        } else {
            LogWrite "Skipping storjshare setup; data setup files exist..."
        }
    } else {
        LogWrite "Skipping setup check, in update mode..."
        $services=Get-Service -Name *storjshare-cli*
        $services | ForEach-Object {
            $service=$_.name
            Remove-Item "$storjshare_cli_log_path\$service.log"
            Start-Service -Name $service -ErrorAction SilentlyContinue
        }
        LogWrite "Started services"
    }
}

function storjshare_cli_checkver([string]$script_ver) {
    LogWrite "Checking for Storj Script Version Environment Variable..."
    $env:STORJSHARE_SCRIPT_VER = [System.Environment]::GetEnvironmentVariable("STORJSHARE_SCRIPT_VER","Machine")
    if ($env:STORJSHARE_SCRIPT_VER -eq $script_ver) {
    	LogWrite "STORJSHARE_SCRIPT_VER Environment Variable $script_ver already matches, skipping..."
    } else {
        Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name STORJSHARE_SCRIPT_VER -Value $script_ver -ErrorAction SilentlyContinue
        LogWrite "Storjshare Script Version Environment Variable Added: $script_ver"
    }
}

function autoupdate($howoften) {
    if(!($global:update)) {
        Copy-Item "${automated_script_path}automate_storj_cli.ps1" "$global:npm_path" -force -ErrorAction SilentlyContinue
        LogWrite "Script file copied to $global:npm_path"
        if(!($global:noautoupdate)) {
            $Arguments="-NoProfile -NoLogo -Noninteractive -WindowStyle Hidden -ExecutionPolicy Bypass ""${global:npm_path}automate_storj_cli.ps1"" -silent -update"
            $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument $Arguments
            $trigger =  New-ScheduledTaskTrigger -Daily -At $global:checktime
            Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "storjshare Auto-Update" -Description "Updates storjshare software $howoften at $global:checktime local time" -RunLevel Highest -ErrorAction SilentlyContinue
            LogWrite "Scheduled Task Created"
        } else {
            LogWrite "No autoupdate specified skipping"
        }
    } else {
        LogWrite "Skipping autoupdate, update method on..."
    }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

handleParameters

LogWrite -color Yellow "=============================================="
LogWrite -color Cyan "Performing storjshare-cli Automated Management"
LogWrite -color Cyan "Script Version: $global:script_version"
LogWrite -color Cyan "Github Site: https://github.com/Storj/storj-automation"
LogWrite -color Red "USE AT YOUR OWN RISK"
LogWrite ""
LogWrite -color Yellow "Recommended Versions of Software"
LogWrite -color Cyan "Git for Windows: Latest Version"
LogWrite -color Cyan "OpenSSL for Windows: $openssl_ver"
LogWrite -color Cyan "Node.js - Major Branch: $nodejs_ver"
LogWrite -color Cyan "Python - Major Branch: $python_ver"
LogWrite -color Cyan "Visual Studio: $visualstudio_ver Commmunity Edition"
LogWrite -color Yellow "=============================================="
LogWrite ""
LogWrite -color Cyan "Checking for Pre-Requirements..."
LogWrite ""
LogWrite ""
LogWrite -color Yellow "Reviewing Git for Windows..."
GitForWindowsCheck
LogWrite -color Green "Git for Windows Review Completed"
LogWrite ""
LogWrite -color Yellow "Reviewing OpenSSL for Windows..."
OpenSSLCheck
LogWrite -color Green "OpenSSL for Windows Review Completed"
LogWrite ""
LogWrite -color Yellow "Reviewing Node.js..."
NodejsCheck $nodejs_ver
LogWrite -color Green "Node.js Review Completed"
LogWrite ""
LogWrite -color Yellow "Reviewing Python..."
PythonCheck $python_ver
LogWrite -color Green "Python Review Completed"
LogWrite ""
LogWrite -color Yellow "Reviewing Visual Studio $visualstudio_ver Edition..."
VisualStudioCheck $visualstudio_ver $visualstudio_dl
LogWrite -color Green "Visual Studio $visualstudio_ver Edition Review Completed"
LogWrite ""
LogWrite ""
LogWrite -color Cyan "Completed Pre-Requirements Check"
LogWrite ""
LogWrite -color Yellow "=============================================="
checkRebootNeeded
LogWrite ""
LogWrite -color Cyan "Reviewing storjshare-cli..."
storjshare-cliCheck
LogWrite -color Green "storjshare-cli Review Completed"
LogWrite ""
LogWrite -color Yellow "=============================================="
LogWrite ""
LogWrite -color Cyan "Reviewing UPNP..."
CheckUPNP
LogWrite -color Green "UPNP Review Completed"
LogWrite ""
LogWrite -color Yellow "=============================================="
LogWrite ""
LogWrite -color Cyan "Reviewing storjshare Automated Setup..."
setup-storjshare
LogWrite -color Green "storjshare Automated Setup Review Completed"
LogWrite ""
LogWrite -color Yellow "=============================================="
LogWrite ""
LogWrite -color Cyan "Reviewing Service..."
nssmCheck $nssm_ver
LogWrite -color Green "Service Review Completed"
LogWrite ""
LogWrite -color Yellow "=============================================="
LogWrite ""
LogWrite -color Cyan "Reviewing Script Registry Version..."
storjshare_cli_checkver $global:script_version
LogWrite -color Green "Script Registry Version Completed"
LogWrite ""
LogWrite -color Yellow "=============================================="
LogWrite ""
LogWrite -color Cyan "Reviewing Auto-Update Ability..."
autoupdate $global:howoften
LogWrite -color Green "Auto-Update AbilityReview Completed"
LogWrite ""
LogWrite -color Yellow "=============================================="
LogWrite -color Cyan "Completed storjshare-cli Automated Management"
LogWrite -color Cyan "storjshare-cli should now be running as a windows service."
LogWrite -color Cyan "You can check Control Panel > Administrative Tools -> Services -> storjshare-cli and see if the service is running"
LogWrite -color Cyan "You can also check %WINDIR%\Temp\storj\cli to see if any logs are generating and what the details of the logs are saying"
LogWrite -color Cyan "${global:datadir}farms.db folder should slowly start building up shards (ldb files) if everything is configured properly"
LogWrite ""
LogWrite -color Yellow "=============================================="
ErrorOut -code $global:return_code
