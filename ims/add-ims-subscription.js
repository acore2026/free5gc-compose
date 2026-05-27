// IMS DNN Subscription Data for Voice Calls
// Add to MongoDB free5gc database

// For IMSI 460119999999001
db.subscriptionData.provisionedData.smData.update(
  {ueId: "imsi-460119999999001"},
  {
    $set: {
      "dnnConfigurations.ims": {
        pduSessionTypes: {
          defaultSessionType: "IPV4",
          allowedSessionTypes: ["IPV4"]
        },
        sscModes: {
          defaultSscMode: "SSC_MODE_1",
          allowedSscModes: ["SSC_MODE_2", "SSC_MODE_3"]
        },
        "5gQosProfile": {
          "5qi": 5,
          arp: {
            preemptCap: "",
            preemptVuln: "",
            priorityLevel: 1
          },
          priorityLevel: 1
        },
        sessionAmbr: {
          uplink: "100 Mbps",
          downlink: "100 Mbps"
        }
      }
    }
  }
);

// For IMSI 460119999999002
db.subscriptionData.provisionedData.smData.update(
  {ueId: "imsi-460119999999002"},
  {
    $set: {
      "dnnConfigurations.ims": {
        pduSessionTypes: {
          defaultSessionType: "IPV4",
          allowedSessionTypes: ["IPV4"]
        },
        "5gQosProfile": {
          "5qi": 5,
          arp: {priorityLevel: 1},
          priorityLevel: 1
        },
        sessionAmbr: {
          uplink: "100 Mbps",
          downlink: "100 Mbps"
        }
      }
    }
  }
);

// For IMSI 460119999999003
db.subscriptionData.provisionedData.smData.update(
  {ueId: "imsi-460119999999003"},
  {
    $set: {
      "dnnConfigurations.ims": {
        pduSessionTypes: {
          defaultSessionType: "IPV4",
          allowedSessionTypes: ["IPV4"]
        },
        "5gQosProfile": {
          "5qi": 5,
          arp: {priorityLevel: 1},
          priorityLevel: 1
        },
        sessionAmbr: {
          uplink: "100 Mbps",
          downlink: "100 Mbps"
        }
      }
    }
  }
);

print("IMS DNN subscription data added successfully");