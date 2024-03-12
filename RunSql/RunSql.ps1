<#PSScriptInfo

.VERSION 1.0.0

.GUID dc84dcb3-e230-414e-87e4-0b49a9552582

.AUTHOR andy-mishechkin@github.com

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.DESCRIPTION
 RunSql - GUI script for execution of SQL code and batch files. Just run this script from PowerShell and you'll get the main script GUI.
 This GUI has the next elements:
 Field "Sql Server Instance name" - the name of target SQL Server. Script will try to connect to this SQL Server.
 Field "Port" - port number, which will be used for connecting to SQL Server. SQL Server standart port 1433 using by default.
 Field "SQl Server User Name" - user name which will be used for connection to SQL Server. This field is active, if checkbox "Use SQL Serve authentication" is enabled.
 Field "SQl Server User Password" - password which will be used for connection to SQL Server. This field is active, if checkbox "Use SQL Serve authentication" is enabled.
 Field "Database name" - the name of using database. You can select this name from list, wich will be got using the "Get Databases" button.
 Button "Get Databases" - this button will be used for getting the databases list from SQL Server.
 Checkbox "Use SQL Serve authentication" - if this checkbox is unactive, script will be try to use integrated security with current Windows user.
 Checkbox "Execute T-SQL code" - if this checkbox is active, the field for SQL code enterning is enable. Use this checkbox if you want to execute SQL code directly.
 Checkbox "Execute T-SQL bacth file" - if this checkbox is active, the field for SQL code enterning is disable, and "Browse" button will be active. Use this checkbox if you want to execute SQL batch file.
 Field "T-SQL Code" is used for entering of executed T-SQL code, when checkbox "Execute T-SQL code" is enabled.
 Field "T-SQL batch file" is used for entering of executed T-SQL batch file, when checkbox "Execute T-SQL batch file" is enabled.
 Button "Browse" - this button will be using for selecting the T-SQL batch file, when you enable "Execute T-SQL bacth file" checkbox.
 Checkbox "Disable output" - when this checkbox is enabled, result of T-SQL execution will not show in PowerShell console.
 Button "Clear PowerShell console" is used for clearing the PowerShell console.
 Button "Execute SQL" is used for starting the execution of T-SQL code.

 All execution process will be shown in PowerShell console by default.

.PARAMETER -debug
 When you run RunSql with 'debug' switch (.\RunSql.ps1 -debug), PowerShell will show debug information in PowerShell console.
#>

using namespace System.Drawing;
using namespace System.Data;
using namespace System.Data.SqlClient;
using namespace System.Collections;
using namespace System.Oblect;
using namespace System.IO;
using namespace System.Windows.Forms;
using namespace System.Text;

param([switch]$debug)
Add-Type -AssemblyName System.Windows.Forms -PassThru > $null
Get-Variable -Scope script | Where-Object {$_.Name -like "Sql*"} | Remove-Variable -Scope Script;

$RunSQLVersion = "1.0.0";
$DebugTime = get-date -Format yyyyMMddhhmmss
$Script:DebugFile = ".\DebugLog_${DebugTime}.txt"
if($debug) {
	$global:DebugPreference = "Continue";
}
else {
	$global:DebugPreference = "SilentlyContinue";
}

class SqlExec
{

    [string] [ValidateNotNullOrEmpty()] $Server;
	[int] [AllowNull()] $Port = 1433;
    [string] [ValidateNotNullOrEmpty()] $Db;
    [string] [AllowNull()] $User;
    [string] [AllowNull()] [AllowEmptyString()] $Password;

    hidden [string] $DebugFile = ".\SqlExecDebug_" + (get-date -Format yyyyMMddhhmmss) + ".txt";

	SqlExec([string]$Server, [int]$Port, [string]$db)
    {
	   $this.Init($Server, $Port, $Db, $null, $null);
    }

