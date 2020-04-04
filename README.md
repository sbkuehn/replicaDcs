# Replica Domain Controllers - Quickstart

## Architecture
![Quickstart Architecture](https://contentsharing1.blob.core.windows.net/content/1-replicaDcs-quickstart.jpg)

## Background
Most enterprises choose to extend their Active Directory Domain Services (ADDS) environment into Azure as part of their digital transformation. Many applications and server environments still rely upon legacy authentication methods like Kerberos for access. Rather than build out replica domain controllers in Azure manually, this template automates both the build and configuration process to help speed up the process. 

## Pre-requisities
1) An existing VNet needs to be set-up with a [S2S VPN](https://github.com/Azure/azure-quickstart-templates/tree/master/101-site-to-site-vpn-create) or ExpressRoute with private peering. [DNS servers](https://docs.microsoft.com/en-us/azure/virtual-network/manage-virtual-network#change-dns-servers) in Azure VNet need to point to on-premises domain controllers.
2) Regardless of the forest and domain configuration that exists on-premises, the domain that hosts users should be able to be seen from Azure for traditional ADDS replication.
3) A [Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/quick-create-portal) must be set up in the subscription. The parameters json showcases how to reference a secret, but values need to be changed per the environment you are deploying this Quickstart to in Azure.
4) Prior to running this template, ensure you have [Active Directory Sites and Services](https://docs.microsoft.com/en-us/windows-server/remote/remote-access/ras/multisite/configure/step-2-configure-the-multisite-infrastructure) set up within your ADDS environment on-premises so your Azure environment. AD Sites provide a great solution for managing ADDS environments that have different geographical locations, yet fall under the same domain. Sites are groupings of well-connected IP subnets that are used to efficiently replicate information among domain controllers. Sites help to achieve cost-efficiency and speed, along with letting companies exercise better control over the replication traffic and the entire authentication process. When there is more than one DC in the associated site that is capable of handling client logon, services, and directory searches, sites locates the closest DC to perform those actions. 

## Benefits
1) Provides access to the same identity information that is available on-premises.
2) Companies can authenticate a user, service, and/or computer accounts on-premises and in Azure.
3) Companies do not need to manage a separate AD forest, as the domain in Azure can belong to the on-premises forest.
4) Companies can apply group policy defined by on-premises Group Policy Objects to the domain in Azure.

## Possible Challenges
1) Companies must deploy and manage their own AD DS servers and domain in the cloud.
2) There may be some synchronization latency between the domain servers in the cloud and the servers running on-premises.
