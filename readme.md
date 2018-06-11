# Terraform configuration
This configuration will build multiple VMs on azure. and then run an 
ansible playbook on each host.  Before running, terraform.tfvars needs to be created
with the following variables

```
subscription_id 	= ""
client_id 		= ""
client_secret 		= ""
tenant_id 		= ""
```

## Creating client_id and client_secret

To get the client_id and client_secret, run the command:

```
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<SUBSCRIPTION_ID>"
```

which will output:

```
{
  "appId": "MYAPPID",
  "displayName": "azure-cli-2018-06-09-19-44-55",
  "name": "http://azure-cli-2018-06-09-19-44-55",
  "password": "MYPASSWORD",
  "tenant": "MYTENANT"
}
```

 appid is the client_id and password is the client_secret.
 