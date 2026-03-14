var dbName = "free5gc";
var db = db.getSiblingDB(dbName);

var supi = "imsi-208930000000001";
var key = "8baf473f2f8fd09487cccbd7097c6862";
var opc = "8e27b6af0e692e750f32667a3b14605d";
var amf = "8000";
var plmn = "20893";
var sst = 1;
var sd = "010203";
var snssai = "01010203";

var authData = {
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
};

db["subscriptionData.authenticationData.authenticationSubscription"].replaceOne({ ueId: supi }, authData, { upsert: true });

print("Subscriber provisioned with simple string sequenceNumber and lowercase fields.");
