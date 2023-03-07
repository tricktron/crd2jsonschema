const toJsonSchemaDraft4 = require("@openapi-contrib/openapi-schema-to-json-schema");
const fs                 = require('fs');

try
{
    const openapiV3Schema    = fs.readFileSync(0, 'utf-8');
    const jsonSchemaDraft4   = toJsonSchemaDraft4(JSON.parse(openapiV3Schema.toString()));
    console.log(JSON.stringify(jsonSchemaDraft4, null, 4));
    process.exit();

} catch (error)
{
    console.error(error);
    process.exit(1); 
}