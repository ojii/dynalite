let scenarios = require('./expressionScenarios.json');
const assert = require('assert');
const {validateExpressions} = require("../validations");

describe('validateExpressions', () => {
    scenarios.forEach(([inputs, outputs], index) => {
        it(`validateExpressions${index}`, () => {
            validateExpressions(inputs);
            for (const [key, value] of Object.entries(outputs)) {
                // 'inputs' has weird "objects", so i get rid of them via json
                assert.deepStrictEqual(JSON.parse(JSON.stringify(inputs['_' + key])), value)
            }
        })
    })
});