	SqlExec([string]$Server, [int]$Port, [string]$db, [string]$User, [string]$Password)
    {
       $this.Init($Server, $Port, $Db, $User, $Password);
    }

	hidden [void] Init([string]$Server, [int]$Port, [string]$db, [string]$User, [string]$Password)
	{
		$this.Server = $Server;
		$this.Port = $Port;
		$this.Db = $Db;
		$this.User = $User;
		if (-not [string]::IsNullOrEmpty($User))
		{
			$this.Password = $Password;
		}
	}

    hidden [void] WriteInfo([string]$message, [string]$type)
    {
        switch($type)
        {
            'Info'{ Write-Host $message; }
            'Warning'{ Write-Warning $message; }
            'Error'{ Write-Error $message; }
        }
        if($global:DebugPreference -eq "Continue")
        {
            $message | Out-File $this.DebugFile -Append;
        }
    }

    hidden [void]GuiMessage([string]$message, [string]$header, [string]$button, [string]$buttonType)
    {
        $type = "System.Windows.Forms.MessageBox";
		if (-not ($type -as [type]))
        {
			[System.Reflection.Assembly]::LoadWithPartialName($type) > $null;
		}
		($type -as [type])::Show($message, $header, $button, $buttonType);
    }

	[object] Execute ([string]$Sql)
	{
		if([string]::IsNullOrEmpty($Sql))
		{
			$this.WriteInfo("SQL Query text can't be NULL or empty string","Error");
		}
		$message = "Execute SQL package: `n[${Sql}]";
        $this.WriteInfo($message,'Info');

		$SqlResult = $null;
		$Connection = $this.OpenConnection();
		if($Connection)
		{
			$Command = $this.GetSqlCommand($Connection,0);
			$Command.CommandText = $Sql;
			if(($Sql -like "SELECT*") -or ($Sql -match "`nSELECT\s.+"))
			{
				$SqlResult = $this.RunSelectCommand($Command);
			}
			elseif($Sql -like "USE*")
			{
				$NewDb = ($_.Trim()).Substring(4);
				$this.Db = $NewDb;
			}
			else
			{
				$SqlResult = $this.RunExecuteNonQuery($Command);
			}
			$Connection.Dispose();
		}
		return $SqlResult;
	}

	hidden [SqlConnection] OpenConnection()
	{
		if(-not $this.User)
		{
			$ConnectionString = "Server=$($this.Server),$($this.Port);Database=$($this.Db);Integrated Security=True;";
		}
		else
		{
			$ConnectionString = "Server=$($this.Server),$($this.Port);Database=$($this.Db);User Id=$($this.User);Password='$($this.Password)';";
		}
		$Connection = New-Object SqlConnection;
		$Connection.ConnectionString = $ConnectionString;
		$handler = [SqlInfoMessageEventHandler] {
            if($_.Errors)
            {
                $realErrors = $_.Errors | Where-Object { $_.Class -gt 10 };
                if($realErrors)
                {
                    $ErrorMessages = $realErrors | ForEach-Object { $_ | Out-String };
                    $message = "SQL Server Error:`n" + ($ErrorMessages.Trim() -join "`n");
                    $this.WriteInfo($message,"Warning");
                }
                $message = (($_.Errors | Where-Object { $_.Class -le 10 } | ForEach-Object { $_.Message }) -join "`n");
                $this.WriteInfo($message,"Info");
            }
		}
	    $Connection.add_InfoMessage($handler);
	    $Connection.FireInfoMessageEventOnUserErrors = $true;
		try
		{
			$Connection.Open();
		}
		catch
		{
            $this.GuiMessage("Can't open SqlConnection: $_", "RunSQL Error","OK","Error");
			$Connection = $null;
		}
		return $Connection;
	}

	hidden [SqlCommand] GetSqlCommand([SqlConnection]$Connection, [int]$timeout)
	{
		$Command = New-Object SqlCommand;
		$Command.Connection = $Connection;
		$Command.CommandTimeout = $timeout;
		$Command.CommandText = "SET ROWCOUNT 2000";
		$Command.ExecuteNonQuery();

		return $Command;
	}

