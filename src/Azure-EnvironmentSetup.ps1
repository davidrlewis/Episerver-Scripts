# The following scripts depend on Azure CLI to be installed
# https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest
## List available subscriptions if needed -> 
##    - az account list --output table

$PROJECT_NAMESPACE = "Epi"
$PROJECTNAME = "Project"
$ENVIRONMENT = "Dev"
$SUBSCRIPTION_ID = "##GUID FOR YOUR SUBSCRIPTION"
$LOCATION = "westus2"
$SQL_ADMIN_USERNAME = "##Sql Admin Username##"
$SQL_ADMIN_PASSWORD = "##Sql Admin Password##"
$SERVICEPLAN_SKU = "S1"
$BLOB_SKU = "standard_lrs"

#=========================================================================================
$RESOURCEGROUP_NAME = "$PROJECT_NAMESPACE.$PROJECTNAME.$ENVIRONMENT"
$SERVICEPLAN_NAME = "$PROJECT_NAMESPACE.$PROJECTNAME.$ENVIRONMENT.ServicePlan"
$WEBAPP_NAME = "$PROJECT_NAMESPACE-$PROJECTNAME-$ENVIRONMENT-web".ToLower()
$SQL_SERVER_NAME = "$PROJECT_NAMESPACE-$PROJECTNAME-$ENVIRONMENT-sql".ToLower()
$SQL_COLLATION = "SQL_Latin1_General_CP1_CI_AS"
$SQL_SERVICEOBJECTIVE = "S0"
$SQL_EDITION = "Standard"
$CMS_DB_NAME = "$PROJECT_NAMESPACE.$PROJECTNAME.$ENVIRONMENT.Cms"
$STORAGEACCOUNT_NAME = "$PROJECT_NAMESPACE$PROJECTNAME$ENVIRONMENT".ToLower() + "strg"
$SERVICEBUS_NAME = "$PROJECT_NAMESPACE$PROJECTNAME$ENVIRONMENT".ToLower() + "servicebus"

# Log in to Azure
az login

# Select the Subscription to deploy the resources
az account set --subscription $SUBSCRIPTION_ID

# Create the resource group
az group create --name $RESOURCEGROUP_NAME --location $LOCATION

# Create App Service
az appservice plan create --name $SERVICEPLAN_NAME --resource-group $RESOURCEGROUP_NAME --sku $SERVICEPLAN_SKU
az webapp create --name $WEBAPP_NAME --resource-group $RESOURCEGROUP_NAME --plan $SERVICEPLAN_NAME

# Create SQL Server
az sql server create --name $SQL_SERVER_NAME --location $LOCATION --resource-group $RESOURCEGROUP_NAME --admin-user $SQL_ADMIN_USERNAME --admin-password $SQL_ADMIN_PASSWORD
az sql server firewall-rule create --resource-group $RESOURCEGROUP_NAME --server $SQL_SERVER_NAME -n AllowAllWindowsAzureIps --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Create CMS DB
az sql db create --resource-group $RESOURCEGROUP_NAME --server $SQL_SERVER_NAME --name $CMS_DB_NAME --edition $SQL_EDITION --collation $SQL_COLLATION --service-objective $SQL_SERVICEOBJECTIVE

# Add the Connection String to your Web App
$CMS_CONNECTIONSTRING="Data Source=tcp:'$(az sql server show -g $RESOURCEGROUP_NAME -n $SQL_SERVER_NAME --query fullyQualifiedDomainName -o tsv)',1433;Initial Catalog='$CMS_DB_NAME';User Id='$SQL_ADMIN_USERNAME';Password='$SQL_ADMIN_PASSWORD';"
az webapp config connection-string set --resource-group $RESOURCEGROUP_NAME --name $WEBAPP_NAME --connection-string-type SQLServer --settings EPiServerDB="$CMS_CONNECTIONSTRING"

# Create Blob Storage Account and Container - note type is set to custom right now as 'blob' is not a defined type
az storage account create --resource-group $RESOURCEGROUP_NAME --name $STORAGEACCOUNT_NAME  --location $LOCATION --sku $BLOB_SKU
$BLOB_KEY = az storage account keys list --resource-group $RESOURCEGROUP_NAME --account-name $STORAGEACCOUNT_NAME --query [0].value

# Add the Connection String to your Web App
$BLOB_CONNECTIONSTRING="DefaultEndpointsProtocol=https;AccountName=$STORAGEACCOUNT_NAME ;AccountKey=$BLOB_KEY"
az webapp config connection-string set --resource-group $RESOURCEGROUP_NAME --name $WEBAPP_NAME --connection-string-type custom --settings EPiServerAzureBlobs="$BLOB_CONNECTIONSTRING"

# Create Service Bus
az servicebus namespace create --resource-group $RESOURCEGROUP_NAME --name $SERVICEBUS_NAME --location $LOCATION

# Add the Connection String to your Web App
$SEVICEBUS_CONNECTIONSTRING=$(az servicebus namespace authorization-rule keys list --resource-group $RESOURCEGROUP_NAME --namespace-name $SERVICEBUS_NAME --name RootManageSharedAccessKey --query primaryConnectionString --output tsv)
az webapp config connection-string set --resource-group $RESOURCEGROUP_NAME --name $WEBAPP_NAME --connection-string-type servicebus --settings EPiServerAzureEvents="$SEVICEBUS_CONNECTIONSTRING"

