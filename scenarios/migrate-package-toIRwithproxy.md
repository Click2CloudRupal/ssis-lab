# Tutorial: migrate packages to Azure-SSIS IR with self-hosted IR as proxy

This is a step-by-step tutorial to migrate two sample packages to Azure-SSIS with [self-hosted IR as proxy](https://docs.microsoft.com/azure/data-factory/self-hosted-integration-runtime-proxy-ssis).

Prepare a demo server:

- SQL server with SSIS, as on-premises source.
- Download folder "shirdemo" under [this link](https://github.com/chugugrace/ssis-lab/tree/master/scenarios) to c:\.
- Create DB empty "demodatabase".
- The self-hosted IR is installed with default configuration:
    - Self-hosted IR service account: “NT Service\DIAHostService” by default
    - Self-hosted IR logging: “C:\ProgramData\SSISTelemetry” by default
    - Staging storage path: \<blobaccount\>\ssisstagingtempdata

Sample project **onPremOldPackages.ispac** used in this tutorial is designed with SSDT version lower than 15.9.1, which does not have “ConnectByProxy” property.

This project includes:

- Project Params

**destServerName**: destination server name.

**dbName**: database name used in this sample. Source and destination is the same.

**destUserName**: destination server SQL login.

**destPwd**: destination server SQL login password.

- Package flatfile.dtsx

This package is to transfer data from **flat file connection manager "NewCustomers"** (C:\shirdemo\NewCustomers.txt) to local SQL server **demodatabase**. Destination SQL server is moved to Azure SQL server, flat file source is kept in on-premises.

> [!NOTE]
> Make sure source folder is accessible by Self-hosted IR service account “NT Service\DIAHostService”. This is for demo purpose, check more info about [accessing data stores and file shares with Windows authentication from SSIS packages in Azure](https://docs.microsoft.com/sql/integration-services/lift-shift/ssis-azure-connect-with-windows-auth?view=sql-server-2017).

- Package odbc.dtsx

This package is to transfer data from **ODBC Source connection manager "odbccm"** (Driver={ODBC Driver 17 for SQL Server};server=.;uid=LabUser;database=demodatabase) to SQL server. Destination SQL server is moved to Azure SQL server, ODBC source is kept in on-premises.

> [!NOTE]
> Make sure ODBC driver is available on the machine Self-hosted IR is installed.
>
> If ODBC connection uses DSN, make sure “NT Service\DIAHostService” can access the DSN.

## Deploy package to Azure-SSIS IR and update project params

Deploy "onPremOldPackages.ispac" to Azure-SSIS IR via SSMS, similar as the way in on-premises SSIS.

1. Launch "Deploy Project" wizard in SSMS.

![deploy-1](media/ssms-deploy.png)

2. Input project file path.

![deploy-2](media/ssms-deploy-2.png)

3. Select SSIS in "Azure Data Factory" as deployment target

![deploy-3](media/ssms-deploy-3.png)

4. Follow the wizard till complete.

5. Configure project parameters with your destination Azure SQL server connection parameters.
![ssms-project-params](media/ssms-parameter-config.png)

## Execute package

### Execute package in SSMS

Select flatfile.dtsx, then launch execute package. In **Advance** tab, add:

**Property path**: \Package.Connections[NewCustomers].Properties[ConnectByProxy]

**Value**: True

![ssms-execute](media/ssms-execute.png)

> [!TIP]
> If you rebuild the package with SSDT 15.9.1 or later then deploy, you will see "ConnectByProxy" as a property of connection manager, then you can change the property to "True" directly.
> ![conf-proxy-prop](media/ssms-cm-file-newprop.png)

### Execute package via SQL job (SSISDB in Azure SQL managed instance)

Advanced property override is not supported in SSIS job configuration yet, you can use T-SQL to execute SSIS job with property override.

Or you can rebuild package with SSDT 15.9.1 or later then deploy and configure "ConnectByProxy" property in job conneciton manager configuration.

### Execute package via ADF pipeline (SSISDB in Azure SQL server)

1. Configure pipeline "Execute SSIS Package" activity setting as below
![ssis-setting](media/pipeline-setting-config.png)

2. Override pipeline "Execute SSIS Package" activity parameters with your destination Azure SQL server.
![ssis-params](media/pipeline-parameters-config.png)

3. Override property as below:

**Property path**: \Package.Connections[NewCustomers].Properties[ConnectByProxy]

**Value**: True

![ssis-property](media/pipeline-property.png)

>[!TIP]
> If you rebuild the package with SSDT 15.9.1 or later then deploy, you do not need to do property override. You can directly update property "ConnectByProxy" value to "True" of the connection manager.
> ![pipeline-prop-new](media/pipeline-property-new.png)