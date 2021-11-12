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



<# Inventory Table
CREATE TABLE TBL_AZSQL_INVENTORY
(
ServerName varchar(300),
DatabaseName varchar(200),
Location varchar(100),
Collation varchar(200), 
Edition varchar(200),
CreationDate varchar(50),
CurrentServiceObjectiveName varchar(100),
SkuName varchar(100),
EarliestRestoreDate varchar(50),
DBstatus varchar(100),
UsedSpace float,
UsedSpacePer float,
AllocatedSpace float,
MaxStorageSize float,
CaptureDateTime varchar(50)
)
#>



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
                
                
                ##Key Parameters To Capture##

                $db_loc = $database.Location
                $db_col = $database.CollationName
                $db_ed  = $database.Edition
                $db_cd  = $database.CreationDate
                $db_SO  = $database.CurrentServiceObjectiveName
                $db_erd =$database.EarliestRestoreDate
                $db_sku =$database.SkuName
                $db_status =$database.Status

                               
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
                $Report | Add-Member -Name "ServerName"   -MemberType NoteProperty -Value $server.ServerName
                $Report | Add-Member -Name "DatabaseName" -MemberType NoteProperty -Value $database.DatabaseName
                $Report | Add-Member -Name "Location"     -MemberType NoteProperty -Value $db_loc
                $Report | Add-Member -Name "Collation"     -MemberType NoteProperty -Value $db_col
                $Report | Add-Member -Name "Edition"       -MemberType NoteProperty -Value $db_Ed
                $Report | Add-Member -Name "CreationDate"     -MemberType NoteProperty -Value $db_cd
                $Report | Add-Member -Name "ServiceObjective"     -MemberType NoteProperty -Value $db_SO
                $Report | Add-Member -Name "EarliestRestoreDate"     -MemberType NoteProperty -Value $db_Erd
                $Report | Add-Member -Name "SKU"         -MemberType NoteProperty -Value $db_sku
                $Report | Add-Member -Name "Status"      -MemberType NoteProperty -Value $db_status
                $Report | Add-Member -Name "UsedSpace" -MemberType NoteProperty -Value $db_UsedSpace
                $Report | Add-Member -Name "UsedSpacePer" -MemberType NoteProperty -Value $db_UsedSpacePercentage
                $Report | Add-Member -Name "AllocatedSpace" -MemberType NoteProperty -Value $db_AllocatedSpace
                $Report | Add-Member -Name "MaximumStorageSize" -MemberType NoteProperty -Value $db_MaximumStorageSize
                ##View the Report
                $OutData += $Report 
                $SqlQuery="INSERT INTO [TBL_AZSQL_INVENTORY] (ServerName,DatabaseName,location,Collation,Edition,CreationDate,CurrentServiceObjectiveName,SkuName,EarliestRestoreDate,DBstatus,UsedSpace,UsedSpacePer,AllocatedSpace,MaxStorageSize,CaptureDateTime) VALUES (" + "'" + $server.ServerName + "'," + "'" +  $database.DatabaseName + "'," + "'" + $db_loc + "'," + "'" + $db_col + "'," + "'" + $db_ed  + "'," + "'" + $db_cd  + "'," + "'" + $db_SO  + "'," + "'" + $db_sku + "'," + "'" + $db_erd + "'," + "'" + $db_status + "'" + "," + $db_UsedSpace + "," + $db_UsedSpacePercentage + "," + $db_AllocatedSpace + "," + $db_MaximumStorageSize + "," + "'" + (Get-Date).ToString('MM/dd/yyyy hh:mm:ss tt') + "'" + ")"
                                                   ##Uncomment below line in case of close monitoring on inventory update"
                                                   write-host $SqlQuery
                                                   Invoke-Sqlcmd $SqlQuery -ServerInstance $LocalInstance -Username $localUser -Password $localPwd -Database $Repositorydb
                                                   Write-Host "Inventory STORED IN DB"


                }
                
            }
        }
        $OutData | Out-GridView -Title "Azure SQL DB Inventory Report"
    }