	hidden [DataTableCollection] RunSelectCommand([SqlCommand]$Command)
	{
		$Adapter = New-Object SqlDataAdapter;
		$Adapter.SelectCommand = $Command;
		$DataSet = New-Object DataSet;
		$Adapter.Fill($DataSet) > $null;

		return $DataSet.Tables;
	}

	hidden [int] RunExecuteNonQuery([SqlCommand]$Command)
	{
		$Result = $null;
		try
		{
			$Result = $Command.ExecuteNonQuery();
		}
		catch
		{
            $this.GuiMessage("Error of ExecuteNonQuery method: $_", "RunSQL Error","OK","Error");
		}
		return $Result;
	}
}

function Write-DebugInfo
{
    param(
         [Parameter(Mandatory)][string] $message
    )

    if($global:DebugPreference -eq "Continue")
    {
        Write-Debug $message;
        $message | Out-File $Script:DebugFile -Append;
    }
}

function Get-SqlExec
{
	if([string]::IsNullOrEmpty($SqlDbComboBox.Text))
    {
        $Db = 'master';
    }
	else
	{
		$Db = $SqlDbComboBox.Text;
	}
	$SqlServer = $SqlServerTextBox.Text;
	$SqlPort = 	$SqlPortTextBox.Text;

	if($SqlAuthCheckBox.Checked)
    {
        $User = $SqlUserTextBox.Text;
		$Password = $SqlPswdTextBox.Text;
    }

	if($Script:SqlExec)
	{
		Write-DebugInfo -message "SqlExec object is already exists";
		$SqlExec.Server = $SqlServer;
		$SqlExec.Port = $SqlPort;
		$SqlExec.Db =$Db;
		if($SqlAuthCheckBox.Checked)
		{
			$SqlExec.User = $User;
			$SqlExec.Password = $Password;
		}
	}
	else
	{
		$SqlExecArgs = ($SqlServer,$SqlPort,$db)
		if($SqlAuthCheckBox.Checked)
		{
			$SqlExecArgs += $User;
			$SqlExecArgs += $Password;
			$Script:SqlExec = New-Object -TypeName 'SqlExec' -ArgumentList $SqlExecArgs;
		}
	}
}

function Get-SqlPackage
{
	Param(
		[Parameter(Mandatory)][string] $rawSql
	)

	$dontAddToPackage = $false;
	$reader = New-Object StringReader($rawSql);
	$SqlPackage = New-Object StringBuilder;

	do
	{
		$line = $reader.ReadLine();
		if($null -ne $line)
		{
			if(($line -replace"[^a-z]") -eq 'go')
			{
				Invoke-Sql -SqlPackage ($SqlPackage.ToString());
				$SqlPackage.Clear();
			}
			else
			{
				if($line.Trim() -eq '/*')
				{
					Write-DebugInfo -message "Commented block started";
					$dontAddToPackage = $false;
				}
				elseif($line.Trim() -eq '*/')
				{
					Write-DebugInfo -message "Commented block is finished";
					$dontAddToPackage = $true;
				}

				if(($line -notlike "--*") -and	(-not $dontAddToPackage))
				{
					Write-DebugInfo -message "Line [$line] will be added to SQL package";
					$SqlPackage.AppendLine($line) > $null;
				}
				else
				{
					Write-DebugInfo -message "Line [$line] has been skipped";
				}
			}
		}
		elseif($SqlPackage.ToString())
		{
			Invoke-Sql -SqlPackage ($SqlPackage.ToString());
			$SqlPackage.Clear();
		}
	} while($null -ne $line);
}

