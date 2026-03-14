// provision.js
// MongoDB script to provision a subscriber into free5gc database

var dbName = "free5gc";
var db = db.getSiblingDB(dbName);

var supi = "imsi-208930000000001";
var key = "8baf473f2f8fd09487cccbd7097c6862";
var opc = "8e27b6af0e692e750f32667a3b14605d";
var amf = "8000";
var plmn = "20893";
var sst = 1;
var sd = "010203";
var snssai = "01010203"; // SST (1 byte) + SD (3 bytes) in hex

// 1. authenticationSubscription
db.authenticationSubscription.updateOne(
    { ueId: supi },
    {
        $set: {
            ueId: supi,
            authenticationMethod: "5G_AKA",
            permanentKey: {
                permanentKeyValue: key,
                encryptionKey: 0,
                encryptionAlgorithm: 0
            },
            sequenceNumber: "000000000000",
            authenticationManagementField: amf,
            milenage: {
                op: {
                    opValue: "",
                    encryptionKey: 0,
                    encryptionAlgorithm: 0
                }
            },
            opc: {
                opcValue: opc,
                encryptionKey: 0,
                encryptionAlgorithm: 0
            }
        }
    },
    { upsert: true }
);

// 2. AccessAndMobilitySubscriptionData
db.AccessAndMobilitySubscriptionData.updateOne(
    { ueId: supi, servingPlmnId: plmn },
    {
        $set: {
            ueId: supi,
            servingPlmnId: plmn,
            nssai: {
                defaultSingleNssais: [{ sst: sst, sd: sd }],
                singleNssais: [{ sst: sst, sd: sd }]
            },
            subscribedUeAmbr: {
                uplink: "1000 Mbps",
                downlink: "1000 Mbps"
            },
            gpsis: ["msisdn-0900000001"]
        }
    },
    { upsert: true }
);

// 3. SessionManagementSubscriptionData
db.SessionManagementSubscriptionData.updateOne(
    { ueId: supi, servingPlmnId: plmn, "singleNssai.sst": sst, "singleNssai.sd": sd },
    {
        $set: {
            ueId: supi,
            servingPlmnId: plmn,
            singleNssai: { sst: sst, sd: sd },
            dnnConfigurations: {
                internet: {
                    pduSessionTypes: { defaultSessionType: "IPV4" },
                    sscModes: { defaultSscMode: "SSC_MODE_1" },
                    "5gQosProfile": {
                        "5qi": 9,
                        arp: { priorityLevel: 8 },
                        priorityLevel: 8
                    },
                    sessionAmbr: {
                        uplink: "200 Mbps",
                        downlink: "100 Mbps"
                    }
                }
            }
        }
    },
    { upsert: true }
);

// 4. SmfSelectionSubscriptionData
db.SmfSelectionSubscriptionData.updateOne(
    { ueId: supi, servingPlmnId: plmn },
    {
        $set: {
            ueId: supi,
            servingPlmnId: plmn,
            subscribedSnssaiInfos: {
                [snssai]: {
                    dnnInfos: [{ dnn: "internet" }]
                }
            }
        }
    },
    { upsert: true }
);

// 5. AmPolicyData
db.AmPolicyData.updateOne(
    { ueId: supi },
    {
        $set: {
            ueId: supi,
            subscCats: ["free5gc"]
        }
    },
    { upsert: true }
);

// 6. SmPolicyData
db.SmPolicyData.updateOne(
    { ueId: supi },
    {
        $set: {
            ueId: supi,
            smPolicySnssaiData: {
                [snssai]: {
                    snssai: { sst: sst, sd: sd },
                    smPolicyDnnData: {
                        internet: { dnn: "internet" }
                    }
                }
            }
        }
    },
    { upsert: true }
);

print("Subscriber " + supi + " provisioned successfully in " + dbName + " database.");
