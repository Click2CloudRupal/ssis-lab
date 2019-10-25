$ServerName = '.'
$JobPattern = "ssisjob"
$AzureDBName = 'labserverzqboa73y2zauw.database.windows.net'
$AzureDBPassword = 'Pa$$w0rd'
$SubscriptionName = "yoursubscriptionname"
$ResourceGroupName = "adf-ssis-lab"
$DataFactoryName = "labadfzqboa73y2zauw"
$AzureSSISName = "SPAzureSsisIR"
$PipelineTemplate = "C:\labfiles\migrateagentjob\pipeline.json"
$PipelinePath = "C:\labfiles\migrateagentjob\myPipeline.json"
$TriggerTemplate = "C:\labfiles\migrateagentjob\trigger.json"
$TriggerPath = "C:\labfiles\migrateagentjob\myTrigger.json"
$runtimeState = "Started"

Connect-AzAccount -SubscriptionName $SubscriptionName

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo') | Out-Null
$server = New-Object "Microsoft.SqlServer.Management.Smo.Server" $ServerName

Write-Output "Creating ADF pipelines/triggers for SSIS jobs:"
$jobs = $server.JobServer.Jobs
for ($i=0; $i -lt $jobs.Count; $i++) {
    if ($jobs.Item($i).Name -match $JobPattern) {
        Write-Output $jobs.Item($i).Name
        $job = $jobs.Item($i)

        $steps = $job.JobSteps
        for ($j=0; $j -lt $steps.Count; $j++) {
            $step = $steps.Item($j)

            $cmd = $step.Command
            #Write-Output '$Cmd: ' $cmd
            if ($cmd.StartsWith("/ISSERVER")) {
                $start = "/ISSERVER ".Length + 4 + "SSISDB/".Length
                $PackagePath = $cmd.Substring($start, $cmd.IndexOf(" /SERVER") - 3 -$start)
                $PackagePath = $packagePath.Replace('\', '/')
            }
            #$start = $cmd.IndexOf("/Par ")
            #$parameter0 = $cmd.Substring($cmd.IndexOf("/Par ") + "/Par ".Length)
            #$parameter0 = $parameter0.Substring(0, $parameter0.IndexOf("/Par"))
            #$name = $parameter0.Substring(0, $parameter0.IndexOf(";"))
            #$value = $parameter0.Substring($parameter0.IndexOf(";") + 1)

            $pipeline = [System.IO.File]::ReadAllText($PipelineTemplate)
            $pipeline = $pipeline.Replace('##PipelineName##', $job.Name)
            $pipeline = $pipeline.Replace('##ActivityName##', $step.Name)
            $pipeline = $pipeline.Replace('##AzureSSISName##', $AzureSSISName)
            $pipeline = $pipeline.Replace('##PackagePath##', $PackagePath)
            $pipeline = $pipeline.Replace('##AzureDBName##', $AzureDBName)
            $pipeline = $pipeline.Replace('##AzureDBPassword##', $AzureDBPassword)
            #$pipeline = $pipeline.Replace('##ParameterName##', $name)
            #$pipeline = $pipeline.Replace('##ParameterValue##', $value)
            [System.IO.File]::WriteAllText($PipelinePath, $pipeline)

            Set-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -DefinitionFile $PipelinePath -Name $job.Name 
        }
        $schedules = $job.JobSchedules
        for ($k=0; $k -lt $schedules.Count; $k++) {
            $schedule = $schedules.Item($k)

            $startTime = $schedule.ActiveStartDate.ToUniversalTime().ToString("yyyy-MM-ddThh:mm:ss")
            $interval = $schedule.FrequencyRecurrenceFactor
            if ($schedule.FrequencyTypes = 'Weekly') {
                $frequency = 'Week'
            }
            if ($schedule.FrequencyInterval = 1){
                $weekDays =  'Sunday'
            }
            if (!$schedule.IsEnabled) {
                $runtimeState = 'Stopped'
            }
            $trigger = [System.IO.File]::ReadAllText( $TriggerTemplate)
            $trigger = $trigger.Replace('##TriggerName##', $schedule.Name)
            $trigger = $trigger.Replace('##startTime##', $startTime)
            $trigger = $trigger.Replace('##interval##', $interval)
            $trigger = $trigger.Replace('##frequency##', $frequency)
            $trigger = $trigger.Replace('##weekday##', $weekDays)
            $trigger = $trigger.Replace('##runtimeState##', $runtimeState)
            $trigger = $trigger.Replace('##pipelinename##', $job.Name)
            [System.IO.File]::WriteAllText($TriggerPath, $trigger)

            Set-AzDataFactoryV2Trigger -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -DefinitionFile $TriggerPath -Name $schedule.Name
        }
    }
}

Write-Output "Completed creating ADF pipelines/triggers."