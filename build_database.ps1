Add-Type -Path ".\System.Data.SQLite.dll"
$con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
$path = ".\dnaquery.db"
$con.ConnectionString = "Data Source=$path"
$con.Open()

$sql = $con.CreateCommand()

### Build Windows Table ###

$WindowsScanColumns = "'Machine Name' string, `
            'Machine Type' string, `
            'Account Name' string, `
            'Account Display Name' string, `
            'Account Type' string, `
            'Account Category' string, `
            'Account Group' string, `
            'Privileged Domain Group' string, `
            'Pass-the-Hash: Vulnerable' string, `
            'Pass-the-Hash: Hash Found' string, `
            'Causes Vulnerability On # of Machines' string, `
            'Threat Cause' string, `
            'Account Description' string, `
            'Service Account Type' string, `
            'Service Account Description' string, `
            'Compliance Status' string, `
            'Account State' string, `
            'Password Never Expires' string, `
            'Credential Type' string, `
            'Password Length' string, `
            'Password Age' string, `
            'Password Last Set' string, `
            'Last Login Date' string, `
            'Account Expiration Date' string, `
            '# of Keys Found' string, `
            'Last Key Update Date' string, `
            'Key Age (at least)' string, `
            'Key Length' string, `
            'Key Algorithm' string, `
            'SSH Server' string, `
            'Key Comment' string, `
            'Command Run on Login' string, `
            'Key Fingerprint' string, `
            'OS Version' string, `
            'Details' string"
            
$sql.CommandText = "CREATE table WindowsScan($WindowsScanColumns)"
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

### Build Unix Table ###

$UnixScanColumns = "'Machine Name' string, `
                    'Account Name' string, `
                    'Local Mapped Account' string, `
                    'Account Display Name' string, `
                    'Account Type' string, `
                    'Account Category' string, `
                    'Account Group' string, `
                    'Account Description' string, `
                    'Compliance Status' string, `
                    'Account State' string, `
                    'Password Never Expires' string, `
                    'Password Age' string, `
                    'Password Last Set' string, `
                    'Insecure Privilege Escalation' string, `
                    'Insecure Privilege Escalation: Reason' string, `
                    'Last Login Date' string, `
                    'Account Expiration Date' string, `
                    '# of Keys Found' string, `
                    'Last Key Update Date' string, `
                    'Key Age (at least)' string, `
                    'Key Length' string, `
                    'Key Algorithm' string, `
                    'SSH Server' string, `
                    'Key Comment' string, `
                    'Command Run on Login' string, `
                    'Key Fingerprint' string, `
                    'OS Version' string, `
                    'Details' string"
            
$sql.CommandText = "CREATE table UnixScan($UnixScanColumns)"
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

### Buil Domain Table ###

$DomainScanColumns = "'Machine Name' string, `
                    'Account Name' string, `
                    'Account Display Name' string, `
                    'Account Type' string, `
                    'Account Category' string, `
                    'Account Description' string, `
                    'Service Account Type'  string, `
                    'Service Account Description' string, `
                    'SPN Description' string, `
                    'Compliance Status' string, `
                    'Account State' string, `
                    'Password Never Expires' string, `
                    'Password Age' string, `
                    'Password Last Set' string, `
                    'Last Login Date' string, `
                    'Account Expiration Date' string "
            
$sql.CommandText = "CREATE table DomainScan($DomainScanColumns)"
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

### Build Database Table ###

$DatabaseScanColumns = "'Machine Name' string, `
                        'Instance Name' string, `
                        'Instance Version' string, `
                        'Account Name' string, `
                        'Account Type' string, `
                        'Context' string, `
                        'User Name' string, `
                        'Database Name' string, `
                        'Account Category' string, `
                        'Roles' string, `
                        'Permissions' string, `
                        'Account State' string "
            
$sql.CommandText = "CREATE table DatabaseScan($DatabaseScanColumns)"
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

### Build Hardcoded Credentials Table ###

$HardcodedScanColumns = "'Machine Name' string, `
                        'Machine Type' string, `
                        'Application Server' string, `
                        'Application Name' string, `
                        'Site Name' string, `
                        'Account Name' string, `
                        'Hard-Coded in File' string, `
                        'Hard-Coded Credential' string, `
                        'Password Length' int, `
                        'Target System Address' string, `
                        'Target System Type' string, `
                        'OS Version' string, `
                        'Details' string "
            
$sql.CommandText = "CREATE table HardcodedScan($HardcodedScanColumns)"
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

### Build SSH Keys Table ###

$SSHKeysScanColumns = "'Source Machine' string, `
                       'Source Account' string, `
                       'Target Machine' string, `
                       'Target Account' string, `
                       'Account Category' string, `
                       'Account State' string, `
                       'Compliance Status' string, `
                       'Orphan SSH Key?' string, `
                       'Key Length' string, `
                       'Key Algorithm' string, `
                       'Passphrase Encryption' string, `
                       'Key Last Used' string, `
                       'Last Trust Update Date'	string, `
                       'Trust Age (at least)' string, `
                       'Key Age (at least)' string, `
                       'Key Comment' string, `
                       'Command Run on Login' string, `
                       'Private Key Type' string, `
                       'Private Key Path' string, `
                       'Public Key Path' string, `
                       'Key Fingerprint' string, `
                       'Details' string "

$sql.CommandText = "CREATE table SSHKeysScan($SSHKeysScanColumns)"
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

### Build Cloud Users Table ###

$CloudUsersScanColumns = "'User Name' string, `
                       'Type' string, `
                       'ARN' string, `
                       'Access Key ID' string, `
                       'Account Category' string, `
                       'Status' string, `
                       'Compliance Status' string, `
                       'Password Age' double, `
                       'Password Last Set' string, `
                       'Login Profile' string, `
                       'Path' string, `
                       'Groups' string, `
                       'Privilege Policies'	string, `
                       'Creation Date' string, `
                       'Last Used Date' string, `
                       'Details' string "

$sql.CommandText = "CREATE table CloudUsersScan($CloudUsersScanColumns)"
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)