function Invoke-Sql
{
	param(
		[Parameter(Mandatory)][string][ValidateNotNullOrEmpty()] $SqlPackage
	)

	Write-DebugInfo -message "Sql Package: $SqlPackage";
	Get-SqlExec
    try
    {
	    [object]$SqlResult = $Script:SqlExec.Execute($SqlPackage);
	}
    catch [SqlException]
    {
        [MessageBox]::Show("Can't open connection. See message in PowerShell console for details", "RunSQL Error",[MessageBoxButtons]::OK,[MessageBoxIcon]::Error);
        return;
    }

    if($SqlResult)
	{
		if($DisableOutputCheckBox.Checked)
		{
			return;
		}
		else
		{
			if($SqlResult.ToString() -eq  'System.Data.DataTableCollection')
			{
				Show-Result -TableCollection $SqlResult -Title $SqlPackage;
			}
		}
	}
}

function Show-Result
{
	param(
		[Parameter(Mandatory)][System.Data.DataTableCollection] $TableCollection,
		[Parameter()][string] $Title
	)
	if($Tables.Count -gt 0)
	{
		foreach($Table in $Tables)
		{
			$Rows = $Table.Rows;
			Write-DebugInfo -message "Total Rows: $($Rows.Count)";
			if($Rows.Count -eq 0)
			{
				[MessageBox]::Show("Table contains no data", $Title,[MessageBoxButtons]::OK,[MessageBoxIcon]::Warning);
				continue;
			}

			if(Test-Path "$env:SystemRoot\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe")
			{
				$Table | Out-GridView -Title $Title;
			}
            else
			{
				$Table | Format-Table -AutoSize;
			}
		}
	}
	else
	{
		[MessageBox]::Show("No tables was returned", "RunSQL Message",[MessageBoxButtons]::OK,[MessageBoxIcon]::Warning);
	}
}

#-----------------------------------
#          RunSql GUI
#-----------------------------------

function Add-GuiElement
{
    param(
        [Parameter(Mandatory)][string] $Type,
        [Parameter(Mandatory)][hashtable] $ElementProperties
    )
    $GuiElement = New-Object System.Windows.Forms.$Type;
    $ElementProperties.GetEnumerator() | ForEach-Object {
        $Property = $_;
        if($GuiElement | Get-Member | Where-Object { $_.Name -eq $($Property.key)})
        {
            $GuiElement.$($Property.Key) = $Property.Value;
        }
    }
    $GuiElement;
}

function Get-DBList
{
	Get-SqlExec;

	$SqlDbComboBox.Items.Clear();
	$DbList = ($Script:SqlExec.Execute("SELECT name FROM sys.databases"))[0];
	foreach($Db in $DbList.Rows)
    {
        $SqlDbComboBox.Items.Add($Db.Name) > $null;
    }
}

function Get-SqlFile
{
    $FileName = Add-GuiElement -Type 'OpenFileDialog' -ElementProperties @{Filter = "T-SQL files (*.sql)|*.sql|All files (*.*)|*.*"; FilterIndex = 1};
    $FileName.ShowDialog();
    $SqlFileTextBox.Text = $FileName.FileName;
}

$MainFormSubElements = @();
$MainGroups = New-Object ArrayList;

#SQL Server Main Form Elements
$SqlServerMainGroupElements = New-Object ArrayList;
$SqlServerMainGroupElements.Add(
    @{
        GroupId = 'SqlServer';
        TextBox = @{ Name = 'SqlServerTextBox'; Location = New-Object Point(7, 15); Size = New-Object Size(150, 20); Text = 'local'; Enabled = $true };
        GroupBox = @{ Name = 'SqlServerGroupBox'; Location = New-Object Point(12, 15); Size = New-Object Size(165, 40); Text = 'SQL Server Instance Name'; Visible = $true }
    }) > $null;
$SqlServerMainGroupElements.Add(
    @{
        GroupId = 'SqlPort';
        TextBox = @{ Name = 'SqlPortTextBox'; Location = New-Object Point(7, 15); Size = New-Object Size(40, 20); Text = '1433'; Enabled = $true };
        GroupBox = @{ Name = 'SqlPortGroupBox'; Location = New-Object Point(190, 15); Size = New-Object Size(60, 40); Text = 'Port'; Visible = $true }
    }) > $null;
