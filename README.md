# Replica Domain Controllers - Quickstart

## Background
Most enterprises choose to extend their Active Directory Domain Services (ADDS) environment into Azure as part of their digital transformation. Many applications and server environments still rely upon legacy authentication methods like Kerberos for access. Rather than build out replica domain controllers in Azure manually, this template automates both the build and configuration process to help speed up the process. 

## Pre-requisities & Notes
1) An existing VNet needs to be set-up with a S2S VPN or ExpressRoute.
2) Site-to-Site VPN or ExpressRoute with private peering set-up.
3) Line of sight to on-premises domain controllers. Regardless of the forest and domain configuration on-premises, the domain that hosts users should be able to be seen from Azure for Active Directory replication.
4) A Key Vault must be set up in the subscription. The parameters json showcases how to reference a secret, but values need to be changed per the environment you are deploying this Quickstart to.

## Benefits
1) Provides access to the same identity information that is available on-premises.
2) Companies can authenticate a user, service, and/or computer accounts on-premises and in Azure.
3) Companies do not need to manage a separate AD forest, as the domain in Azure can belong to the on-premises forest.
4) Companies can apply group policy defined by on-premises Group Policy Objects to the domain in Azure.

## Possible Challenges
1) Companies must deploy and manage their own AD DS servers and domain in the cloud.
2) There may be some synchronization latency between the domain servers in the cloud and the servers running on-premises.
