﻿FUNCTION Stop-DbaAgentJob {
	<#
		.SYNOPSIS
			Stops a running SQL Server Agent Job.

		.DESCRIPTION
			This command stops a job then returns connected SMO object for SQL Agent Job information for each instance(s) of SQL Server.

		.PARAMETER SqlInstance
			SQL Server name or SMO object representing the SQL Server to connect to. 
	
		.PARAMETER SqlCredential
			SqlCredential object to connect as. If not specified, current Windows login will be used.

		.PARAMETER Job
			The job(s) to process - this list is auto-populated from the server. If unspecified, all jobs will be processed.

		.PARAMETER ExcludeJob
			The job(s) to exclude - this list is auto-populated from the server.

		.PARAMETER Wait
			Wait for output until the job has completely stopped
	
		.PARAMETER JobCollection
			Internal parameter that enables piping
	
		.PARAMETER WhatIf
			If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

		.PARAMETER Confirm 
			If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

		.PARAMETER Silent
			Use this switch to disable any kind of verbose messages.

		.NOTES
			Tags: Job, Agent
			Website: https://dbatools.io
			Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Stop-DbaAgentJob

		.EXAMPLE
			Stop-DbaAgentJob -SqlInstance localhost

			Stops all running SQL Agent Jobs on the local SQL Server instance

		.EXAMPLE
			Get-DbaAgentJob -SqlInstance sql2016 -Job cdc.DBWithCDC_capture | Stop-DbaAgentJob

			Stops the cdc.DBWithCDC_capture SQL Agent Job on sql2016

		.EXAMPLE
			Stop-DbaAgentJob -SqlInstance sql2016 -Job cdc.DBWithCDC_capture
	
			Stops the cdc.DBWithCDC_capture SQL Agent Job on sql2016
	
	#>
	[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "Default")]
	param (
		[parameter(Mandatory, ParameterSetName = "Instance")]
		[Alias("ServerInstance", "SqlServer")]
		[DbaInstanceParameter[]]$SqlInstance,
		[PSCredential]$SqlCredential,
		[string[]]$Job,
		[string[]]$ExcludeJob,
		[parameter(Mandatory, ValueFromPipeline, ParameterSetName = "Object")]
		[Microsoft.SqlServer.Management.Smo.Agent.Job[]]$JobCollection,
		[switch]$Wait,
		[switch]$Silent
	)
	
	process {
		foreach ($instance in $SqlInstance) {
			Write-Verbose "Attempting to connect to $instance"
			try {
				$server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
			}
			catch {
				Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
			}
			
			$jobcollection += $server.JobServer.Jobs
			
			if ($Job) {
				$jobcollection = $jobcollection | Where-Object Name -In $Job
			}
			if ($ExcludeJob) {
				$jobcollection = $jobcollection | Where-Object Name -NotIn $ExcludeJob
			}
		}
		
		foreach ($currentjob in $JobCollection) {
			
			$server = $currentjob.Parent.Parent
			$status = $currentjob.CurrentRunStatus
			
			if ($status -eq 'Idle') {
				Stop-Function -Message "$currentjob on $server is idle ($status)" -Target $currentjob -Continue
			}
			
			If ($Pscmdlet.ShouldProcess($server, "Stopping job $currentjob")) {
				$null = $currentjob.Stop()
				Start-Sleep -Milliseconds 300
				$currentjob.Refresh()
				
				$waits = 0
				while ($currentjob.CurrentRunStatus -ne 'Idle' -and $waits++ -lt 10) {
					Start-Sleep -Milliseconds 100
					$currentjob.Refresh()
				}
				
				if ($wait) {
					while ($currentjob.CurrentRunStatus -ne 'Idle') {
						Write-Message -Level Output -Message "$currentjob is $($currentjob.CurrentRunStatus)"
						Start-Sleep -Seconds 3
						$currentjob.Refresh()
					}
					$currentjob
				}
				else {
					$currentjob
				}
			}
		}
	}
}