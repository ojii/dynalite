let { validateExpressions } = require("../../validations/index");

function testExpressionValidation() {
  const result = validateExpressions({
    ExpressionAttributeNames: {
      "#n0": "H",
      "#n1": "error",
      "#n2": "reserved",
      "#n3": "revoked",
      "#n4": "not_before",
      "#n5": "early_expiration",
      "#n6": "not_after",
      "#n7": "renewal_info",
      "#n8": "status",
      "#n9": "device",
      "#n10": "cert_type",
      "#n11": "install_info",
      "#n12": "count",
    },
    ExpressionAttributeValues: {
      ":v0": {
        S: "CERT@cert.filters",
      },
      ":v1": {
        BOOL: true,
      },
      ":v2": {
        N: "1630993151",
      },
      ":v3": {
        S: "done",
      },
      ":v4": {
        S: "processing",
      },
      ":v5": {
        S: "macos",
      },
      ":v6": {
        S: "personal",
      },
      ":v7": {
        N: "0",
      },
    },
    UpdateExpression: null,
    ConditionExpression: null,
    KeyConditionExpression: "#n0 = :v0",
    FilterExpression:
      "((((attribute_not_exists(#n1) AND ((((#n2 = :v1 AND #n3 <> :v1) OR ((#n4 < :v2 AND #n3 <> :v1) AND ((attribute_not_exists(#n5) AND #n6 > :v2) OR #n5 > :v2))) AND (NOT #n7.#n8 IN (:v3,:v4))) AND attribute_not_exists(#n5))) AND #n9 = :v5) AND #n10 = :v6) AND (attribute_not_exists(#n11.#n12) OR #n11.#n12 = :v7))",
    ProjectionExpression: null,
  });

  return result;
}

const t = new Date();
const result = testExpressionValidation();
console.log(`Took ${new Date() - t} m.s.`);
console.log(result);