$SqlServerMainGroupElements.Add(
    @{
        GroupId = 'SqlDb'
        ComboBox = @{ Name = 'SqlDbComboBox'; Location = New-Object Point(7, 15); Size = New-Object Size(224, 20); DropDownWidth = 50; ArrItems = $DbList; Enabled = $true };
        GroupBox = @{ Name = 'SqlDbGroupBox'; Location = New-Object Point(12, 60); Size = New-Object Size(239, 40); Text = 'Database Name'; Visible = $true }
    }) > $null;
$SqlServerMainGroupElements.Add(
    @{
        GroupId = 'SqlUser';
        TextBox = @{Name = "SqlUserTextBox"; Location = New-Object Point(7, 15); Size = New-Object Size(175, 20); Enabled = $true};
        GroupBox = @{Name = "SqlUserGroupBox"; Location = New-Object Point(270, 15); Size = New-Object Size(190, 40); Text = "SQL Server User Name"; Visible = $true }
    }) > $null;
$SqlServerMainGroupElements.Add(
    @{
        GroupId = 'SqlPswd';
        TextBox = @{Name = "SqlPswdTextBox"; Location = New-Object Point(7, 15); Size = New-Object Size(175, 20); PasswordChar = '*'; Enabled = $true };
        GroupBox = @{Name = "SqlPswdGroupBox"; Location = New-Object Point(270, 60); Size = New-Object Size(190, 40); Text = "SQL Server User Password"; Visible = $true }
    }) > $null;
$SqlServerMainGroupElements.Add(
    @{
        GroupId = $null;
        CheckBox = @{Name = "SqlAuthCheckBox"; Location = New-Object Point(270, 110); Size = New-Object Size(190, 20); Text = "Use SQL Server authentification"; Enabled = $true; Checked = $true }
    }) > $null;
$SqlServerMainGroupElements.Add(
    @{
        GroupId = $null;
        Button = @{Name = "SqlGetDbsButton"; Location = New-Object Point(10, 107); Size = New-Object Size(100, 23); Text = "Get databases"; Enabled = $true }
    }) > $null;
$SqlServerMainGroupParams = @{ Name="SqlServerMainGroupBox"; Location = New-Object Point(10, 10); Size = New-Object Size(470, 140); Text="Microsoft SQL Server" };
$MainGroups.Add(@($SqlServerMainGroupParams,$SqlServerMainGroupElements)) > $null;

#T-SQL Code processing elements
$SqlExecMainGroupElements = New-Object System.Collections.ArrayList;
$SqlExecMainGroupElements.Add(
    @{
        GroupId = 'SqlCode';
        RichTextBox = @{Name = "SqlCodeTextBox"; Location = New-Object Point(7, 20); Size = New-Object Size(435, 250); Text = ''; Multiline = $true; Enabled = $true; ShortcutsEnabled = $true};
        GroupBox = @{Name="SqlCodeGroupBox"; Location = New-Object Point(12, 60); Size = New-Object Size(450, 290); Text = "T-SQL code"; Visible = $true}
    }) > $null;
$SqlExecMainGroupElements.Add(
    @{
        GroupId = $null;
        CheckBox = @{Name = "SqlCodeCheckBox"; Location = New-Object Point(10, 20); Size = New-Object Size(244, 20); Text = "Execute T-SQL code"; Enabled = $true; Checked = $true }
    }) > $null;
$SqlExecMainGroupElements.Add(
    @{
        GroupId = 'SqlFile';
        TextBox = @{Name = "SqlFileTextBox"; Location = New-Object Point(7, 20); Size = New-Object Size(345, 20); Text=''; Enabled = $true; };
        Button = @{Name = "SqlFileButton"; Location = New-Object Point(360, 19); Size = New-Object Size(70, 30); Text = "Browse"; Enabled = $true };
        GroupBox = @{Name="SqlFileGroupBox"; Location = New-Object Point(10, 70); Size = New-Object Size(450, 80); Text="T-SQL batch file"; Visible = $false }
    }) > $null;
