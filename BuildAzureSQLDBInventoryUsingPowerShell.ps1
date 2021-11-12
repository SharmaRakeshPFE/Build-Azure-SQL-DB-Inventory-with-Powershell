##Author - Rakesh Sharma ##
##Version - 1.0 ##
##Free to Use with caution - No Gurantee test it on Dev Enviornment##
##Build Your Inventory of Azure SQL Databases"
##Provide the name of the Local Instance to store the data##
##This local SQL Server will be used to store the inventory"

$LocalInstance ='MININT-B7K1QNM\SQL01'

##Provide the name of the database to read credential to connect to Azure SQL Servers##
$Repositorydb='GET_AZURESQL_STATS'
##Provide the credential to connect to local repository##
$localUser='sa'
$localPwd='sa'

##Connect to Azure in case you are not connecting using Profile 
##How to connect to Azure without login primpr - https://github.com/SharmaRakeshPFE/Get_Azure_Resources_Information_Using_Azure-Profile 
#Connect-AzAccount

$OutData = @()
##List of Databases to be ignored --The script will fail in case Dedicated Synapse Pool
##Filter at resource type did not worked as they both fal under SQLServer\Databases\ namespae
$ExcludeDB = @('master','SynapseLab','myworkshopsynapse','SynapseLab_2021-10-13T09-54Z')

##Allowed to Select only Single Subscription from the Grid and then Click OK"

$Subscription = Get-AzSubscription | Out-GridView -OutputMode 'Single'
if($Subscription){
    $Subscription | Select-AzSubscription

##Allowed to Select multiple Logical SQL Server from the Grid and then Click OK"
    $AzSqlServer = Get-AzSqlServer | Out-GridView -OutputMode Multiple
    if($AzSqlServer)
    {
        Foreach ($server in $AzSqlServer)
        {
            $SQLDatabase = Get-AzSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName | Where-Object { $_.DatabaseName -notin $ExcludeDB }
            
            Foreach ($database in $SQLDatabase)  
            {
                Write-Host $database.DatabaseName
                $db_resource = Get-AzResource -ResourceId $database.ResourceId 
             
                 # Database maximum storage size
                $db_MaximumStorageSize = $database.MaxSizeBytes / 1GB

                # Database used space
                $db_metric_storage = $db_resource | Get-AzMetric -MetricName 'storage' -WarningAction SilentlyContinue
                $db_UsedSpace = $db_metric_storage.Data.Maximum | Select-Object -Last 1
                $db_UsedSpace = [math]::Round($db_UsedSpace / 1GB, 2)

                # Database used space procentage
                $db_metric_storage_percent = $db_resource | Get-AzMetric -MetricName 'storage_percent' -WarningAction SilentlyContinue
                $db_UsedSpacePercentage = $db_metric_storage_percent.Data.Maximum | Select-Object -Last 1

                # Database allocated space
                $db_metric_allocated_data_storage = $db_resource | Get-AzMetric -MetricName 'allocated_data_storage' -WarningAction SilentlyContinue
                $db_AllocatedSpace = $db_metric_allocated_data_storage.Data.Average | Select-Object -Last 1
                $db_AllocatedSpace = [math]::Round($db_AllocatedSpace / 1GB, 2) 
                $Report = New-Object PSObject
                $Report | Add-Member -Name "ServerName" -MemberType NoteProperty -Value $server.ServerName
                $Report | Add-Member -Name "DatabaseName" -MemberType NoteProperty -Value $database.DatabaseName
                $Report | Add-Member -Name "UsedSpace" -MemberType NoteProperty -Value $db_UsedSpace
                $Report | Add-Member -Name "UsedSpacePer" -MemberType NoteProperty -Value $db_UsedSpacePercentage
                $Report | Add-Member -Name "AllocatedSpace" -MemberType NoteProperty -Value $db_AllocatedSpace
                $Report | Add-Member -Name "MaximumStorageSize" -MemberType NoteProperty -Value $db_MaximumStorageSize
                ##View the Report
                $OutData += $Report
                $SqlQuery="INSERT INTO [TBL_AZSQL_INVENTORY] (ServerName,DatabaseName,UsedSpace,UsedSpacePer,AllocatedSpace,MaxStorageSoze,CaptureDateTime) VALUES (" + "'" + $server.ServerName + "'," + "'" +  $database.DatabaseName + "'," + $db_UsedSpace + "," + $db_UsedSpacePercentage + "," + $db_AllocatedSpace + "," + $db_MaximumStorageSize + "," + "'" + (Get-Date).ToString('MM/dd/yyyy hh:mm:ss tt') + "'" + ")"
                                                   ##Uncomment below line in case of close monitoring on inventory update"
                                                   ##write-host $SqlQuery_1
                                                   Invoke-Sqlcmd $SqlQuery -ServerInstance $LocalInstance -Username $localUser -Password $localPwd -Database $Repositorydb
                                                   Write-Host "Inventory STORED IN DB"


                }
                
            }
        }
        $OutData | Out-GridView
    }
