# RunSlq.ps1 - script for execution of T-SQL code. 
This script is designed to execute T-SQL code on local and remote SQL server. 
I've created this one for some implementation tasks, where I should execute something on SQL Server, but
I had no SQL Server Managent Studio installed on machine.
In this script I decided to created GUI and this was my study of possibilities of PowerShell in GUI creation.
# Script GUI description
Just run this script from PowerShell and you'll get the main script GUI.
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
Button "Execute SQL" is used for starting the execution of T-SQL code. All execution process will be shown in PowerShell console by default.