$SqlExecMainGroupElements.Add(
    @{
        GroupId = $null;
        CheckBox = @{Name = "SqlFileCheckBox"; Location = New-Object Point(10, 40); Size = New-Object Size(244, 20); Text = "Execute T-SQL batch file"; Checked = $false}
    }) > $null;
$SqlExecMainGroupParams = @{Name="SqlExecMainGroupBox"; Location = New-Object Point(12, 160); Size = New-Object Size(470, 360); Text="T-SQL code execution"};
$MainGroups.Add(@($SqlExecMainGroupParams,$SqlExecMainGroupElements)) > $null;

Write-Debug "Building the GUI"
$MainGroups | ForEach-Object {
    $MainGroupBox = Add-GuiElement -Type 'GroupBox' -ElementProperties $_[0];
    foreach($SubElementParams in $_[1])
    {
        Write-Debug "==============================="
        Write-Debug "GUI elements creation";
        $SubElementParams.Keys | ForEach-Object {
            Write-Debug "-------------------------------"
            Write-Debug "Element Key: [$_]";
            if($_ -ne 'GroupId')
            {
                #$Script:GroupId = $null;

                $Params = $SubElementParams[$_];
                $ElementName = $Params.Name;
                Write-Debug "Creation the element [$ElementName]";
                New-Variable -Name $ElementName -Scope Script -Value (Add-GuiElement -Type $_ -ElementProperties $Params);
                switch($ElementName)
                {
                    'SqlAuthCheckBox'
                    {
                        $SqlAuthCheckBox.add_CheckedChanged( {($SqlUserGroupBox,$SqlPswdGroupBox) | ForEach-Object { $_.Enabled = $SqlAuthCheckBox.Checked }});
                    }
                    'SqlGetDbsButton'
                    {
                        $SqlGetDbsButton.add_Click({Get-DBList});
                    }
                    'SqlCodeCheckBox'
                    {
                        $SqlCodeCheckBox.add_CheckedChanged({
                            $SqlCodeGroupBox.Visible = $SqlCodeCheckBox.Checked;
                            $SqlFileGroupBox.Visible = -not $SqlCodeCheckBox.Checked;
                            $SqlFileCheckBox.Checked = -not $SqlCodeCheckBox.Checked;
                            $DisableOutputCheckBox.Checked = $false;
                        })
                    }
                    'SqlFileCheckBox'
                    {
                        $SqlFileCheckBox.add_CheckedChanged({
                            $SqlFileGroupBox.Visible = $SqlFileCheckBox.Checked;
                            $SqlCodeGroupBox.Visible = -not $SqlFileCheckBox.Checked;
                            $SqlCodeCheckBox.Checked = -not $SqlFileCheckBox.Checked;
                            $DisableOutputCheckBox.Checked = $true;
                        })
                    }
                    'SqlFileButton'
                    {
                        $SqlFileButton.add_Click({Get-SqlFile});
                    }
                }
            }
            else
            {
                $Script:GroupId = $SubElementParams[$_];
                Write-Debug "Setting the GroupId: [$($Script:GroupId)]";
            }
        }
        Write-Debug "=======================================";
        Write-Debug "Adding the GUI elements to main group boxes";

        if(-not ([string]::IsNullOrEmpty($Script:GroupId)))
        {
            $GroupBox = Get-Variable "${GroupId}GroupBox" -Scope Script -ValueOnly;
            Write-Debug "Processing GroupBox [$GroupId]";
            Get-Variable -Include "${GroupId}TextBox", "${GroupId}ComboBox", "${GroupId}CheckBoxBox", "${GroupId}Button" -Scope Script -ValueOnly | ForEach-Object {
                Write-Debug "Adding the element [$($_.Name)] to group box [$($GroupBox.Name)]";
                $GroupBox.Controls.Add($_);
            };
            Write-Debug "Adding the group box [$($GroupBox.Name)] to [$($MainGroupBox.Name)] group box";
            $MainGroupBox.Controls.Add($GroupBox) > $null;
        }
        else
        {
            Write-Debug "Adding the element [$ElementName] to [$($MainGroupBox.Name)] group box";
            $MainGroupBox.Controls.Add((Get-Variable -Name $ElementName -Scope Script -ValueOnly));
        }
    }
    $MainFormSubElements += $MainGroupBox;
}
Write-Debug "Creation the [Disable Output] checkbox";
$DisableOutputCheckBox = Add-GuiElement -Type 'CheckBox' -ElementProperties @{ Name = "DisableOutput"; Location = New-Object System.Drawing.Point(30, 530); Size = New-Object System.Drawing.Size(100, 20); Text = "Disable output"; Enabled = $true };
$MainFormSubElements += $DisableOutputCheckBox;

