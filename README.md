# Replica Domain Controllers - Quickstart

Most enterprises choose to extend their Active Directory Domain Services (ADDS) environment into Azure as part of their digital transformation. Many applications and server environments still rely upon legacy authentication mechanisms like Kerberos for access. Rather than build out replica domain controllers in Azure manually, this template automates both the build and configuration process to help speed up the process. 

Pre-requisities
1) Site-to-Site VPN or ExpressRoute with private peering set-up.
2) Line of sight to on-premises domain controllers. Regardless of the forest and domain configuration on-premises, the domain that hosts users should be able to be seen from Azure.

Benefits

Provides access to the same identity information that is available on-premises.
You can authenticate user, service, and/or computer accounts on-premises and in Azure.
You do not need to manage a separate AD forest. The domain in Azure can belong to the on-premises forest.
You can apply group policy defined by on-premises Group Policy Objects to the domain in Azure.

Possible Challenges

You must deploy and manage your own AD DS servers and domain in the cloud.
There may be some synchronization latency between the domain servers in the cloud and the servers running on-premises.
