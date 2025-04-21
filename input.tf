    resource_group_name = "rg-IaCAutomation5-CB-USE2-D-PRI" 
    location = "eastus2"
    rg_tags = {
    "CCoE_ID_Number":  "23-0304",
    "Application_Name":  "IaCAutomation5",
    "CCoE_Cloud_Planning_Manager":  "Mario Alberto GonzÃ¡lez Vallejo",
    "CCoE_Architect":  "Balwant Singh",
    "Business_ProjectManager":  "Leo Rajapakse \u003cleo.rajapakse@grupobimbo.com\u003e",
    "Application_Owner":  "alberto.gonzalez06@grupobimbo.com",
    "Application_Technical_Contact":  "balwant.singh@gbsupport.net",
    "Distribution_List":  "CCOEArchitecture@gbconnect.onmicrosoft.com",
    "Entity":  "CB",
    "DR_HA":  "N/A"
}

AppGateway_tags = {
    "CCoE_ID_Number":  "23-0304",
    "Application_Name":  "IaCAutomation5",
    "Entity":  "CB",
    "Organization":  "CORP",
    "Change_Ticket":  "CHG0052951",
    "Deploy_Type":  "Automated",
    "App_Criticality":  "yes",
    "Resource_Groups":  "rg-IaCAutomation5-CB-USE2-D-PRI",
    "Launch_Date":  "21/04/2025",
    "Resource_Description":  "IaC_Automation_300"
}

AppGateway = {
    "AppGateway_1":  {
                         "Resource_Description":  "IaC_Automation_300",
                         "application_gateway_name":  "cbtauto5agwcd01",
                         "tier":  "WAF_v2",
                         "capacity_type":  "Autoscale",
                         "autoscale_min_instance_count":  "00",
                         "autoscale_max_instance_count":  "02",
                         "manual_instance_count":  "01",
                         "az_region":  "East US 2",
                         "availability_zone":  "1,2",
                         "vnet":  "vn-dev-eus2",
                         "vnet_rg":  "rgp-allDev-Dev-eus2",
                         "subnet_name":  "snt-IaCAutomation5-CB-USE2-D-PRI-app-gwt",
                         "frontend_ip":  "public",
                         "HTTP2":  "Disabled",
                         "backend_pool_name":  "cbtauto5agwcd01_BEP",
                         "backend_ip_required":  null,
                         "backend_ips":  null,
                         "backend_fqdns_required":  null,
                         "backend_fqdns":  null,
                         "backend_vm":  "true",
                         "backend_vm_name":  "BBUBRDBUSQLCD01",
                         "backend_vm_rg":  null,
                         "backend_vm_nic":  "BBUBRDBUSQLCD01_nic",
                         "backend_app_service":  null,
                         "app_service_name":  null,
                         "backend_app_service_rg":  null,
                         "listener_name":  "cbtauto5agwcd01_Listener",
                         "listener_protocol":  "Https",
                         "key_vault_name":  "CBCOEOPKVACD01",
                         "key_vault_rg":  "rg-CCoEOpsUtilities-cb-use2-d-pri",
                         "hostname":  "app.appgateway.com",
                         "rule_name":  "cbtauto5agwcd01_Rule",
                         "backend_settings_name":  "cbtauto5agwcd01_BES",
                         "port":  "443",
                         "private_ip_address":  null,
                         "firewall_policy_name":  "CBTAUTO5WAFCD",
                         "backend_pools_ip":  {
                                                  "backend_pool_ip_001":  [
                                                                              "172.28.148.188"
                                                                          ]
                                              },
                         "backend_pools_fqdn":  {
                                                    "backend_pool_fqdn_001":  [
                                                                                  "test.appgateway.com"
                                                                              ]
                                                },
                         "backend_pools_vm":  {
                                                  "backend_pool_vm_001":  [
                                                                              "BBUBRDBUSQLCD01"
                                                                          ]
                                              },
                         "backend_pools_appservice":  {
                                                          "backend_pool_appservice_001":  [
                                                                                              "BBUGBCBUAPSCD01"
                                                                                          ],
                                                          "backend_pool_appservice_002":  [
                                                                                              "BBUGBCBUAPSCD02"
                                                                                          ]
                                                      }
                     }
}