$SqlCodeTextBox.Add_MouseUP(
	{
		$SqlCodeContexMenu = New-Object ContextMenu;
		("Cut","Copy","Paste") | ForEach-Object {
			$menuItem = New-Object MenuItem($_);
			switch($_)
			{
				'Cut'
				{
					$menuItem.Add_Click({$SqlCodeTextBox.Cut()});
				}
				'Copy'
				{
					if($SqlCodeTextBox.Text)
					{
						$menuItem.Add_Click({[System.Windows.Forms.Clipboard]::SetText($SqlCodeTextBox.SelectedText)});
					}
				}
				'Paste'
				{
					$menuItem.Add_Click({
						if([System.Windows.Forms.Clipboard]::ContainsText())
						{
							$SqlCodeTextBox.Text += [System.Windows.Forms.Clipboard]::GetText();
						}
					})
				}
			}
			$SqlCodeContexMenu.MenuItems.Add($menuItem);
		}
		$SqlCodeTextBox.ContextMenu = $SqlCodeContexMenu;
	}
)
Write-Debug "Creation the [Exec] button";
$ExecButton = Add-GuiElement -Type 'Button' -ElementProperties @{ Name = "Exec"; Location = New-Object System.Drawing.Point(361, 530); Size = New-Object System.Drawing.Size(100, 23); Text = "Execute SQL"; Enabled = $true };
$ExecButton.add_Click({
	if($SqlCodeCheckBox.Checked -eq $true)
	{
		$rawSql = $SqlCodeTextBox.Text;
	}
	elseif($SqlFileCheckBox.Checked -eq $true)
	{
		$rawSql = ([file]::OpenText($SqlFileTextBox.Text)).ReadToEnd();
	}
	Get-SqlPackage -rawSql $rawSql;
})
$MainFormSubElements += $ExecButton;

$ClsButton = Add-GuiElement -Type 'Button' -ElementProperties @{ Name = "Cls"; Location = New-Object System.Drawing.Point(200, 530); Size = New-Object System.Drawing.Size(150, 23); Text = "Clear PowerShell console"; Enabled = $true };
$ClsButton.add_Click({Clear-Host})
$MainFormSubElements += $ClsButton;

Write-Debug "Creation the main GUI form";
$MainForm = new-object System.Windows.Forms.form;
$MainForm.Size = new-object System.Drawing.Size @(510,600);
$MainForm.MaximizeBox = $false;
$MainForm.SizeGripStyle = [System.Windows.Forms.SizeGripStyle]::Hide;
$MainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle;
$MainForm.Icon = [system.drawing.icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe");
$MainForm.Text = "RunSQL " + $RunSQLVersion;
if($debug)
{
    $MainForm.Text = $MainForm.Text + ' (Debug mode)';
}

$MainFormSubElements | ForEach-Object { $MainForm.Controls.Add($_) };
$MainForm.ShowDialog() > $null;


