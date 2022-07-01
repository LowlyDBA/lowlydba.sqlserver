#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils
#Requires -Modules @{ ModuleName="dbatools"; ModuleVersion="1.1.108" }
#Requires -Modules @{ ModuleName="dbops"; ModuleVersion="0.8.0" }

$spec = @{
    supports_check_mode = $true
    options = @{
        database = @{type = 'str'; required = $true }
        path = @{type = 'str'; required = $true }
        deployment_method = @{type = 'str'; required = $false; default = 'NoTransaction'; choices = @('NoTransaction', 'SingleTransaction', 'TransactionPerScript') }
        schema_version_table = @{type = 'str'; required = $false }
        no_log_version = @{type = 'bool'; required = $false; default = $false }
        connection_timeout = @{type = 'int'; required = $false; default = 0 }
        execution_timeout = @{type = 'int'; required = $false; default = 0 }
        configuration = @{type = 'str'; required = $false }
        output_file = @{type = 'str'; required = $false }
        create_database = @{type = 'bool'; required = $false; default = $false }
        no_recurse = @{type = 'bool'; required = $false; default = $false }
        match = @{type = 'str'; required = $false }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$database = $module.Params.database
$schemaVersionTable = $module.Params.schema_version_table
$path = $module.Params.path
$configuration = $module.Params.configuration
$outputFile = $module.Params.output_file
$match = $module.Params.match
$connectionTimeout = $module.Params.connection_timeout
$executionTimeout = $module.Params.execution_timeout
$createDatabase = $module.Params.create_database
$noRecurse = $module.Params.no_recurse
$noLogVersion = $module.Params.no_log_version
$checkMode = $module.Checkmode
$PSDefaultParameterValues = @{ "*:Confirm" = $false; "*:WhatIf" = $checkMode }

try {
    $installSplat = @{
        SqlInstance = $sqlInstance
        Credential = $sqlCredential
        Database = $database
        Path = $path
        ConnectionTimeout = $connectionTimeout
        ExecutionTimeout = $executionTimeout
        CreateDatabase = $createDatabase
        NoRecurse = $noRecurse
        Silent = $true
    }
    if ($schemaVersionTable) {
        $installSplat.Add("SchemaVersionTable", $schemaVersionTable)
    }
    if ($configuration) {
        $installSplat.Add("Configuration", $configuration)
    }
    if ($outputFile) {
        $installSplat.Add("OutputFile", $outputFile)
    }
    if ($match) {
        $installSplat.Add("Match", $match)
    }
    if ($noLogVersion) {
        $installSplat.SchemaVersionTable = $null
    }

    $output = Install-DboScript @installSplat
    if ($output.DeploymentLog[-1] -ne "No new scripts need to be executed - completing.") {
        $module.Result.changed = $true

        if ($null -ne $output) {
            $resultData = ConvertTo-SerializableObject -InputObject $output
            $module.Result.data = $resultData
        }
    }

    $module.ExitJson()
}
catch {
    $module.FailJson("Failed migration script(s) execution: $($_.Exception.Message)", $_)
}
