const toJsonSchema    = require("@openapi-contrib/openapi-schema-to-json-schema");
const fs              = require('fs');

try
{
    const input           = fs.readFileSync(0, 'utf-8');
    const convertedSchema = toJsonSchema(JSON.parse(input.toString()));
    console.log(JSON.stringify(convertedSchema, null, 4));
    process.exit();

} catch (error)
{
    console.error(error);
    process.exit(1); 
}